import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Marks fabricated content. Mandatory wherever Slice 1 shows a value it did
/// not actually observe.
class DemoDataBanner extends StatelessWidget {
  const DemoDataBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.elevated.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.elevated.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            size: 16,
            color: AppColors.elevated,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'DEMO DATA — ',
                    style: TextStyle(
                      color: AppColors.elevated,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextSpan(
                    text: message,
                    style: const TextStyle(
                      color: AppColors.ink300,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
