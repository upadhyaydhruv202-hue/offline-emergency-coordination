import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../domain/entities/disaster_type.dart';
import '../../../../domain/entities/incident_draft.dart';
import '../../../../domain/entities/incident_status.dart';
import '../../../../domain/entities/location_record.dart';
import '../../../../shared/widgets/form_failure.dart';
import '../../../../shared/widgets/status_chip.dart';

/// The declaration and edit form for an incident.
///
/// Only the title and the disaster type are required. A responder declaring a
/// response from the pavement outside a collapsed building should not be blocked
/// by a zone they have not been given yet.
class IncidentForm extends StatefulWidget {
  const IncidentForm({
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.showStatus = false,
    this.position,
    super.key,
  });

  final IncidentDraft initial;
  final String submitLabel;

  /// Returns an error message to display, or null when the save succeeded.
  final Future<String?> Function(IncidentDraft draft) onSubmit;

  /// Status is offered when editing an existing incident; a new one is always
  /// declared ACTIVE, so the declaration form does not ask.
  final bool showStatus;

  /// The last position this device recorded, offered as the incident's location.
  /// Null when nothing has been captured yet, in which case the incident is
  /// stored without coordinates rather than blocking the declaration.
  final LocationRecord? position;

  @override
  State<IncidentForm> createState() => _IncidentFormState();
}

class _IncidentFormState extends State<IncidentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _zone;
  late final TextEditingController _description;

  late DisasterType _type;
  late IncidentStatus _status;
  late bool _attachPosition;

  bool _busy = false;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial.title);
    _zone = TextEditingController(text: widget.initial.assignedZone ?? '');
    _description =
        TextEditingController(text: widget.initial.description ?? '');
    _type = widget.initial.disasterType;
    _status = widget.initial.status;
    // Attaching the responder's position is the useful default when the device
    // has one and the incident does not already carry different coordinates.
    _attachPosition =
        widget.position != null && widget.initial.latitude == null;
  }

  @override
  void dispose() {
    _title.dispose();
    _zone.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    final position = _attachPosition ? widget.position : null;

    final failure = await widget.onSubmit(
      IncidentDraft(
        title: _title.text,
        disasterType: _type,
        description: _description.text,
        assignedZone: _zone.text,
        status: _status,
        latitude: position?.latitude ?? widget.initial.latitude,
        longitude: position?.longitude ?? widget.initial.longitude,
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
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const FieldLabel('Incident'),
          const SizedBox(height: 10),
          TextFormField(
            controller: _title,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Ahmedabad Earthquake Response',
              prefixIcon: Icon(Icons.crisis_alert_outlined, size: 18),
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Give the response a name teams will recognise'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DisasterType>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Disaster type'),
            items: [
              for (final type in DisasterType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _zone,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Assigned zone',
              hintText: 'AHMEDABAD ZONE 04',
              prefixIcon: Icon(Icons.grid_view_outlined, size: 18),
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
              hintText: 'Multi-storey collapse, two buildings, gas smell '
                  'reported on the north side',
              alignLabelWithHint: true,
            ),
          ),

          if (widget.showStatus) ...[
            const SizedBox(height: 20),
            const FieldLabel('Status'),
            const SizedBox(height: 10),
            DropdownButtonFormField<IncidentStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Current status'),
              items: [
                for (final status in IncidentStatus.values)
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
          if (widget.position case final position?)
            SwitchListTile(
              value: _attachPosition,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _attachPosition = value),
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Use my current position',
                style: TextStyle(color: AppColors.ink200, fontSize: 14),
              ),
              subtitle: Text(
                '${position.fix.latitudeLabel}  ${position.fix.longitudeLabel} · '
                'accuracy ${position.fix.accuracyLabel} · '
                'taken ${position.fix.timeLabel}',
                style: const TextStyle(color: AppColors.ink500, fontSize: 11),
              ),
            )
          else
            const Text(
              'This device has not recorded a position yet, so the incident '
              'will be stored without coordinates. Capture one from the home '
              'screen and edit the incident to add it.',
              style: TextStyle(
                color: AppColors.ink500,
                fontSize: 11,
                height: 1.45,
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
            'incident is usable the moment it is stored.',
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
