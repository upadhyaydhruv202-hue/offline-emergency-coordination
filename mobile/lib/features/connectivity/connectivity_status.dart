/// Operational connectivity, as a responder needs to understand it.
enum ConnectivityStatus {
  /// A network interface is up and the coordination backend answered.
  online('ONLINE'),

  /// An interface is up but the backend did not answer, or the only link
  /// available cannot carry internet traffic. Work continues locally.
  degraded('DEGRADED'),

  /// No usable interface at all.
  offline('OFFLINE');

  const ConnectivityStatus(this.label);

  final String label;
}

/// Link types the device can report.
///
/// Deliberately independent of `connectivity_plus` so the decision logic below
/// can be unit-tested without a platform channel.
enum ConnectivityTransport {
  wifi,
  mobile,
  ethernet,
  vpn,
  satellite,
  bluetooth,
  other,
  none,
}

/// Transports that can plausibly reach the coordination backend.
///
/// Satellite counts. It is slow and the platform flags it as constrained, but
/// in a disaster zone it is frequently the only uplink left, and a responder
/// who has one should be told the backend is reachable.
const Set<ConnectivityTransport> _internetCapable = {
  ConnectivityTransport.wifi,
  ConnectivityTransport.mobile,
  ConnectivityTransport.ethernet,
  ConnectivityTransport.vpn,
  ConnectivityTransport.satellite,
  ConnectivityTransport.other,
};

/// Maps a link inventory plus a reachability result onto an operational state.
///
/// Kept pure on purpose: this is the rule the whole UI depends on, and it must
/// be verifiable without a device.
///
/// - No usable link, or only `none`, is [ConnectivityStatus.offline].
/// - Bluetooth alone is [ConnectivityStatus.degraded]: it is a real link and
///   will carry mesh traffic in a later slice, but it is not an internet path.
/// - A usable link whose backend probe failed is [ConnectivityStatus.degraded];
///   captive portals and dead uplinks are common in a disaster zone, and
///   reporting them as ONLINE would mislead a responder.
ConnectivityStatus resolveConnectivityStatus({
  required Set<ConnectivityTransport> transports,
  required bool backendReachable,
}) {
  final usable = transports
      .where((transport) => transport != ConnectivityTransport.none)
      .toSet();

  if (usable.isEmpty) return ConnectivityStatus.offline;

  final hasInternetPath = usable.any(_internetCapable.contains);
  if (!hasInternetPath) return ConnectivityStatus.degraded;

  return backendReachable
      ? ConnectivityStatus.online
      : ConnectivityStatus.degraded;
}
