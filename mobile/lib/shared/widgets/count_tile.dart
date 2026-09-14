import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// One number in a summary row, colour-coded by what it counts.
///
/// The point of a summary board is that it reads at arm's length, so the count
/// is large and the caption is small. The dot repeats the colour for anyone who
/// cannot rely on the text colour alone.
class CountTile extends StatelessWidget {
  const CountTile({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.navy850,
        border: Border.all(color: AppColors.navy700),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              color: AppColors.ink100,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: '$label: $count',
      button: onTap != null,
      child: onTap == null
          ? tile
          : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(6),
              child: tile,
            ),
    );
  }
}
