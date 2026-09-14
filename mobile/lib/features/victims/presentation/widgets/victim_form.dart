import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/triage_category.dart';
import '../../../../domain/entities/victim_demographics.dart';
import '../../../../domain/entities/victim_draft.dart';
import '../../../../domain/entities/victim_status.dart';
import '../../../../shared/widgets/form_failure.dart';
import '../../../../shared/widgets/status_chip.dart';
import 'triage_selector.dart';

/// The registration and reassessment form.
///
/// Only the triage category is mandatory. A responder who has thirty seconds
/// with an unconscious stranger must still be able to produce a usable record,
/// so every identifying field is optional and blank means "not established"
/// rather than blocking the save.
class VictimForm extends StatefulWidget {
  const VictimForm({
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.showStatus = false,
    super.key,
  });

  final VictimDraft initial;
  final String submitLabel;

  /// Returns an error message to display, or null when the save succeeded.
  final Future<String?> Function(VictimDraft draft) onSubmit;

  /// Status is set on the detail screen for an existing record; the register
  /// form does not ask for it, because a new record is always REGISTERED.
  final bool showStatus;

  @override
  State<VictimForm> createState() => _VictimFormState();
}

class _VictimFormState extends State<VictimForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _injury;
  late final TextEditingController _condition;
  late final TextEditingController _assistance;

  late TriageCategory _triage;
  late Gender _gender;
  late VictimStatus _status;

  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name ?? '');
    _age = TextEditingController(text: widget.initial.age?.toString() ?? '');
    _injury = TextEditingController(text: widget.initial.injuryType ?? '');
    _condition =
        TextEditingController(text: widget.initial.medicalCondition ?? '');
    _assistance =
        TextEditingController(text: widget.initial.assistanceRequired ?? '');
    _triage = widget.initial.triageCategory;
    _gender = widget.initial.gender;
    _status = widget.initial.status;
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _injury.dispose();
    _condition.dispose();
    _assistance.dispose();
    super.dispose();
  }

  int? get _parsedAge {
    final text = _age.text.trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final failure = await widget.onSubmit(
      VictimDraft(
        triageCategory: _triage,
        name: _name.text,
        age: _parsedAge,
        gender: _gender,
        injuryType: _injury.text,
        medicalCondition: _condition.text,
        assistanceRequired: _assistance.text,
        status: _status,
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
    final ageGroup = AgeGroup.fromAge(_parsedAge);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const FieldLabel('Triage category'),
          const SizedBox(height: 4),
          const Text(
            'The one decision this form exists for. Everything else can be '
            'left blank and filled in later.',
            style: TextStyle(
              color: AppColors.ink500,
              fontSize: 11,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          TriageSelector(
            selected: _triage,
            onChanged: (category) => setState(() => _triage = category),
          ),

          const SizedBox(height: 20),
          const FieldLabel('Identity'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _name,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Leave blank if unidentified',
              prefixIcon: Icon(Icons.badge_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _age,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Age',
                    hintText: 'Optional',
                    helperText: ageGroup.label,
                    prefixIcon: const Icon(Icons.cake_outlined, size: 18),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    final age = int.tryParse(text);
                    if (age == null || age > 130) return 'Enter a real age';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<Gender>(
                  initialValue: _gender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: [
                    for (final gender in Gender.values)
                      DropdownMenuItem(
                        value: gender,
                        child: Text(gender.label),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(
                            () => _gender = value ?? Gender.unknown,
                          ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const FieldLabel('Assessment'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _injury,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Injury type',
              hintText: 'Crush injury to left leg',
              prefixIcon: Icon(Icons.healing_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _condition,
            enabled: !_busy,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Medical condition',
              hintText: 'Conscious, breathing, heavy bleeding controlled',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _assistance,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Assistance required',
              hintText: 'Stretcher and two carriers',
              prefixIcon: Icon(Icons.support_outlined, size: 18),
            ),
          ),

          if (widget.showStatus) ...[
            const SizedBox(height: 20),
            const FieldLabel('Status'),
            const SizedBox(height: 10),
            DropdownButtonFormField<VictimStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Current status'),
              items: [
                for (final status in VictimStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(
                        () => _status = value ?? VictimStatus.registered,
                      ),
            ),
          ],

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
            'record is authoritative the moment it is stored.',
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