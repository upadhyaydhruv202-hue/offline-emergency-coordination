import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../connectivity/connectivity_providers.dart';
import '../../../connectivity/connectivity_status.dart';
import '../../application/victim_providers.dart';

/// States, on every victim screen, where the data actually is.
///
/// A responder must never have to guess whether what they just captured left
/// the device. In this slice nothing does, and the banner says so plainly
/// rather than showing a hopeful spinner.
class LocalDataBanner extends ConsumerWidget {
  const LocalDataBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityStatusProvider).value;
    final board = ref.watch(victimBoardProvider).value;
    final pending = board?.pendingSync ?? 0;

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
                label: pending == 0 ? 'NOTHING PENDING' : '$pending SYNC PENDING',
                color: pending == 0 ? AppColors.ink500 : AppColors.elevated,
                icon: Icons.cloud_upload_outlined,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Every record below was written to this device and is complete '
            'without the backend. Peer synchronisation arrives in a later '
            'slice, so nothing has left the handset yet.',
            style: TextStyle(
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
