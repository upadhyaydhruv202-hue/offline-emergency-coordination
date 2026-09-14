import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/sos_priority.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';

/// What the responder confirms before a distress call is raised.
///
/// The confirmation exists because the button is deliberately easy to hit with a
/// gloved hand, and a false alarm costs a team a diversion. It is a single extra
/// tap, not a dialog to read: the priority is chosen here rather than on a
/// separate screen so the whole action stays two taps deep.
///
/// The wording is careful not to promise delivery. Nothing in this build can
/// send anything, and a responder who believes help has been dispatched when it
/// has not is worse off than one who knows they still need the radio.
class SosConfirmSheet extends StatefulWidget {
  const SosConfirmSheet({this.hasPosition = false, super.key});

  /// Whether the device has a position it can attach. Shown honestly either way.
  final bool hasPosition;

  @override
  State<SosConfirmSheet> createState() => _SosConfirmSheetState();
}

/// The responder's answer: which priority, and any note.
class SosConfirmation {
  const SosConfirmation({required this.priority, this.message});

  final SosPriority priority;
  final String? message;
}

class _SosConfirmSheetState extends State<SosConfirmSheet> {
  final _message = TextEditingController();
  SosPriority _priority = SosPriority.critical;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Create Emergency SOS?',
                style: TextStyle(
                  color: AppColors.ink100,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your current location and emergency information will be stored '
                'locally and marked for synchronisation.',
                style: TextStyle(
                  color: AppColors.ink300,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.elevated.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.elevated.withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppColors.elevated,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This does not transmit. Nothing leaves the handset in '
                        'this build — keep using your radio to call for help.',
                        style: TextStyle(
                          color: AppColors.elevated,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const FieldLabel('Priority'),
              const SizedBox(height: 10),
              for (final priority in SosPriority.byUrgency)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _PriorityOption(
                    priority: priority,
                    selected: _priority == priority,
                    onTap: () => setState(() => _priority = priority),
                  ),
                ),

              const SizedBox(height: 12),
              TextField(
                controller: _message,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message (optional)',
                  hintText: 'Trapped on second floor, structure shifting',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    widget.hasPosition
                        ? Icons.my_location
                        : Icons.location_disabled_outlined,
                    size: 15,
                    color: widget.hasPosition
                        ? AppColors.nominal
                        : AppColors.ink500,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.hasPosition
                          ? 'A position will be attached. The device will try '
                              'for a fresh reading first.'
                          : 'No position has been recorded on this device yet. '
                              'The call will still be raised without one.',
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('CANCEL'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(
                        SosConfirmation(
                          priority: _priority,
                          message: _message.text,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.critical,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                      child: const Text('CREATE SOS'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.priority,
    required this.selected,
    required this.onTap,
  });

  final SosPriority priority;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sosPriorityColor(priority);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
            border: Border.all(color: selected ? color : AppColors.navy600),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected ? color : AppColors.ink500,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      priority.label,
                      style: TextStyle(
                        color: selected ? color : AppColors.ink200,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      priority.guidance,
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
