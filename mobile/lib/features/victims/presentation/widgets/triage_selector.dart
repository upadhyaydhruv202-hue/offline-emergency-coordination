import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/triage_category.dart';
import 'victim_visuals.dart';

/// Assigns a triage category.
///
/// Deliberately four large targets rather than a dropdown: this is the one
/// decision on the form that matters most, it is taken in gloves, and it must
/// be readable without focusing on small text.
class TriageSelector extends StatelessWidget {
  const TriageSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final TriageCategory selected;
  final ValueChanged<TriageCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in TriageCategory.byUrgency)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TriageOption(
              category: category,
              selected: category == selected,
              onTap: () => onChanged(category),
            ),
          ),
      ],
    );
  }
}

class _TriageOption extends StatelessWidget {
  const _TriageOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final TriageCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = triageColor(category);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Triage ${category.label}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.16)
                : AppColors.navy850,
            border: Border.all(
              color: selected ? color : AppColors.navy600,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.wireValue,
                      style: TextStyle(
                        color: selected ? color : AppColors.ink200,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category.guidance,
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
                Icon(Icons.check_circle, size: 18, color: color)
              else
                const Icon(
                  Icons.circle_outlined,
                  size: 18,
                  color: AppColors.navy600,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
