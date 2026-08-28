import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'status_chip.dart';

/// A bordered block with a caption, a prominent value and optional trailing
/// status. This is the unit the responder home screen is built from.
class OperationalPanel extends StatelessWidget {
  const OperationalPanel({
    required this.label,
    required this.value,
    this.detail,
    this.trailing,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final String? detail;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent ?? AppColors.navy600),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FieldLabel(label),
                          const SizedBox(height: 6),
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppColors.ink100,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                          if (detail != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              detail!,
                              style: const TextStyle(
                                color: AppColors.ink400,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 12),
                      trailing!,
                    ],
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
