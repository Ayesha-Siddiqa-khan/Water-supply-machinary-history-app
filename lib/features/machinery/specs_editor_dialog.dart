import 'package:flutter/material.dart';

/// Session clipboard for one-click spec copy/paste. In-memory only —
/// cleared when the app restarts. Type-guarded: motor specs paste into
/// motors, not pumps.
class SpecClipboard {
  static String? _type;
  static Map<String, String> _values = {};

  static bool matchesType(String? machineryType) =>
      _values.isNotEmpty &&
      machineryType != null &&
      _type == machineryType.trim().toLowerCase();

  static void copy(String machineryType, Map<String, String> specs) {
    _type = machineryType.trim().toLowerCase();
    _values = Map<String, String>.from(specs)
      ..removeWhere((_, v) => v.trim().isEmpty);
  }

  static Map<String, String> paste() => Map<String, String>.from(_values);

  static void clear() {
    _type = null;
    _values = {};
  }
}

/// Generic label/value editor for spec sheets. Fields containing "(Yes/No)"
/// render as a Yes/No dropdown, fields starting with "Other" render multiline.
/// Returns only the non-empty values, or null if cancelled.
class SpecsEditorDialog extends StatefulWidget {
  final String title;
  final List<String> fields;
  final Map<String, String> values;

  /// Equipment type of the spec sheet — enables the one-click
  /// "Paste Specifications" button when the clipboard holds the same type.
  /// Null (set information) disables pasting.
  final String? machineryType;

  /// Optional "copy specifications" sources: label -> values. When non-empty,
  /// a dropdown at the top prefills the fields with the chosen equipment's
  /// saved values; everything stays editable afterwards.
  final Map<String, Map<String, String>> copyTemplates;

  const SpecsEditorDialog({
    super.key,
    required this.title,
    required this.fields,
    this.values = const {},
    this.machineryType,
    this.copyTemplates = const {},
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String title,
    required List<String> fields,
    Map<String, String> values = const {},
    String? machineryType,
    Map<String, Map<String, String>> copyTemplates = const {},
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SpecsEditorDialog(
            title: title,
            fields: fields,
            values: values,
            machineryType: machineryType,
            copyTemplates: copyTemplates,
          ),
        ),
      ),
    );
  }

  @override
  State<SpecsEditorDialog> createState() => _SpecsEditorDialogState();
}

class _SpecsEditorDialogState extends State<SpecsEditorDialog> {
  late final Map<String, TextEditingController> _ctrls = {
    for (final f in widget.fields) f: TextEditingController(text: widget.values[f] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFields(Map<String, String> values) {
    setState(() {
      for (final e in _ctrls.entries) {
        final v = values[e.key];
        if (v != null) e.value.text = v;
      }
    });
  }

  void _applyTemplate(String label) {
    final values = widget.copyTemplates[label];
    if (values == null) return;
    _fillFields(values);
  }

  void _pasteFromClipboard() {
    _fillFields(SpecClipboard.paste());
  }

  void _save() {
    final result = <String, String>{};
    for (final e in _ctrls.entries) {
      if (e.value.text.trim().isNotEmpty) result[e.key] = e.value.text.trim();
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (SpecClipboard.matchesType(widget.machineryType))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton.icon(
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.paste, size: 18),
                  label: const Text('Paste Specifications'),
                ),
              ),
            if (widget.copyTemplates.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Copy Specifications From Existing',
                    hintText: 'Select equipment to prefill fields',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.copy_all_outlined),
                  ),
                  items: widget.copyTemplates.keys
                      .map((label) => DropdownMenuItem(value: label, child: Text(label)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _applyTemplate(v);
                  },
                ),
              ),
            ...widget.fields.map((f) {
              final isYesNo = f.contains('(Yes/No)');
              final isOther = f.startsWith('Other');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: isYesNo
                    ? DropdownButtonFormField<String>(
                        // Keyed by current value so the field re-reads
                        // initialValue when a copy-template prefills it.
                        key: ValueKey('yn-$f-${_ctrls[f]!.text}'),
                        initialValue: _ctrls[f]!.text.isEmpty ? null : _ctrls[f]!.text,
                        decoration: InputDecoration(
                          labelText: f,
                          border: const OutlineInputBorder(),
                        ),
                        items: const ['Yes', 'No']
                            .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) => setState(() => _ctrls[f]!.text = v ?? ''),
                      )
                    : TextField(
                        controller: _ctrls[f],
                        decoration: InputDecoration(
                          labelText: f,
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: isOther,
                        ),
                        minLines: isOther ? 2 : 1,
                        maxLines: isOther ? 4 : 1,
                      ),
              );
            }),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Save Details'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
