/// Positions plotted on the field map from this device's own SQLite.
enum FieldMapLayer { self, incident, victim, hazard, sos }

class FieldMapMarker {
  const FieldMapMarker({
    required this.id,
    required this.layer,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.subtitle,
    this.routePath,
  });

  final String id;
  final FieldMapLayer layer;
  final String label;
  final double latitude;
  final double longitude;
  final String? subtitle;
  final String? routePath;
}

bool _hasFix(double? lat, double? lng) =>
    lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180;

List<FieldMapMarker> buildFieldMapMarkers({
  required Iterable<({String id, String label, double? lat, double? lng, String? subtitle, String? path})>
      incidents,
  required Iterable<({String id, String label, double? lat, double? lng, String? subtitle, String? path})>
      victims,
  required Iterable<({String id, String label, double? lat, double? lng, String? subtitle, String? path})>
      hazards,
  required Iterable<({String id, String label, double? lat, double? lng, String? subtitle, String? path})>
      sos,
  double? selfLat,
  double? selfLng,
  String? selfLabel,
}) {
  final markers = <FieldMapMarker>[];

  void add(
    FieldMapLayer layer,
    String id,
    String label,
    double? lat,
    double? lng,
    String? subtitle,
    String? path,
  ) {
    if (!_hasFix(lat, lng)) return;
    markers.add(
      FieldMapMarker(
        id: id,
        layer: layer,
        label: label,
        latitude: lat!,
        longitude: lng!,
        subtitle: subtitle,
        routePath: path,
      ),
    );
  }

  if (_hasFix(selfLat, selfLng)) {
    markers.add(
      FieldMapMarker(
        id: 'self',
        layer: FieldMapLayer.self,
        label: selfLabel ?? 'This device',
        latitude: selfLat!,
        longitude: selfLng!,
        subtitle: 'Last captured GPS on this handset',
      ),
    );
  }

  for (final row in incidents) {
    add(FieldMapLayer.incident, row.id, row.label, row.lat, row.lng, row.subtitle, row.path);
  }
  for (final row in victims) {
    add(FieldMapLayer.victim, row.id, row.label, row.lat, row.lng, row.subtitle, row.path);
  }
  for (final row in hazards) {
    add(FieldMapLayer.hazard, row.id, row.label, row.lat, row.lng, row.subtitle, row.path);
  }
  for (final row in sos) {
    add(FieldMapLayer.sos, row.id, row.label, row.lat, row.lng, row.subtitle, row.path);
  }
  return markers;
}

List<FieldMapMarker> visibleFieldMarkers(
  List<FieldMapMarker> markers,
  Set<FieldMapLayer> layers,
) =>
    markers.where((marker) => layers.contains(marker.layer)).toList();
