import 'package:flutter/material.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/models/set_model.dart';
import '../../shared/theme/app_colors.dart';

class SetForm extends StatefulWidget {
  final int schemeId;
  final int nextSetNumber;
  final SetModel? set;

  const SetForm({
    super.key,
    required this.schemeId,
    required this.nextSetNumber,
    this.set,
  });

  @override
  State<SetForm> createState() => _SetFormState();
}

class _SetFormState extends State<SetForm> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _labelController = TextEditingController();
  final _setsDao = SetsDao();
  bool _isSaving = false;

  bool get isEditing => widget.set != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _numberController.text = widget.set!.setNumber.toString();
      _labelController.text = widget.set!.setLabel;
    } else {
      _numberController.text = widget.nextSetNumber.toString();
      _labelController.text = 'Set No. ${widget.nextSetNumber}';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final setNumber = int.parse(_numberController.text.trim());
      final label = _labelController.text.trim();

      if (isEditing) {
        await _setsDao.updateSet(widget.set!.copyWith(
          setNumber: setNumber,
          setLabel: label,
        ));
      } else {
        await _setsDao.insertSet(SetModel(
          schemeId: widget.schemeId,
          setNumber: setNumber,
          setLabel: label,
        ));
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Set' : 'Add Set',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Set Number',
                prefixIcon: Icon(Icons.tag),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Required';
                if (int.tryParse(value) == null) return 'Enter a number';
                return null;
              },
              onChanged: (v) {
                if (int.tryParse(v) != null) {
                  _labelController.text = 'Set No. $v';
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Set Label',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Update' : 'Add'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _numberController.dispose();
    _labelController.dispose();
    super.dispose();
  }
}
