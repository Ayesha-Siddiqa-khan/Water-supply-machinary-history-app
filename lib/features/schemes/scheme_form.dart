import 'package:flutter/material.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';
import '../../shared/theme/app_colors.dart';

class SchemeForm extends StatefulWidget {
  final Scheme? scheme;
  final String schemeCategory;
  final int? parentSchemeId;
  final int? parentSetId;

  const SchemeForm({
    super.key,
    this.scheme,
    this.schemeCategory = 'scheme',
    this.parentSchemeId,
    this.parentSetId,
  });

  @override
  State<SchemeForm> createState() => _SchemeFormState();
}

class _SchemeFormState extends State<SchemeForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _sortOrderController = TextEditingController();
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();
  List<Scheme> _parentSchemes = [];
  List<SetModel> _parentSets = [];
  int? _selectedParentSchemeId;
  int? _selectedParentSetId;
  bool _isLoadingSchemes = false;
  bool _isSaving = false;

  bool get isEditing => widget.scheme != null;
  bool get _isUselessItem =>
      (widget.scheme?.category ?? widget.schemeCategory).toLowerCase() ==
      'useless_item';

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _nameController.text = widget.scheme!.schemeName;
      _descController.text = widget.scheme!.description ?? '';
      _sortOrderController.text = widget.scheme!.sortOrder > 0
          ? widget.scheme!.sortOrder.toString()
          : '';
    }
    _selectedParentSchemeId =
        widget.scheme?.parentSchemeId ?? widget.parentSchemeId;
    _selectedParentSetId = widget.scheme?.parentSetId ?? widget.parentSetId;
    if (_isUselessItem) _loadParentSchemes();
  }

  Future<void> _loadParentSchemes() async {
    setState(() => _isLoadingSchemes = true);
    final schemes = await _schemesDao.getAllSchemes();
    if (!mounted) return;
    setState(() {
      _parentSchemes = schemes;
    });
    if (_selectedParentSchemeId != null) {
      await _loadParentSets(_selectedParentSchemeId!);
    }
    if (mounted) setState(() => _isLoadingSchemes = false);
  }

  Future<void> _loadParentSets(int schemeId) async {
    final sets = await _setsDao.getSetsForScheme(schemeId);
    if (!mounted) return;
    setState(() => _parentSets = sets);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (isEditing) {
        await _schemesDao.updateScheme(
          widget.scheme!.copyWith(
            schemeName: _nameController.text.trim(),
            parentSchemeId: _selectedParentSchemeId,
            parentSetId: _selectedParentSetId,
            description: _descController.text.trim(),
            sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
          ),
        );
      } else {
        final now = DateTime.now();
        final nowStr =
            '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        await _schemesDao.insertScheme(
          Scheme(
            schemeName: _nameController.text.trim(),
            category: widget.schemeCategory,
            parentSchemeId: _selectedParentSchemeId,
            parentSetId: _selectedParentSetId,
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null,
            sortOrder: int.tryParse(_sortOrderController.text.trim()) ?? 0,
            createdAt: nowStr,
            updatedAt: nowStr,
          ),
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
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
        child: SingleChildScrollView(
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
                _isUselessItem
                    ? (isEditing ? 'Edit Useless Item' : 'Add Useless Item')
                    : (isEditing ? 'Edit Scheme' : 'Add Scheme'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _isUselessItem
                      ? 'Useless Item Record Name'
                      : 'Scheme Name',
                  hintText: _isUselessItem
                      ? 'e.g., Old Pump and Motor'
                      : 'e.g., City Water Works Tanky No. 2',
                  prefixIcon: Icon(Icons.water_drop_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Name is required';
                  return null;
                },
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sortOrderController,
                decoration: InputDecoration(
                  labelText: 'Display Number (Optional)',
                  hintText: _isUselessItem
                      ? 'e.g., 1'
                      : 'e.g., 1, 2, 3 — controls listing order',
                  prefixIcon: Icon(Icons.sort),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              if (_isUselessItem) ...[
                if (_isLoadingSchemes)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int>(
                    initialValue: _selectedParentSchemeId,
                    decoration: const InputDecoration(
                      labelText: 'Related Scheme *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                    items: _parentSchemes
                        .map(
                          (scheme) => DropdownMenuItem<int>(
                            value: scheme.schemeId,
                            child: Text(scheme.schemeName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) async {
                      setState(() {
                        _selectedParentSchemeId = value;
                        _selectedParentSetId = null;
                        _parentSets = [];
                      });
                      if (value != null) await _loadParentSets(value);
                    },
                    validator: (value) => value == null
                        ? 'Please select the related scheme'
                        : null,
                  ),
                const SizedBox(height: 12),
                if (!_isLoadingSchemes)
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selectedParentSchemeId),
                    initialValue: _selectedParentSetId,
                    decoration: const InputDecoration(
                      labelText: 'Related Set *',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: _parentSets
                        .map(
                          (set) => DropdownMenuItem<int>(
                            value: set.setId,
                            child: Text(set.setLabel),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedParentSetId = value),
                    validator: (value) =>
                        value == null ? 'Please select the related set' : null,
                  ),
                const SizedBox(height: 12),
              ],
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
                      onPressed: (_isSaving || _isLoadingSchemes)
                          ? null
                          : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(isEditing ? 'Update' : 'Add'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }
}
