import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../features/connectivity/connectivity_providers.dart';
import '../../features/connectivity/connectivity_status.dart';
import '../../features/sync/application/pending_changes_provider.dart';
import 'status_chip.dart';

/// States, on every operational screen, where the data actually is.
///
/// A responder must never have to guess whether what they just captured left the
/// device. In this slice nothing does, and the banner says so plainly rather than
/// showing a hopeful spinner.
///
/// The pending count covers every field record on the handset, not just the
/// module being viewed: a responder deciding whether it is safe to hand the
/// device in, or to walk out of a sector, needs the whole number.
class LocalDataBanner extends ConsumerWidget {
  const LocalDataBanner({this.message, super.key});

  /// Replaces the default explanation when a module needs to say something more
  /// specific about what is stored.
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStatusProvider).value;
    final pending = ref.watch(pendingChangesProvider);

    final (connectivityColor, connectivityLabel) = switch (connectivity) {
      ConnectivityStatus.online => (AppColors.nominal, 'ONLINE'),
      ConnectivityStatus.degraded => (AppColors.elevated, 'DEGRADED'),
      ConnectivityStatus.offline => (AppColors.critical, 'OFFLINE'),
      null => (AppColors.ink500, 'CHECKING'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.navy700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              const StatusChip(
                label: 'LOCAL DATA',
                color: AppColors.accentSoft,
                icon: Icons.sd_storage_outlined,
              ),
              StatusChip(
                label: connectivityLabel,
                color: connectivityColor,
                icon: Icons.wifi_tethering,
              ),
              StatusChip(
                label: pending == 0
                    ? 'NOTHING PENDING'
                    : '$pending ${pending == 1 ? 'CHANGE' : 'CHANGES'} PENDING',
                color: pending == 0 ? AppColors.ink500 : AppColors.elevated,
                icon: Icons.cloud_upload_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message ??
                'Every record below was written to this device and is complete '
                    'without the backend. Peer synchronisation arrives in a '
                    'later slice, so nothing has left the handset yet.',
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
