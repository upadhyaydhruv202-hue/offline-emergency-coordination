import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/responder_status.dart';
import '../../../../shared/widgets/ops_visuals.dart';

/// Where a responder changes their own operational status.
///
/// A sheet rather than a screen: the status changes several times a shift, and
/// it must never be more than two taps from the dashboard.
class ResponderStatusSheet extends StatelessWidget {
  const ResponderStatusSheet({required this.current, super.key});

  final ResponderStatus current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Responder status',
              style: TextStyle(
                color: AppColors.ink100,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Stored on this device. Command will see it when synchronisation '
              'arrives, so keep using your radio for anything urgent.',
              style: TextStyle(
                color: AppColors.ink500,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final status in ResponderStatus.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StatusOption(
                          status: status,
                          selected: status == current,
                          onTap: () => Navigator.of(context).pop(status),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ResponderStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = responderStatusColor(status);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: selected ? color : AppColors.navy600),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(responderStatusIcon(status), size: 20, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.label,
                      style: TextStyle(
                        color: selected ? color : AppColors.ink200,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      status.guidance,
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check, size: 18, color: AppColors.ink300),
            ],
          ),
        ),
      ),
    );
  }
}
