import 'package:drp_mobile/features/map/field_map_markers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('omits records that have no coordinates', () {
    final markers = buildFieldMapMarkers(
      incidents: [
        (
          id: 'i1',
          label: 'Quake',
          lat: 23.02,
          lng: 72.57,
          subtitle: 'Zone 04',
          path: '/incidents/i1',
        ),
        (
          id: 'i2',
          label: 'No fix',
          lat: null,
          lng: null,
          subtitle: null,
          path: '/incidents/i2',
        ),
      ],
      victims: [
        (
          id: 'v1',
          label: 'V-1',
          lat: 23.03,
          lng: 72.58,
          subtitle: 'CRITICAL',
          path: '/victims/v1',
        ),
      ],
      hazards: const [],
      sos: const [],
      selfLat: 23.01,
      selfLng: 72.56,
    );

    expect(markers.map((m) => m.id).toList(), ['self', 'i1', 'v1']);
  });

  test('layer filter hides unselected kinds', () {
    final all = buildFieldMapMarkers(
      incidents: [
        (id: 'i1', label: 'A', lat: 1, lng: 1, subtitle: null, path: null),
      ],
      victims: [
        (id: 'v1', label: 'V', lat: 2, lng: 2, subtitle: null, path: null),
      ],
      hazards: const [],
      sos: const [],
    );
    final visible = visibleFieldMarkers(all, {FieldMapLayer.victim});
    expect(visible.single.id, 'v1');
  });
}
