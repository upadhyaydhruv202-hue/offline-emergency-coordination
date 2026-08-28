import 'package:drp_mobile/features/connectivity/connectivity_service.dart';
import 'package:drp_mobile/features/connectivity/connectivity_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveConnectivityStatus', () {
    test('no transports at all is OFFLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: <ConnectivityTransport>{},
          backendReachable: false,
        ),
        ConnectivityStatus.offline,
      );
    });

    test('an explicit "none" transport is OFFLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: {ConnectivityTransport.none},
          backendReachable: false,
        ),
        ConnectivityStatus.offline,
      );
    });

    test('a reachable backend over wifi is ONLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: {ConnectivityTransport.wifi},
          backendReachable: true,
        ),
        ConnectivityStatus.online,
      );
    });

    test('a link whose backend probe failed is DEGRADED, never ONLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: {ConnectivityTransport.mobile},
          backendReachable: false,
        ),
        ConnectivityStatus.degraded,
      );
    });

    test('bluetooth alone is DEGRADED: a link, but not an internet path', () {
      expect(
        resolveConnectivityStatus(
          transports: {ConnectivityTransport.bluetooth},
          backendReachable: false,
        ),
        ConnectivityStatus.degraded,
      );
    });

    test('bluetooth alongside a reachable uplink is ONLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: {
            ConnectivityTransport.bluetooth,
            ConnectivityTransport.wifi,
          },
          backendReachable: true,
        ),
        ConnectivityStatus.online,
      );
    });

    test('"none" mixed with a usable transport does not force OFFLINE', () {
      expect(
        resolveConnectivityStatus(
          transports: {
            ConnectivityTransport.none,
            ConnectivityTransport.ethernet,
          },
          backendReachable: true,
        ),
        ConnectivityStatus.online,
      );
    });

    test('every transport resolves to a defined status', () {
      for (final transport in ConnectivityTransport.values) {
        expect(
          () => resolveConnectivityStatus(
            transports: {transport},
            backendReachable: false,
          ),
          returnsNormally,
        );
      }
    });
  });

  group('ConnectivityService', () {
    ConnectivityService build({
      required Set<ConnectivityTransport> transports,
      required Future<bool> Function() probe,
    }) {
      final service = ConnectivityService(
        transportSnapshot: () async => transports,
        transportChanges: const Stream<void>.empty(),
        probe: probe,
      );
      addTearDown(service.dispose);
      return service;
    }

    test('reports OFFLINE and skips the probe when there is no link', () async {
      var probeCalls = 0;
      final service = build(
        transports: {ConnectivityTransport.none},
        probe: () async {
          probeCalls++;
          return true;
        },
      );

      expect(await service.refresh(), ConnectivityStatus.offline);
      expect(probeCalls, 0, reason: 'probing with no link only drains battery');
    });

    test('reports ONLINE when a link exists and the probe succeeds', () async {
      final service = build(
        transports: {ConnectivityTransport.wifi},
        probe: () async => true,
      );

      expect(await service.refresh(), ConnectivityStatus.online);
      expect(service.status, ConnectivityStatus.online);
    });

    test('reports DEGRADED when the link is up but the probe fails', () async {
      final service = build(
        transports: {ConnectivityTransport.wifi},
        probe: () async => false,
      );

      expect(await service.refresh(), ConnectivityStatus.degraded);
    });

    test('treats a failing transport lookup as OFFLINE', () async {
      final service = ConnectivityService(
        transportSnapshot: () async =>
            throw Exception('platform channel unavailable'),
        transportChanges: const Stream<void>.empty(),
        probe: () async => true,
      );
      addTearDown(service.dispose);

      expect(await service.refresh(), ConnectivityStatus.offline);
    });

    test('defaults to OFFLINE before the first evaluation', () {
      final service = build(
        transports: {ConnectivityTransport.wifi},
        probe: () async => true,
      );

      expect(service.status, ConnectivityStatus.offline);
    });

    test('emits the first evaluation, then only on change', () async {
      var reachable = true;
      final service = build(
        transports: {ConnectivityTransport.wifi},
        probe: () async => reachable,
      );

      final seen = <ConnectivityStatus>[];
      final subscription = service.statusStream.listen(seen.add);

      await service.refresh();
      await service.refresh();
      reachable = false;
      await service.refresh();
      await pumpEventQueue();
      await subscription.cancel();

      expect(seen, [ConnectivityStatus.online, ConnectivityStatus.degraded]);
    });

    test('start performs an immediate evaluation', () async {
      final service = build(
        transports: {ConnectivityTransport.ethernet},
        probe: () async => true,
      );

      await service.start();

      expect(service.status, ConnectivityStatus.online);
    });
  });
}
