import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/local_data_banner.dart';
import '../connectivity/connectivity_providers.dart';
import '../connectivity/connectivity_status.dart';
import '../hazards/application/hazard_providers.dart';
import '../incidents/application/incident_providers.dart';
import '../location/application/location_providers.dart';
import '../sos/application/sos_providers.dart';
import '../victims/application/victim_providers.dart';
import 'field_map_markers.dart';

const _ahmedabad = LatLng(23.0225, 72.5714);

/// Local operational plot. Tiles come from OSM when a link exists; markers
/// always come from this device's SQLite. Not mesh, not a digital twin, and
/// tiles are not cached for offline use.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _controller = MapController();
  final Set<FieldMapLayer> _layers = {...FieldMapLayer.values};
  var _mapReady = false;

  void _fit(List<FieldMapMarker> markers) {
    if (!_mapReady) return;
    if (markers.isEmpty) {
      _controller.move(_ahmedabad, 13);
      return;
    }
    final points = [
      for (final marker in markers) LatLng(marker.latitude, marker.longitude),
    ];
    if (points.length == 1) {
      _controller.move(points.first, 14);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentListProvider).value ?? const [];
    final victims = ref.watch(victimListProvider).value ?? const [];
    final hazards = ref.watch(hazardListProvider).value ?? const [];
    final sos = ref.watch(sosHistoryProvider).value ?? const [];
    final self = ref.watch(latestLocationProvider).value;
    final link = ref.watch(connectivityStatusProvider).value;
    final loadTiles = _shouldLoadTiles(link);

    final markers = visibleFieldMarkers(
      buildFieldMapMarkers(
        incidents: incidents.map(
          (row) => (
            id: row.id,
            label: row.title,
            lat: row.latitude,
            lng: row.longitude,
            subtitle: row.assignedZone,
            path: AppRoute.incidentDetailPath(row.id),
          ),
        ),
        victims: victims.map(
          (row) => (
            id: row.id,
            label: row.temporaryId,
            lat: row.latitude,
            lng: row.longitude,
            subtitle: row.triageCategory.wireValue,
            path: AppRoute.victimDetailPath(row.id),
          ),
        ),
        hazards: hazards.map(
          (row) => (
            id: row.id,
            label: row.hazardCode,
            lat: row.latitude,
            lng: row.longitude,
            subtitle: row.type.label,
            path: AppRoute.hazardDetailPath(row.id),
          ),
        ),
        sos: sos.map(
          (row) => (
            id: row.id,
            label: row.sosCode,
            lat: row.latitude,
            lng: row.longitude,
            subtitle: row.priority.wireValue,
            path: AppRoute.sosDetailPath(row.id),
          ),
        ),
        selfLat: self?.latitude,
        selfLng: self?.longitude,
        selfLabel: 'This device',
      ),
      _layers,
    );

    final center = markers.isEmpty
        ? _ahmedabad
        : LatLng(markers.first.latitude, markers.first.longitude);

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: LocalDataBanner(
            message:
                'Pins are records stored on this handset. Map tiles load from '
                'OpenStreetMap only while a network is available — they are not '
                'cached. This is not mesh networking.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final layer in FieldMapLayer.values)
                FilterChip(
                  label: Text(_layerLabel(layer)),
                  selected: _layers.contains(layer),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _layers.add(layer);
                      } else {
                        _layers.remove(layer);
                      }
                    });
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.navy900,
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.navy700),
              ),
            ),
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                backgroundColor: AppColors.navy900,
                initialCenter: center,
                initialZoom: markers.length <= 1 ? 14 : 12,
                onMapReady: () {
                  _mapReady = true;
                  _fit(markers);
                },
              ),
              children: [
                if (loadTiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.drp.drp_mobile',
                    tileProvider: NetworkTileProvider(
                      headers: const {
                        'User-Agent':
                            'drp-mobile/0.1 (offline-first disaster response field app)',
                      },
                    ),
                  ),
                MarkerLayer(
                  markers: [
                    for (final marker in markers)
                      Marker(
                        point: LatLng(marker.latitude, marker.longitude),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            if (marker.routePath != null) {
                              context.push(marker.routePath!);
                            }
                          },
                          child: Tooltip(
                            message: [
                              marker.label,
                              if (marker.subtitle != null) marker.subtitle,
                            ].join(' · '),
                            child: _Pin(layer: marker.layer),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _statusLine(markers: markers, loadTiles: loadTiles),
                  style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: () => _fit(markers),
                child: const Text('Fit'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _statusLine({
  required List<FieldMapMarker> markers,
  required bool loadTiles,
}) {
  final pins =
      '${markers.length} local pin${markers.length == 1 ? '' : 's'}';
  if (!loadTiles) {
    if (markers.isEmpty) {
      return 'Street tiles paused while this handset is offline. Capture GPS or register a record with a fix.';
    }
    return '$pins · street tiles paused while this handset is offline';
  }
  if (markers.isEmpty) {
    return 'No coordinates on this device yet. Capture GPS or register a record with a fix.';
  }
  return pins;
}

bool _shouldLoadTiles(ConnectivityStatus? status) {
  if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
  return status == ConnectivityStatus.online ||
      status == ConnectivityStatus.degraded;
}

String _layerLabel(FieldMapLayer layer) => switch (layer) {
      FieldMapLayer.self => 'Self',
      FieldMapLayer.incident => 'Incidents',
      FieldMapLayer.victim => 'Victims',
      FieldMapLayer.hazard => 'Hazards',
      FieldMapLayer.sos => 'SOS',
    };

class _Pin extends StatelessWidget {
  const _Pin({required this.layer});

  final FieldMapLayer layer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy800,
        shape: BoxShape.circle,
        border: Border.all(color: _layerColor(layer), width: 2),
      ),
      child: Icon(_layerIcon(layer), color: _layerColor(layer), size: 22),
    );
  }
}

IconData _layerIcon(FieldMapLayer layer) => switch (layer) {
      FieldMapLayer.self => Icons.navigation,
      FieldMapLayer.incident => Icons.flag,
      FieldMapLayer.victim => Icons.person_pin_circle,
      FieldMapLayer.hazard => Icons.warning_amber,
      FieldMapLayer.sos => Icons.emergency,
    };

Color _layerColor(FieldMapLayer layer) => switch (layer) {
      FieldMapLayer.self => AppColors.accentSoft,
      FieldMapLayer.incident => AppColors.accent,
      FieldMapLayer.victim => AppColors.critical,
      FieldMapLayer.hazard => AppColors.high,
      FieldMapLayer.sos => AppColors.elevated,
    };
