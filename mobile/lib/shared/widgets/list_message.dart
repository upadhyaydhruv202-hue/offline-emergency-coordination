import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// The empty and failed states for an operational list.
///
/// Always says what happened and what the responder can do next. "No records"
/// on its own leaves someone wondering whether the list is empty or broken,
/// which are very different situations in the field.
class ListMessage extends StatelessWidget {
  const ListMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    this.action,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.navy700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink200,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
