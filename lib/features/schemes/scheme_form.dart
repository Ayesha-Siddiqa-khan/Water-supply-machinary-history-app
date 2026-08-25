import 'package:flutter/material.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/models/scheme.dart';
import '../../shared/theme/app_colors.dart';

class SchemeForm extends StatefulWidget {
  final Scheme? scheme;
  final String schemeCategory;

  const SchemeForm({super.key, this.scheme, this.schemeCategory = 'scheme'});

  @override
  State<SchemeForm> createState() => _SchemeFormState();
}

class _SchemeFormState extends State<SchemeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _schemesDao = SchemesDao();
  bool _isSaving = false;

  bool get isEditing => widget.scheme != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.scheme!.schemeName;
      _descController.text = widget.scheme!.description ?? '';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        await _schemesDao.updateScheme(widget.scheme!.copyWith(
          schemeName: _nameController.text.trim(),
          description: _descController.text.trim(),
        ));
      } else {
        final now = DateTime.now();
        final nowStr =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        await _schemesDao.insertScheme(Scheme(
          schemeName: _nameController.text.trim(),
          category: widget.schemeCategory,
          description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
          createdAt: nowStr,
          updatedAt: nowStr,
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
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isEditing ? 'Edit Scheme' : 'Add Scheme',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Scheme Name',
                hintText: 'e.g., City Water Works Tanky No. 2',
                prefixIcon: Icon(Icons.water_drop_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Name is required';
                return null;
              },
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                hintText: 'Additional notes...',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
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
                            width: 20,
                            height: 20,
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
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }
}
