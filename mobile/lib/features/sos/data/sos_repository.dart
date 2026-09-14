import '../../../core/utils/identifiers.dart';
import '../../../data/local/daos/app_metadata_dao.dart';
import '../../../data/local/daos/sos_dao.dart';
import '../../../data/local/field_code_minter.dart';
import '../../../data/local/tables/app_metadata.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/location_fix.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sos_priority.dart';
import '../../../domain/entities/sos_status.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation_type.dart';
import '../../sync/data/entity_payloads.dart';
import '../../sync/data/sync_journal.dart';

/// How a distress call comes into existence and changes.
///
/// The rule this file exists to enforce: **raising an SOS completes against
/// local storage and nothing else**. There is no network call here, no SMS, no
/// dialler, and no mesh — none of which exist in this build. A responder who
/// presses the button gets a timestamped, positioned, durable record, and the
/// interface tells them exactly that rather than implying help is on its way.
class SosRepository {
  SosRepository({
    required this.events,
    required this.metadata,
    this.journal,
  }) : _codes = FieldCodeMinter(metadata);

  final SosDao events;
  final AppMetadataDao metadata;
  final SyncJournal? journal;
  final FieldCodeMinter _codes;

  Stream<List<SosEvent>> watchEvents() => events.watchEvents();

  Future<List<SosEvent>> readEvents() => events.readEvents();

  Stream<SosEvent?> watchEvent(String id) => events.watchEvent(id);

  Future<SosEvent?> readEvent(String id) => events.readEvent(id);

  Stream<SosBoard> watchBoard() => events.watchBoard();

  /// Writes a new distress call to the device and returns the stored record.
  ///
  /// [position] is whatever the device managed to read. A call with no fix is
  /// still raised: somebody in trouble without a position is exactly the person
  /// who most needs the record to exist.
  Future<SosEvent> raise({
    required String createdBy,
    required SosPriority priority,
    String? incidentId,
    LocationFix? position,
    String? message,
    DateTime? now,
  }) async {
    final timestamp = (now ?? DateTime.now()).toUtc();

    final event = SosEvent(
      id: generateUuidV4(),
      sosCode: await _nextCode(),
      createdBy: createdBy,
      incidentId: incidentId,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      // When the button was pressed, not when the fix was taken: a position may
      // be minutes old, and the moment a responder called for help is the one
      // thing about the record that must not be approximate.
      raisedAt: timestamp,
      priority: priority,
      message: _clean(message),
      status: SosStatus.created,
      createdAt: timestamp,
      updatedAt: timestamp,
      // Nothing has been synchronised, because nothing can be yet.
      syncStatus: SyncStatus.pending,
    );

    await events.insertEvent(event);
    await journal?.record(
      entityType: SyncEntityType.sos,
      entityId: event.id,
      operationType: SyncOperationType.create,
      payload: sosPayload(event),
      actorId: createdBy,
      now: timestamp,
    );
    return event;
  }

  /// Moves a call through created, acknowledged and resolved.
  ///
  /// In this slice only the raising device can do this: acknowledgement is
  /// recorded because a responder was told over the radio that the call was
  /// heard. That is honest. A remote acknowledgement would not be.
  Future<SosEvent> changeStatus({
    required SosEvent event,
    required SosStatus status,
    DateTime? now,
  }) async {
    final updated = event.copyWith(
      status: status,
      updatedAt: (now ?? DateTime.now()).toUtc(),
      syncStatus: SyncStatus.pending,
    );

    await events.updateEvent(updated);
    await journal?.record(
      entityType: SyncEntityType.sos,
      entityId: updated.id,
      operationType: SyncOperationType.update,
      payload: sosPayload(updated),
      actorId: event.createdBy,
      now: updated.updatedAt,
    );
    return updated;
  }

  Future<String> _nextCode() => _codes.next(
        prefix: 'SOS',
        sequenceKey: AppMetadataKeys.sosSequence,
        isTaken: (candidate) async =>
            await events.readByCode(candidate) != null,
      );

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
