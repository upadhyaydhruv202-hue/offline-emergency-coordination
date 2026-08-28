import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../data/local/database_providers.dart';

/// Shown while the local session is read back from SQLite.
///
/// The wait is real work, not a splash animation: until the datastore is open
/// the app does not know who is holding the device.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(localDatabaseHealthProvider);

    final statusLine = health.when(
      data: (value) => value.isReady
          ? 'Local datastore ready · schema v${value.schemaVersion}'
          : 'Local datastore unavailable',
      loading: () => 'Opening local datastore…',
      error: (error, _) => 'Local datastore error',
    );

    return Scaffold(
      backgroundColor: AppColors.navy950,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.radar, size: 48, color: AppColors.accentSoft),
            const SizedBox(height: 20),
            const Text(
              'DISASTER RESPONSE PLATFORM',
              style: TextStyle(
                color: AppColors.ink100,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Field coordination · offline first',
              style: TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 18),
            Text(
              statusLine,
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
