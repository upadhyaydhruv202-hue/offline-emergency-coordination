/// Minimal description of the incident a device is assigned to.
///
/// Slice 1 has no incident module, so the only instance in the app is the
/// clearly-labelled demo constant in `lib/domain/entities/demo_data.dart`.
class IncidentSummary {
  const IncidentSummary({
    required this.id,
    required this.name,
    required this.sector,
    required this.declaredAt,
    this.isDemoData = false,
  });

  final String id;
  final String name;
  final String sector;
  final DateTime declaredAt;

  /// Set on any record that is fabricated rather than observed.
  final bool isDemoData;
}
