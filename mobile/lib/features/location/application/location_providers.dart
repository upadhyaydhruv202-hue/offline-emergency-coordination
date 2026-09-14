import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../data/local/database_providers.dart';
import '../../../domain/entities/audit_event.dart';
import '../../../domain/entities/gps_status.dart';
import '../../../domain/entities/location_fix.dart';
import '../../../domain/entities/location_record.dart';
import '../../audit/application/audit_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../field_ops/application/operating_context.dart';
import '../data/location_repository.dart';
import '../data/location_service.dart';

const locationAllowMockKey = 'location.allow_mock';

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);

final locationRepositoryProvider = Provider<LocationRepository>(
  (ref) => LocationRepository(
    locations: ref.watch(locationDaoProvider),
    service: ref.watch(locationServiceProvider),
  ),
);

final latestLocationProvider = StreamProvider<LocationRecord?>((ref) {
  final responderId = ref.watch(authControllerProvider).responderOrNull?.id;
  if (responderId == null) return Stream<LocationRecord?>.value(null);
  return ref.watch(locationRepositoryProvider).watchLatestFor(responderId);
});

final locationPendingCountProvider = StreamProvider<int>(
  (ref) => ref.watch(locationDaoProvider).watchPendingCount(),
);

/// Developer-only: accept mock/emulator GPS and label it DEMO MODE.
final locationAllowMockProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(appMetadataDaoProvider)
      .watch(locationAllowMockKey)
      .map((value) => value == 'true');
});

class LocationCaptureState {
  const LocationCaptureState({
    this.isCapturing = false,
    this.failure,
    this.access = LocationAccessState.unknown,
  });

  final bool isCapturing;
  final String? failure;
  final LocationAccessState access;

  bool get hasFailed => failure != null;
}

final locationCaptureProvider =
    NotifierProvider<LocationCaptureController, LocationCaptureState>(
  LocationCaptureController.new,
);

class LocationCaptureController extends Notifier<LocationCaptureState> {
  @override
  LocationCaptureState build() => const LocationCaptureState();

  Future<LocationRecord?> refresh() async {
    if (state.isCapturing) return null;

    final context = ref.read(operatingContextProvider);
    final responderId = context.responderId();
    if (responderId == null) {
      state = const LocationCaptureState(
        failure: 'No session on this device, so there is nobody to record a '
            'position for.',
      );
      return null;
    }

    state = LocationCaptureState(isCapturing: true, access: state.access);

    try {
      final access = await ref.read(locationServiceProvider).ensureAccess();
      final accessState =
          ref.read(locationServiceProvider).toAccessState(access);
      final record = await ref.read(locationRepositoryProvider).capture(
            responderId: responderId,
            incidentId: await context.currentIncidentId(),
          );

      await ref.read(auditRepositoryProvider).record(
            eventType: AuditEventType.locationCaptured,
            entityType: AuditEntityType.location,
            entityId: record.id,
            actorId: responderId,
            metadata: {
              'latitude': record.latitude,
              'longitude': record.longitude,
              'accuracy': record.accuracy,
              'source': record.source,
              'mocked': record.isMocked,
            },
          );

      state = LocationCaptureState(access: accessState);
      return record;
    } on LocationUnavailableException catch (error) {
      state = LocationCaptureState(
        failure: error.message,
        access: _accessFromFailure(error),
      );
      return null;
    } on Exception catch (error) {
      state = LocationCaptureState(
        failure: 'The position could not be stored on this device: $error',
      );
      return null;
    }
  }

  void clearFailure() => state = LocationCaptureState(access: state.access);
}

LocationAccessState _accessFromFailure(LocationUnavailableException error) {
  if (error.isPermanent) return LocationAccessState.deniedForever;
  final message = error.message;
  if (message.contains('was not granted') ||
      message.contains('denied access')) {
    return LocationAccessState.denied;
  }
  if (message.contains('switched off')) {
    return LocationAccessState.serviceDisabled;
  }
  return LocationAccessState.unknown;
}

class LocationSessionState {
  const LocationSessionState({
    this.listening = false,
    this.access = LocationAccessState.unknown,
    this.failure,
  });

  final bool listening;
  final LocationAccessState access;
  final String? failure;
}

/// Keeps a foreground GPS subscription alive for the signed-in field session.
final locationSessionProvider =
    NotifierProvider<LocationSessionController, LocationSessionState>(
  LocationSessionController.new,
);

class LocationSessionController extends Notifier<LocationSessionState> {
  StreamSubscription<LocationFix>? _subscription;
  LocationRecord? _lastStored;
  String? _activeResponderId;

  @override
  LocationSessionState build() {
    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _subscription = null;
    });

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final id = next.responderOrNull?.id;
      if (id == null) {
        unawaited(_stop());
        state = const LocationSessionState();
        return;
      }
      if (id != _activeResponderId) {
        unawaited(_start(id));
      }
    }, fireImmediately: true);

    return const LocationSessionState();
  }

  Future<void> _stop() async {
    _activeResponderId = null;
    await _subscription?.cancel();
    _subscription = null;
    _lastStored = null;
  }

  Future<void> _start(String responderId) async {
    _activeResponderId = responderId;
    await _subscription?.cancel();
    _lastStored =
        await ref.read(locationRepositoryProvider).readLatestFor(responderId);

    final service = ref.read(locationServiceProvider);
    LocationAccessState accessState = LocationAccessState.unknown;
    try {
      final access = await service.ensureAccess();
      accessState = service.toAccessState(access);
    } on Exception {
      accessState = LocationAccessState.unknown;
    }

    if (accessState != LocationAccessState.granted) {
      state = LocationSessionState(access: accessState);
      return;
    }

    state = LocationSessionState(access: accessState, listening: true);

    try {
      _subscription = service.watchFixes().listen(
        (fix) => unawaited(_onFix(responderId, fix)),
        onError: (Object error) {
          state = LocationSessionState(
            access: accessState,
            failure: error is LocationUnavailableException
                ? error.message
                : 'The receiver stopped: $error',
          );
        },
      );
    } on LocationUnavailableException catch (error) {
      state = LocationSessionState(
        access: _accessFromFailure(error),
        failure: error.message,
      );
    } on Exception catch (error) {
      state = LocationSessionState(
        access: accessState,
        failure: 'The receiver could not be started: $error',
      );
    }
  }

  Future<void> _onFix(String responderId, LocationFix fix) async {
    final previous = _lastStored;
    if (previous != null && !_movedEnough(previous.fix, fix)) {
      return;
    }

    final context = ref.read(operatingContextProvider);
    final record = await ref.read(locationRepositoryProvider).store(
          fix: fix,
          responderId: responderId,
          incidentId: await context.currentIncidentId(),
        );
    _lastStored = record;
  }

  bool _movedEnough(LocationFix previous, LocationFix next) {
    final elapsed = next.timestamp.difference(previous.timestamp);
    if (elapsed >= const Duration(seconds: 5)) return true;
    return previous.distanceMetersTo(next) >= 5;
  }
}

GpsClassification classifyCurrentGps({
  required LocationRecord? record,
  required LocationSessionState session,
  required LocationCaptureState capture,
  required bool allowMock,
  required DateTime now,
}) {
  return GpsClassification.classify(
    now: now,
    allowMock: allowMock,
    record: record,
    access: capture.access != LocationAccessState.unknown
        ? capture.access
        : session.access,
    listening: session.listening,
    failure: capture.failure ?? session.failure,
  );
}
