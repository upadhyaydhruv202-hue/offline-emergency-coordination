import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/hazard.dart';
import '../../../domain/entities/hazard_draft.dart';
import '../../../domain/entities/hazard_severity.dart';
import '../../../domain/entities/hazard_type.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../application/hazard_providers.dart';
import 'widgets/hazard_form.dart';

/// Files a new hazard report against local storage.
///
/// There is no "saving…" round trip and no way for this screen to fail because
/// of the network: the only thing between the responder and a stored report is a
/// SQLite write.
class HazardReportScreen extends ConsumerWidget {
  const HazardReportScreen({super.key});

  Future<void> _showReported(BuildContext context, Hazard hazard) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _HazardReportedDialog(hazard: hazard),
    );
    if (!context.mounted) return;
    context.pushReplacement(AppRoute.hazardDetailPath(hazard.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Hazard')),
      body: SafeArea(
        child: HazardForm(
          initial: const HazardDraft(
            type: HazardType.buildingDamage,
            severity: HazardSeverity.high,
          ),
          submitLabel: 'Save to this device',
          onSubmit: (draft) async {
            try {
              final hazard = await ref.read(hazardServiceProvider).report(draft);
              if (!context.mounted) return null;

              // Return first so the form can drop its spinner; the receipt
              // dialog is a separate step and must not keep the page animating.
              unawaited(_showReported(context, hazard));
              return null;
            } on Exception catch (error) {
              return 'The report could not be written to this device: $error';
            }
          },
        ),
      ),
    );
  }
}

/// The receipt shown immediately after a report is stored.
class _HazardReportedDialog extends StatelessWidget {
  const _HazardReportedDialog({required this.hazard});

  final Hazard hazard;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.navy900,
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.nominal, size: 20),
          SizedBox(width: 10),
          Text('HAZARD REPORTED', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hazardTypeIcon(hazard.type),
                size: 18,
                color: hazardSeverityColor(hazard.severity),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${hazard.hazardCode} · ${hazard.type.label}',
                  style: const TextStyle(
                    color: AppColors.ink100,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'LOCAL RECORD CREATED\nSYNC PENDING',
            style: TextStyle(
              color: AppColors.elevated,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.6,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hazard.hasPosition
                ? 'A position was attached from this device\'s receiver.'
                : 'No position was attached. The report is still complete.',
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CLOSE'),
        ),
      ],
    );
  }
}
