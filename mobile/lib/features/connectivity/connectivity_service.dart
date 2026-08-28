import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'connectivity_status.dart';

/// Answers "did the coordination backend respond?".
typedef ReachabilityProbe = Future<bool> Function();

/// Answers "which links does this device currently have?".
typedef TransportSnapshot = Future<Set<ConnectivityTransport>> Function();

/// Observes the device's links and reports an operational [ConnectivityStatus].
///
/// Its collaborators are plain functions rather than the `connectivity_plus`
/// and `http` objects, so the whole service is testable without a platform
/// channel or a socket.
///
/// Slice 1 covers network interfaces only. Bluetooth, Wi-Fi Direct, LoRa and
/// multi-hop mesh are later slices; when they arrive they extend
/// [ConnectivityTransport] and the pure resolver, not this plumbing.
class ConnectivityService {
  ConnectivityService({
    TransportSnapshot? transportSnapshot,
    Stream<void>? transportChanges,
    ReachabilityProbe? probe,
    this.refreshInterval = AppConfig.connectivityRefreshInterval,
  }) : _transportSnapshot = transportSnapshot ?? platformTransportSnapshot,
       _transportChanges = transportChanges ?? platformTransportChanges(),
       _probe = probe ?? defaultReachabilityProbe;

  final TransportSnapshot _transportSnapshot;
  final Stream<void> _transportChanges;
  final ReachabilityProbe _probe;
  final Duration refreshInterval;

  final StreamController<ConnectivityStatus> _controller =
      StreamController<ConnectivityStatus>.broadcast();

  StreamSubscription<void>? _subscription;
  Timer? _timer;
  bool _hasEmitted = false;

  ConnectivityStatus _status = ConnectivityStatus.offline;

  /// Last evaluated status, available synchronously so the first frame can
  /// render something truthful.
  ConnectivityStatus get status => _status;

  Stream<ConnectivityStatus> get statusStream => _controller.stream;

  /// Evaluates immediately, then watches for link changes.
  Future<void> start() async {
    await refresh();
    _subscription = _transportChanges.listen((_) => unawaited(refresh()));
    _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
  }

  /// Re-evaluates now. Safe to call at any time.
  Future<ConnectivityStatus> refresh() async {
    final transports = await _readTransports();

    final hasLink = transports.any(
      (transport) => transport != ConnectivityTransport.none,
    );

    // Probing with no link would only drain the battery.
    final reachable = hasLink && await _probe();

    return _emit(
      resolveConnectivityStatus(
        transports: transports,
        backendReachable: reachable,
      ),
    );
  }

  Future<Set<ConnectivityTransport>> _readTransports() async {
    try {
      return await _transportSnapshot();
    } on Exception {
      // A failing platform channel is indistinguishable from having no link,
      // and the safe assumption in the field is that there is none.
      return {ConnectivityTransport.none};
    }
  }

  ConnectivityStatus _emit(ConnectivityStatus next) {
    final changed = !_hasEmitted || next != _status;
    _status = next;
    _hasEmitted = true;
    if (changed && !_controller.isClosed) _controller.add(next);
    return next;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Reads the current links from `connectivity_plus`.
Future<Set<ConnectivityTransport>> platformTransportSnapshot() async {
  final results = await Connectivity().checkConnectivity();
  return results.map(mapConnectivityResult).toSet();
}

/// Fires whenever the platform reports a link change.
Stream<void> platformTransportChanges() =>
    Connectivity().onConnectivityChanged.map<void>((_) {});

/// Translates a `connectivity_plus` result into a transport this app models.
ConnectivityTransport mapConnectivityResult(ConnectivityResult result) =>
    switch (result) {
      ConnectivityResult.wifi => ConnectivityTransport.wifi,
      ConnectivityResult.mobile => ConnectivityTransport.mobile,
      ConnectivityResult.ethernet => ConnectivityTransport.ethernet,
      ConnectivityResult.vpn => ConnectivityTransport.vpn,
      ConnectivityResult.satellite => ConnectivityTransport.satellite,
      ConnectivityResult.bluetooth => ConnectivityTransport.bluetooth,
      ConnectivityResult.other => ConnectivityTransport.other,
      ConnectivityResult.none => ConnectivityTransport.none,
    };

/// Probes the backend's liveness endpoint with a short timeout.
Future<bool> defaultReachabilityProbe() async {
  final client = http.Client();
  try {
    final response = await client
        .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
        .timeout(AppConfig.reachabilityTimeout);
    return response.statusCode == 200;
  } on Exception {
    return false;
  } finally {
    client.close();
  }
}
