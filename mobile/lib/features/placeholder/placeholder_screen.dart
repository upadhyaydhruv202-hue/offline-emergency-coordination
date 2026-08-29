import 'package:flutter/material.dart';

import '../../app/router/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../shared/widgets/status_chip.dart';

/// Describes a module that is routed but not yet built.
class PlaceholderSpec {
  const PlaceholderSpec({
    required this.route,
    required this.slice,
    required this.summary,
    required this.scope,
  });

  final AppRoute route;
  final int slice;
  final String summary;
  final List<String> scope;
}

/// Honest stand-in for an unimplemented module.
///
/// It states which slice delivers the module and what that slice covers. It
/// deliberately shows no fabricated operational content.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({required this.spec, super.key});

  final PlaceholderSpec spec;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      children: [
        const Icon(
          Icons.construction_outlined,
          size: 32,
          color: AppColors.elevated,
        ),
        const SizedBox(height: 16),
        Text(
          spec.route.title,
          style: const TextStyle(
            color: AppColors.ink100,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        StatusChip(
          label: 'COMING IN SLICE ${spec.slice}',
          color: AppColors.elevated,
        ),
        const SizedBox(height: 16),
        Text(
          'Coming in the next development slice. ${spec.summary}',
          style: const TextStyle(
            color: AppColors.ink300,
            fontSize: 14,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const FieldLabel('Planned scope'),
        const SizedBox(height: 10),
        for (final item in spec.scope)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '—  ',
                  style: TextStyle(color: AppColors.ink500),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        const Text(
          'Nothing on this screen is simulated. The module is genuinely not '
          'implemented in this build.',
          style: TextStyle(
            color: AppColors.ink500,
            fontSize: 11,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
