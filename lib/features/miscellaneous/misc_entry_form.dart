import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/daos/miscellaneous_dao.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';
import '../../shared/theme/app_colors.dart';

// ─── Category-specific field definitions ──────────────────────────────

class CategoryFieldDef {
  final String key;
  final String label;
  final String type;
  final List<String> options;
  const CategoryFieldDef({
    required this.key,
    required this.label,
    this.type = 'dropdown',
    this.options = const [],
  });
}

const Map<String, List<CategoryFieldDef>> categoryFields = {
  'Sluice Valves': [
    CategoryFieldDef(key: 'valveSize', label: 'Valve Size', options: [
      '2 Inch', '3 Inch', '4 Inch', '5 Inch', '6 Inch', '7 Inch', '8 Inch', 'Other',
    ]),
  ],
  'Electrical': [
    CategoryFieldDef(key: 'equipmentType', label: 'Equipment Type', options: [
      'Transformer', 'Motor', 'Cable', 'Panel', 'Other',
    ]),
  ],
  'Spare Motor': [
    CategoryFieldDef(key: 'motorHp', label: 'Motor HP', options: [
      '5 HP', '10 HP', '25 HP', '50 HP', 'Other',
    ]),
  ],
};

// ─── Model ────────────────────────────────────────────────────────────

class MiscRecord {
  final String id;
  final String title;
  final String category;
  final String? description;
  final int? schemeId;
  final String? schemeName;
  final int? setId;
  final String? setLabel;
  final String locationType;
  final String? locationName;
  final String? locationAddress;
  final String? locationDescription;
  final String date;
  final double amount;
  final String? workOrderNo;
  final String? voucherNo;
  final String? regPageNo;
  final String? notes;
  final Map<String, dynamic> categoryData;
  final List<MiscEntry> entries;

  MiscRecord({
    required this.id,
    required this.title,
    required this.category,
    this.description,
    this.schemeId,
    this.schemeName,
    this.setId,
    this.setLabel,
    this.locationType = 'external',
    this.locationName,
    this.locationAddress,
    this.locationDescription,
    required this.date,
    this.amount = 0,
    this.workOrderNo,
    this.voucherNo,
    this.regPageNo,
    this.notes,
    this.categoryData = const {},
    this.entries = const [],
  });

  double get totalAmount => entries.isNotEmpty
      ? entries.fold<double>(0, (sum, e) => sum + e.amount)
      : amount;

  MiscRecord copyWith({
    String? id,
    String? title,
    String? category,
    String? description,
    int? schemeId,
    String? schemeName,
    int? setId,
    String? setLabel,
    String? locationType,
    String? locationName,
    String? locationAddress,
    String? locationDescription,
    String? date,
    double? amount,
    String? workOrderNo,
    String? voucherNo,
    String? regPageNo,
    String? notes,
    Map<String, dynamic>? categoryData,
    List<MiscEntry>? entries,
  }) {
    return MiscRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      description: description ?? this.description,
      schemeId: schemeId ?? this.schemeId,
      schemeName: schemeName ?? this.schemeName,
      setId: setId ?? this.setId,
      setLabel: setLabel ?? this.setLabel,
      locationType: locationType ?? this.locationType,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      locationDescription: locationDescription ?? this.locationDescription,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      workOrderNo: workOrderNo ?? this.workOrderNo,
      voucherNo: voucherNo ?? this.voucherNo,
      regPageNo: regPageNo ?? this.regPageNo,
      notes: notes ?? this.notes,
      categoryData: categoryData ?? this.categoryData,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'description': description,
    'schemeId': schemeId,
    'schemeName': schemeName,
    'setId': setId,
    'setLabel': setLabel,
    'locationType': locationType,
    'locationName': locationName,
    'locationAddress': locationAddress,
    'locationDescription': locationDescription,
    'date': date,
    'amount': amount,
    'workOrderNo': workOrderNo,
    'voucherNo': voucherNo,
    'regPageNo': regPageNo,
    'notes': notes,
    'categoryData': jsonEncode(categoryData),
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory MiscRecord.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> catData = {};
    final rawCatData = json['categoryData'];
    if (rawCatData is Map) {
      catData = Map<String, dynamic>.from(rawCatData);
    } else if (rawCatData is String && rawCatData.isNotEmpty) {
      try {
        catData = Map<String, dynamic>.from(jsonDecode(rawCatData));
      } catch (_) {}
    }

    return MiscRecord(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'Miscellaneous').toString(),
      description: json['description']?.toString(),
      schemeId: json['schemeId'] is int ? json['schemeId'] as int : int.tryParse((json['schemeId'] ?? '').toString()),
      schemeName: json['schemeName']?.toString(),
      setId: json['setId'] is int ? json['setId'] as int : int.tryParse((json['setId'] ?? '').toString()),
      setLabel: json['setLabel']?.toString(),
      locationType: (json['locationType'] ?? 'external').toString(),
      locationName: json['locationName']?.toString(),
      locationAddress: json['locationAddress']?.toString(),
      locationDescription: json['locationDescription']?.toString(),
      date: (json['date'] ?? json['entryDate'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      workOrderNo: json['workOrderNo']?.toString(),
      voucherNo: json['voucherNo']?.toString(),
      regPageNo: json['regPageNo']?.toString(),
      notes: json['notes']?.toString(),
      categoryData: catData,
      entries: (json['entries'] is List)
          ? (json['entries'] as List).whereType<Map>().map((e) => MiscEntry.fromJson(Map<String, dynamic>.from(e))).toList()
          : <MiscEntry>[],
    );
  }
}

class MiscEntry {
  final String id;
  final String category;
  final String entryDate;
  final String? voucherNo;
  final double amount;
  final String? regPageNo;
  final String? notes;

