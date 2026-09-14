import '../../../domain/entities/sync_entity_type.dart';
import '../../../domain/entities/sync_operation.dart';
import '../../../domain/entities/sync_operation_type.dart';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

final _deviceId = RegExp(r'^[A-Za-z0-9._:-]{3,64}$');

/// Why a peer operation was refused. The operation is kept (FAILED), not dropped.
class SyncValidationException implements Exception {
  SyncValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Treats every inbound operation as hostile until the shape checks pass.
void validateOperation(SyncOperation operation) {
  _uuidOrThrow(operation.operationId, 'operationId');
  _uuidOrThrow(operation.id, 'id');
  if (operation.entityType != SyncEntityType.responderStatus) {
    _uuidOrThrow(operation.entityId, 'entityId');
  } else if (operation.entityId.trim().length < 8) {
    throw SyncValidationException('Malformed entityId');
  }
  if (!_deviceId.hasMatch(operation.deviceId)) {
    throw SyncValidationException('Malformed deviceId');
  }
  if (operation.actorId.trim().isEmpty) {
    throw SyncValidationException('Missing actorId');
  }
  if (SyncEntityType.tryFromWire(operation.entityType.wireValue) == null) {
    throw SyncValidationException('Unknown entityType');
  }
  if (SyncOperationType.tryFromWire(operation.operationType.wireValue) ==
      null) {
    throw SyncValidationException('Unknown operationType');
  }
  if (operation.logicalTimestamp < 0 || operation.version < 0) {
    throw SyncValidationException('Invalid logical timestamp');
  }
  if (operation.parentVersion != null && operation.parentVersion! < 0) {
    throw SyncValidationException('Invalid parentVersion');
  }
  if (operation.payload.isEmpty &&
      operation.operationType != SyncOperationType.delete) {
    throw SyncValidationException('Empty payload');
  }
  final payloadId = operation.payload['id'];
  if (payloadId is String && payloadId != operation.entityId) {
    throw SyncValidationException('Payload id does not match entityId');
  }
}

void _uuidOrThrow(String value, String field) {
  if (!_uuid.hasMatch(value)) {
    throw SyncValidationException('Malformed UUID for $field');
  }
}
