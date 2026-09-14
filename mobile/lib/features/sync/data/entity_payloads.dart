import '../../../domain/entities/field_task.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_status.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../../domain/entities/incident.dart';
import '../../../domain/entities/responder_status_record.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sync_status.dart';
import '../../../domain/entities/victim.dart';

Map<String, Object?> hazardPayload(Hazard hazard) => {
      'id': hazard.id,
      'hazardCode': hazard.hazardCode,
      'incidentId': hazard.incidentId,
      'reportedBy': hazard.reportedBy,
      'type': hazard.type.wireValue,
      'severity': hazard.severity.wireValue,
      'priority': hazard.priority,
      'description': hazard.description,
      'latitude': hazard.latitude,
      'longitude': hazard.longitude,
      'accuracy': hazard.accuracy,
      'observedAt': hazard.observedAt.toIso8601String(),
      'status': hazard.status.wireValue,
      'createdAt': hazard.createdAt.toIso8601String(),
      'updatedAt': hazard.updatedAt.toIso8601String(),
    };

Map<String, Object?> victimPayload(Victim victim) => {
      'id': victim.id,
      'temporaryId': victim.temporaryId,
      'name': victim.name,
      'triageCategory': victim.triageCategory.wireValue,
      'status': victim.status.wireValue,
      'updatedAt': victim.updatedAt.toIso8601String(),
    };

Map<String, Object?> incidentPayload(Incident incident) => {
      'id': incident.id,
      'incidentCode': incident.incidentCode,
      'title': incident.title,
      'status': incident.status.wireValue,
      'assignedZone': incident.assignedZone,
      'updatedAt': incident.updatedAt.toIso8601String(),
    };

Map<String, Object?> taskPayload(FieldTask task) => {
      'id': task.id,
      'taskCode': task.taskCode,
      'title': task.title,
      'status': task.status.wireValue,
      'priority': task.priority.wireValue,
      'updatedAt': task.updatedAt.toIso8601String(),
    };

Map<String, Object?> sosPayload(SosEvent event) => {
      'id': event.id,
      'sosCode': event.sosCode,
      'priority': event.priority.wireValue,
      'status': event.status.wireValue,
      'updatedAt': event.updatedAt.toIso8601String(),
    };

Map<String, Object?> responderStatusPayload(ResponderStatusRecord record) => {
      'id': record.responderId,
      'status': record.status.wireValue,
      'incidentId': record.incidentId,
      'updatedAt': record.updatedAt.toIso8601String(),
    };

Hazard? hazardFromPayload(Map<String, Object?> payload) {
  final id = payload['id'] as String?;
  final code = payload['hazardCode'] as String?;
  final type = HazardType.tryFromWire(payload['type'] as String?);
  final severity = HazardSeverity.tryFromWire(payload['severity'] as String?);
  final status = HazardStatus.tryFromWire(payload['status'] as String?);
  if (id == null || code == null || type == null || severity == null || status == null) {
    return null;
  }
  DateTime parse(String key, DateTime fallback) {
    final raw = payload[key] as String?;
    return DateTime.tryParse(raw ?? '')?.toUtc() ?? fallback;
  }

  final now = DateTime.now().toUtc();
  return Hazard(
    id: id,
    hazardCode: code,
    incidentId: payload['incidentId'] as String?,
    reportedBy: (payload['reportedBy'] as String?) ?? 'unknown',
    type: type,
    severity: severity,
    priority: (payload['priority'] as num?)?.toInt() ?? severity.priority,
    description: payload['description'] as String?,
    latitude: (payload['latitude'] as num?)?.toDouble(),
    longitude: (payload['longitude'] as num?)?.toDouble(),
    accuracy: (payload['accuracy'] as num?)?.toDouble(),
    observedAt: parse('observedAt', now),
    status: status,
    createdAt: parse('createdAt', now),
    updatedAt: parse('updatedAt', now),
    syncStatus: SyncStatus.acknowledged,
  );
}
