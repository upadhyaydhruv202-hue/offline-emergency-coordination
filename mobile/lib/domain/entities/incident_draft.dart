import 'disaster_type.dart';
import 'incident.dart';
import 'incident_status.dart';

/// What a responder types when declaring or editing an incident.
///
/// Identifiers, timestamps, provenance and sync state are absent on purpose:
/// a draft is an intention, and the repository is the only thing that turns
/// one into an [Incident].
class IncidentDraft {
  const IncidentDraft({
    required this.title,
    required this.disasterType,
    this.description,
    this.assignedZone,
    this.status = IncidentStatus.active,
    this.latitude,
    this.longitude,
  });

  factory IncidentDraft.from(Incident incident) => IncidentDraft(
        title: incident.title,
        disasterType: incident.disasterType,
        description: incident.description,
        assignedZone: incident.assignedZone,
        status: incident.status,
        latitude: incident.latitude,
        longitude: incident.longitude,
      );

  final String title;
  final DisasterType disasterType;
  final String? description;
  final String? assignedZone;
  final IncidentStatus status;
  final double? latitude;
  final double? longitude;

  bool get hasTitle => title.trim().isNotEmpty;

  IncidentDraft copyWith({
    String? title,
    DisasterType? disasterType,
    String? description,
    String? assignedZone,
    IncidentStatus? status,
    double? latitude,
    double? longitude,
  }) =>
      IncidentDraft(
        title: title ?? this.title,
        disasterType: disasterType ?? this.disasterType,
        description: description ?? this.description,
        assignedZone: assignedZone ?? this.assignedZone,
        status: status ?? this.status,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
      );
}
