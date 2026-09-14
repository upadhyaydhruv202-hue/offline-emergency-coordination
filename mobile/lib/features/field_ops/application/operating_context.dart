import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../incidents/application/incident_providers.dart';

/// Who is holding the device and what they are working on.
///
/// Every service that writes a field record needs the same two facts, and
/// neither of them is something to ask the responder for a second time. Passing
/// them as closures rather than values keeps the services out of Riverpod and
/// means a test can supply them directly.
///
/// The incident is resolved from the database on each call rather than read from
/// a stream, so a record can never be filed against a stale selection because a
/// widget had not rebuilt yet.
class OperatingContext {
  const OperatingContext({
    required this.responderId,
    required this.currentIncidentId,
  });

  final String? Function() responderId;
  final Future<String?> Function() currentIncidentId;

  /// The authoring responder, or a failure if there is no session.
  ///
  /// A [StateError] rather than a handled failure: reaching a write path with no
  /// session means the router let something through it should not have, and
  /// swallowing that would hide the bug rather than the symptom.
  String requireResponderId() {
    final id = responderId();
    if (id == null) {
      throw StateError('A field record cannot be written without a session');
    }
    return id;
  }
}

final operatingContextProvider = Provider<OperatingContext>(
  (ref) => OperatingContext(
    responderId: () => ref.read(authControllerProvider).responderOrNull?.id,
    currentIncidentId: () =>
        ref.read(incidentRepositoryProvider).readCurrentIncidentId(),
  ),
);
