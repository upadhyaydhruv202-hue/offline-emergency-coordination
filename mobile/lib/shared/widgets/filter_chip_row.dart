import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A horizontally scrolling row of filters.
///
/// Scrolling rather than wrapping: an operational list has several filter
/// dimensions, and letting them wrap would push the records themselves off the
/// first screen on a handset.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) => children[index],
      ),
    );
  }
}

/// One filter. Selected state is carried by the border and a wash of the
/// filter's own colour, never by colour alone — the label is always present.
class OpsFilterChip extends StatelessWidget {
  const OpsFilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
            border: Border.all(color: selected ? color : AppColors.navy600),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.ink400,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
