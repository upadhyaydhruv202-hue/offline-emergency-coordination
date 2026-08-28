import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_service.dart';
import 'connectivity_status.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => unawaited(service.dispose()));
  unawaited(service.start());
  return service;
});

/// Current connectivity, seeded with the service's cached value so the first
/// frame does not have to render an indeterminate state.
final connectivityStatusProvider =
    StreamProvider<ConnectivityStatus>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield service.status;
  yield* service.statusStream;
});
