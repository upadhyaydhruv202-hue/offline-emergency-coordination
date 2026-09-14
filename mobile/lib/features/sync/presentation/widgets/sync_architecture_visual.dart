import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

class SyncArchitectureVisual extends StatelessWidget {
  const SyncArchitectureVisual({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text(
              'TRANSPORT-INDEPENDENT SYNC',
              style: TextStyle(
                color: AppColors.ink500,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'FIELD DEVICE A  →  LOCAL DB  →  OPERATION A\n'
              'FIELD DEVICE B  →  LOCAL DB  →  OPERATION B\n'
              '        ↓\n'
              '   SIMULATED TRANSPORT  (later: BLE / Wi-Fi Direct / LoRa)\n'
              '        ↓\n'
              '   SYNC SERVICE  →  CRDT ENGINE\n'
              '        ↓\n'
              '   CONFLICT DETECTED  →  DETERMINISTIC MERGE\n'
              '        ↓\n'
              '   SHARED STATE   DEVICE A = DEVICE B',
              style: TextStyle(
                color: AppColors.ink200,
                fontFamily: 'Roboto',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
