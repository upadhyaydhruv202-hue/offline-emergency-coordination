import 'package:flutter/material.dart';

/// The search box used by every operational list.
///
/// Keeps its own controller so the caller can drive filtering from a Riverpod
/// notifier without rebuilding the field on each keystroke and losing the
/// cursor.
class OpsSearchField extends StatefulWidget {
  const OpsSearchField({
    required this.hintText,
    required this.initial,
    required this.onChanged,
    super.key,
  });

  final String hintText;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<OpsSearchField> createState() => _OpsSearchFieldState();
}

class _OpsSearchFieldState extends State<OpsSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}
