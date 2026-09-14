import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/hazard_draft.dart';
import '../../../../domain/entities/hazard_severity.dart';
import '../../../../domain/entities/hazard_status.dart';
import '../../../../domain/entities/hazard_type.dart';
import '../../../../domain/entities/location_fix.dart';
import '../../../../shared/widgets/form_failure.dart';
import '../../../../shared/widgets/ops_visuals.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../location/application/location_providers.dart';

/// The hazard report form.
///
/// Type and severity are the only required decisions. A responder who can see
/// something dangerous should be able to file it in a few seconds and add
/// detail later, so the description is optional and the position is best-effort.
class HazardForm extends ConsumerStatefulWidget {
  const HazardForm({
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.showStatus = false,
    super.key,
  });

  final HazardDraft initial;
  final String submitLabel;

  /// Returns an error message to display, or null when the save succeeded.
  final Future<String?> Function(HazardDraft draft) onSubmit;

  /// Status is offered when editing; a new report is always REPORTED.
  final bool showStatus;

  @override
  ConsumerState<HazardForm> createState() => _HazardFormState();
}

class _HazardFormState extends ConsumerState<HazardForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _description;

  late HazardType _type;
  late HazardSeverity _severity;
  late HazardStatus _status;
  late LocationFix? _position;

  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _description =
        TextEditingController(text: widget.initial.description ?? '');
    _type = widget.initial.type;
    _severity = widget.initial.severity;
    _status = widget.initial.status;
    _position = widget.initial.position;
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  /// Reads a position from the device's own receiver.
  ///
  /// Failure is reported inline and does not block the report: a hazard with no
  /// coordinates is still a hazard the next team needs to know about.
  Future<void> _captureLocation() async {
    final record = await ref.read(locationCaptureProvider.notifier).refresh();
    if (!mounted) return;
    if (record != null) setState(() => _position = record.fix);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final failure = await widget.onSubmit(
      HazardDraft(
        type: _type,
        severity: _severity,
        description: _description.text,
        status: _status,
        position: _position,
      ),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final capture = ref.watch(locationCaptureProvider);
    final position = _position;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const FieldLabel('Hazard type'),
          const SizedBox(height: 10),
          DropdownButtonFormField<HazardType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'What did you find?'),
            items: [
              for (final type in HazardType.values)
                DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(hazardTypeIcon(type), size: 16),
                      const SizedBox(width: 10),
                      Text(type.label),
                    ],
                  ),
                ),
            ],
            onChanged:
                _busy ? null : (value) => setState(() => _type = value ?? _type),
          ),

          const SizedBox(height: 20),
          const FieldLabel('Severity'),
          const SizedBox(height: 4),
          const Text(
            'Determines where the hazard sorts in every list another responder '
            'opens.',
            style: TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          for (final severity in HazardSeverity.bySeverity)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SeverityOption(
                severity: severity,
                selected: _severity == severity,
                onTap: _busy ? null : () => setState(() => _severity = severity),
              ),
            ),

          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Gas smell at the north stairwell, do not use lights',
              alignLabelWithHint: true,
            ),
          ),

          if (widget.showStatus) ...[
            const SizedBox(height: 20),
            const FieldLabel('Status'),
            const SizedBox(height: 10),
            DropdownButtonFormField<HazardStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Current status'),
              items: [
                for (final status in HazardStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _status = value ?? _status),
            ),
          ],

          const SizedBox(height: 20),
          const FieldLabel('Location'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.navy700),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (position == null)
                  const Text(
                    'No position attached. The report can still be filed — '
                    'coordinates are useful, not mandatory.',
                    style: TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  )
                else ...[
                  Text(
                    '${position.latitudeLabel}   ${position.longitudeLabel}',
                    style: const TextStyle(
                      color: AppColors.ink100,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Accuracy ${position.accuracyLabel} · taken '
                    '${position.timeLabel}',
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 11,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      _busy || capture.isCapturing ? null : _captureLocation,
                  icon: capture.isCapturing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(
                    position == null
                        ? 'Capture current location'
                        : 'Capture again',
                  ),
                ),
                if (capture.failure case final failure?) ...[
                  const SizedBox(height: 10),
                  Text(
                    failure,
                    style: const TextStyle(
                      color: AppColors.elevated,
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'GPS is a satellite service. This works with the radio off '
                  'and no network at all.',
                  style: TextStyle(
                    color: AppColors.ink500,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          if (_failure != null) ...[
            const SizedBox(height: 16),
            FormFailure(message: _failure!),
          ],

          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.submitLabel),
          ),
          const SizedBox(height: 12),
          const Text(
            'Saving writes to this device only. No network is used, and the '
            'report is authoritative the moment it is stored.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityOption extends StatelessWidget {
  const _SeverityOption({
    required this.severity,
    required this.selected,
    required this.onTap,
  });

  final HazardSeverity severity;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = hazardSeverityColor(severity);

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
                      severity.label,
                      style: TextStyle(
                        color: selected ? color : AppColors.ink200,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      severity.guidance,
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
