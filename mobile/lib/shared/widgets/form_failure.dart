import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Why a save did not happen, shown inline above the submit button.
///
/// Inline rather than a snack bar: a responder who is looking at the form needs
/// the reason to stay on screen next to what caused it, not to vanish after four
/// seconds while they were reading something else.
class FormFailure extends StatelessWidget {
  const FormFailure({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.critical.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.critical.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.critical),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.critical,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
