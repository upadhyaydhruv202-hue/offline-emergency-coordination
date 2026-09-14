import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../domain/entities/task_draft.dart';
import '../../../domain/entities/task_priority.dart';
import '../../../shared/widgets/form_failure.dart';
import '../../../shared/widgets/ops_visuals.dart';
import '../../../shared/widgets/status_chip.dart';
import '../application/task_providers.dart';

/// Raises a task on this device.
///
/// Tasks will normally be issued by the command centre once synchronisation
/// exists. Until then this is how a responder records work they were given over
/// the radio, so it can be tracked and reported like anything else.
class TaskCreateScreen extends ConsumerStatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  ConsumerState<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends ConsumerState<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();

  TaskPriority _priority = TaskPriority.high;
  bool _busy = false;
  String? _failure;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _failure = null;
    });

    try {
      final task = await ref.read(taskServiceProvider).create(
            TaskDraft(
              title: _title.text,
              priority: _priority,
              description: _description.text,
              location: _location.text,
            ),
          );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy800,
          content: Text('${task.taskCode} stored on this device'),
        ),
      );
      context.pushReplacement(AppRoute.taskDetailPath(task.id));
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = 'The task could not be written to this device: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const FieldLabel('Task'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _title,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                inputFormatters: [LengthLimitingTextInputFormatter(120)],
                decoration: const InputDecoration(
                  labelText: 'What needs doing?',
                  hintText: 'Search collapsed building, north face',
                  prefixIcon: Icon(Icons.assignment_outlined, size: 18),
                ),
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Describe the task in a few words'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Block C stairwell',
                  prefixIcon: Icon(Icons.place_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Detail',
                  hintText: 'Two casualties reported by a neighbour, bring '
                      'cutting gear',
                  alignLabelWithHint: true,
                ),
              ),

              const SizedBox(height: 20),
              const FieldLabel('Priority'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final priority in TaskPriority.byUrgency)
                    ChoiceChip(
                      label: Text(priority.label),
                      selected: _priority == priority,
                      showCheckmark: false,
                      selectedColor:
                          taskPriorityColor(priority).withValues(alpha: 0.16),
                      side: BorderSide(
                        color: _priority == priority
                            ? taskPriorityColor(priority)
                            : AppColors.navy600,
                      ),
                      labelStyle: TextStyle(
                        color: _priority == priority
                            ? taskPriorityColor(priority)
                            : AppColors.ink400,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: _busy
                          ? null
                          : (_) => setState(() => _priority = priority),
                    ),
                ],
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
                    : const Text('Save to this device'),
              ),
              const SizedBox(height: 12),
              const Text(
                'The task is assigned to you and scoped to the current '
                'incident. Saving writes to this device only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink500,
                  fontSize: 11,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
