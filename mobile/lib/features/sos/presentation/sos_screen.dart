import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/field_ops_boards.dart';
import '../../../domain/entities/sos_event.dart';
import '../../../domain/entities/sos_priority.dart';
import '../../../shared/widgets/count_tile.dart';
import '../../../shared/widgets/list_message.dart';
import '../../../shared/widgets/local_data_banner.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../location/application/location_providers.dart';
import '../application/sos_providers.dart';
import 'widgets/sos_confirm_sheet.dart';
import 'widgets/sos_list_tile.dart';

/// The emergency action, and every call raised on this device.
///
/// The button is the largest target on the screen and is always in the same
/// place, because a responder using it is likely to be injured, in the dark, or
/// wearing gloves. It is also guarded by a confirmation, because the same
/// properties make it easy to press by accident.
class SosScreen extends ConsumerWidget {
  const SosScreen({super.key});

  Future<void> _raise(BuildContext context, WidgetRef ref) async {
    final hasPosition = ref.read(latestLocationProvider).value != null;

    final confirmation = await showModalBottomSheet<SosConfirmation>(
      context: context,
      backgroundColor: AppColors.navy900,
      isScrollControlled: true,
      builder: (context) => SosConfirmSheet(hasPosition: hasPosition),
    );
    if (confirmation == null || !context.mounted) return;

    try {
      final event = await ref.read(sosServiceProvider).raise(
            priority: confirmation.priority,
            message: confirmation.message,
          );
      if (!context.mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => _SosCreatedDialog(event: event),
      );
    } on Exception catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.critical,
          content: Text('The SOS could not be stored on this device: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(sosHistoryProvider);
    final board = ref.watch(sosBoardProvider).value ?? SosBoard.empty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SosButton(onPressed: () => _raise(context, ref)),
        const SizedBox(height: 18),

        const LocalDataBanner(
          message: 'An SOS raised here is written to this device and nothing '
              'else. There is no transport in this build — no message, no call, '
              'no relay — so keep using your radio to call for help.',
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            for (final priority in SosPriority.byUrgency) ...[
              Expanded(
                child: CountTile(
                  label: priority.wireValue,
                  count: board.countOf(priority),
                  color: sosPriorityColor(priority),
                ),
              ),
              if (priority != SosPriority.byUrgency.last)
                const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 18),

        const FieldLabel('SOS history'),
        const SizedBox(height: 10),

        history.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => ListMessage(
            icon: Icons.error_outline,
            color: AppColors.critical,
            title: 'The local database could not be read',
            detail: error.toString(),
          ),
          data: (events) => events.isEmpty
              ? const ListMessage(
                  icon: Icons.emergency_outlined,
                  color: AppColors.ink500,
                  title: 'No SOS raised on this device',
                  detail: 'Anything raised with the button above appears here '
                      'immediately and survives a restart.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 2),
                      child: Text(
                        '${events.length} on this device · ${board.open} open',
                        style: const TextStyle(
                          color: AppColors.ink500,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SosListTile(
                          event: event,
                          onTap: () =>
                              context.push(AppRoute.sosDetailPath(event.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// The emergency action.
///
/// Deliberately the only red-filled control in the application, at a size that
/// can be hit without aiming.
class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Create emergency SOS. Asks for confirmation.',
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.critical,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emergency_outlined, size: 30),
            SizedBox(height: 8),
            Text(
              'CREATE SOS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The receipt shown immediately after a call is stored.
///
/// It states what was captured and what state the record is in, and it does not
/// claim anybody has been notified.
class _SosCreatedDialog extends StatelessWidget {
  const _SosCreatedDialog({required this.event});

  final SosEvent event;

  @override
  Widget build(BuildContext context) {
    final position = event.position;

    return AlertDialog(
      backgroundColor: AppColors.navy900,
      title: const Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.nominal, size: 20),
          SizedBox(width: 10),
          Text('SOS CREATED', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            event.sosCode,
            style: const TextStyle(
              color: AppColors.ink100,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),
          _ReceiptRow(
            label: 'Location',
            value: position == null
                ? 'Not available'
                : 'Captured · ${position.latitudeLabel} '
                    '${position.longitudeLabel}',
          ),
          _ReceiptRow(label: 'Time', value: event.raisedAt.toLocal().toString()),
          _ReceiptRow(label: 'Priority', value: event.priority.label),
          _ReceiptRow(label: 'Status', value: 'SYNC PENDING'),
          const SizedBox(height: 12),
          const Text(
            'Stored on this device. Nothing has been transmitted.',
            style: TextStyle(
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

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink200,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