  MiscEntry({
    required this.id,
    required this.category,
    required this.entryDate,
    this.voucherNo,
    required this.amount,
    this.regPageNo,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'entryDate': entryDate,
    'voucherNo': voucherNo,
    'amount': amount,
    'regPageNo': regPageNo,
    'notes': notes,
  };

  factory MiscEntry.fromJson(Map<String, dynamic> json) {
    return MiscEntry(
      id: (json['id'] ?? '').toString(),
      category: (json['category'] ?? 'Miscellaneous').toString(),
      entryDate: (json['entryDate'] ?? '').toString(),
      voucherNo: json['voucherNo']?.toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      regPageNo: json['regPageNo']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

// ─── Unified Entry Form ───────────────────────────────────────────────

class MiscEntryForm extends StatefulWidget {
  final String category;
  final List<Scheme> schemes;
  final Map<int, List<SetModel>> setsBySchemeId;
  final MiscRecord? existing;

  const MiscEntryForm({
    super.key,
    required this.category,
    required this.schemes,
    required this.setsBySchemeId,
    this.existing,
  });

  @override
  State<MiscEntryForm> createState() => _MiscEntryFormState();
}

class _MiscEntryFormState extends State<MiscEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _miscDao = MiscellaneousDao();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _workOrderCtrl = TextEditingController();
  final _voucherCtrl = TextEditingController();
  final _regPageCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _locationNameCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();
  final _locationDescCtrl = TextEditingController();

  String _locationType = 'external';
  int? _selectedSchemeId;
  int? _selectedSetId;
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic> _categoryData = {};
  List<CategoryFieldDef> _dbFields = [];

  bool get isEditing => widget.existing != null;

  List<CategoryFieldDef> get _fields => _dbFields.isNotEmpty
      ? _dbFields
      : (categoryFields[widget.category] ?? []);

  Future<void> _loadCategoryFields() async {
    final meta = await _miscDao.getCategoryMetaByName(widget.category);
    if (meta == null || meta['custom_fields'] == null) return;
    try {
      final decoded = jsonDecode(meta['custom_fields'].toString());
      if (decoded is List) {
        setState(() {
          _dbFields = decoded.whereType<Map>().map((m) => CategoryFieldDef(
            key: (m['key'] ?? '').toString(),
            label: (m['label'] ?? '').toString(),
            type: (m['type'] ?? 'dropdown').toString(),
            options: (m['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
          )).toList();
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _loadCategoryFields();
    if (isEditing) {
      final e = widget.existing!;
      _titleCtrl.text = e.title;
      _descCtrl.text = e.description ?? '';
      _amountCtrl.text = e.amount > 0 ? e.amount.toString() : '';
      _workOrderCtrl.text = e.workOrderNo ?? '';
      _voucherCtrl.text = e.voucherNo ?? '';
      _regPageCtrl.text = e.regPageNo ?? '';
      _notesCtrl.text = e.notes ?? '';
      _locationNameCtrl.text = e.locationName ?? '';
      _locationAddressCtrl.text = e.locationAddress ?? '';
      _locationDescCtrl.text = e.locationDescription ?? '';
      _locationType = e.locationType;
      _selectedSchemeId = e.schemeId;
      _selectedSetId = e.setId;
      _categoryData = Map<String, dynamic>.from(e.categoryData);
      if (e.date.isNotEmpty) {
        _selectedDate = _parseDate(e.date);
        _dateCtrl.text = e.date;
      } else {
        _dateCtrl.text = _formatDate(_selectedDate);
      }
    } else {
      _dateCtrl.text = _formatDate(_selectedDate);
    }
  }

  DateTime _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return DateTime.now();
    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                    isEditing ? 'Edit ${widget.category} Entry' : 'Add ${widget.category} Entry',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),

                  // ── Section 1: Basic Information ──
                  _sectionHeader('Basic Information'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date *',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.edit_calendar),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedDate = picked;
                              _dateCtrl.text = _formatDate(picked);
                            });
                          }
                        },
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Item / Issue Title *',
                      hintText: 'e.g., Main Leakage at Chak 3 FW',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // ── Section 2: Financial / Register Information ──
                  _sectionHeader('Financial / Register Information'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount (PKR)',
                      prefixIcon: Icon(Icons.payments_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (double.tryParse(v.trim()) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _workOrderCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Work Order No.',
                            prefixIcon: Icon(Icons.description_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _voucherCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Voucher No.',
                            prefixIcon: Icon(Icons.receipt_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _regPageCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Register Page No.',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: const SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes / Remarks',
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // ── Section 3: Location Reference ──
                  _sectionHeader('Location Reference'),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'external', label: Text('Outside Scheme'), icon: Icon(Icons.location_on_outlined)),
                      ButtonSegment(value: 'scheme', label: Text('Related to Scheme'), icon: Icon(Icons.account_tree_outlined)),
                    ],
                    selected: {_locationType},
                    onSelectionChanged: (v) => setState(() => _locationType = v.first),
                  ),
                  const SizedBox(height: 12),
                  if (_locationType == 'scheme') ...[
                    DropdownButtonFormField<int>(
                      initialValue: _selectedSchemeId,
                      decoration: const InputDecoration(
                        labelText: 'Select Scheme *',
                        prefixIcon: Icon(Icons.account_tree_outlined),
                      ),
                      items: widget.schemes.map((s) => DropdownMenuItem(
                        value: s.schemeId,
                        child: Text(s.schemeName),
                      )).toList(),
                      onChanged: (v) => setState(() {
                        _selectedSchemeId = v;
                        _selectedSetId = null;
                      }),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey(_selectedSchemeId),
                      initialValue: _selectedSetId,
                      decoration: const InputDecoration(
                        labelText: 'Select Set *',
                        prefixIcon: Icon(Icons.folder_outlined),
                      ),
                      items: (widget.setsBySchemeId[_selectedSchemeId] ?? const <SetModel>[]).map((s) => DropdownMenuItem(
                        value: s.setId,
                        child: Text(s.setLabel),
                      )).toList(),
                      onChanged: (v) => setState(() => _selectedSetId = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ] else ...[
                    TextFormField(
                      controller: _locationNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location Name',
                        hintText: 'e.g., Highway Road Leakage',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        hintText: 'e.g., Main Road Near Pump House',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationDescCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Location Details',
                        hintText: 'Landmarks, directions...',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // ── Section 4: Category-Specific Fields ──
                  if (_fields.isNotEmpty) ...[
                    _sectionHeader('Category-Specific Information'),
                    const SizedBox(height: 8),
                    ..._fields.map((field) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCategoryField(field),
                    )),
                  ],

                  // ── Buttons ──
                  const SizedBox(height: 8),
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
                          onPressed: _save,
                          child: Text(isEditing ? 'Save Changes' : 'Save Entry'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        )),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildCategoryField(CategoryFieldDef field) {
    if (field.type == 'dropdown') {
      final currentVal = _categoryData[field.key]?.toString();
      return DropdownButtonFormField<String>(
        initialValue: currentVal,
        decoration: InputDecoration(
          labelText: '${field.label} *',
          prefixIcon: const Icon(Icons.tune),
        ),
        items: field.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: (v) => setState(() => _categoryData[field.key] = v),
        validator: (v) => v == null ? 'Required' : null,
      );
    }
    return TextFormField(
      initialValue: _categoryData[field.key]?.toString(),
      decoration: InputDecoration(
        labelText: '${field.label} *',
        prefixIcon: const Icon(Icons.tune),
      ),
      onChanged: (v) => _categoryData[field.key] = v,
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    int? schemeId;
    String? schemeName;
    int? setId;
    String? setLabel;

    if (_locationType == 'scheme') {
      final scheme = widget.schemes.firstWhere((s) => s.schemeId == _selectedSchemeId);
      schemeId = scheme.schemeId;
      schemeName = scheme.schemeName;
      final sets = widget.setsBySchemeId[_selectedSchemeId] ?? [];
      final set = sets.firstWhere((s) => s.setId == _selectedSetId);
      setId = set.setId;
      setLabel = set.setLabel;
    }

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    Navigator.pop(
      context,
      MiscRecord(
        id: isEditing ? widget.existing!.id : DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        category: widget.category,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        schemeId: schemeId,
        schemeName: schemeName,
        setId: setId,
        setLabel: setLabel,
        locationType: _locationType,
        locationName: _locationType == 'external' ? _locationNameCtrl.text.trim() : null,
        locationAddress: _locationType == 'external' ? _locationAddressCtrl.text.trim() : null,
        locationDescription: _locationType == 'external' ? _locationDescCtrl.text.trim() : null,
        date: _dateCtrl.text.trim(),
        amount: amount,
        workOrderNo: _workOrderCtrl.text.trim().isEmpty ? null : _workOrderCtrl.text.trim(),
        voucherNo: _voucherCtrl.text.trim().isEmpty ? null : _voucherCtrl.text.trim(),
        regPageNo: _regPageCtrl.text.trim().isEmpty ? null : _regPageCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        categoryData: _categoryData,
      ),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _amountCtrl.dispose();
    _workOrderCtrl.dispose();
    _voucherCtrl.dispose();
    _regPageCtrl.dispose();
    _notesCtrl.dispose();
    _locationNameCtrl.dispose();
    _locationAddressCtrl.dispose();
    _locationDescCtrl.dispose();
    super.dispose();
  }
}
