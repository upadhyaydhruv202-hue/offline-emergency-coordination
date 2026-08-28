import 'incident_summary.dart';

/// The single place fabricated data is allowed to live in the mobile app.
///
/// Slice 2 introduces a real incident module and deletes this file.
final IncidentSummary demoIncident = IncidentSummary(
  id: 'demo-incident-0001',
  name: 'Ahmedabad Earthquake Response',
  sector: 'Sector 4 — Naroda',
  declaredAt: DateTime.utc(2026, 8, 27, 4, 12),
  isDemoData: true,
);
