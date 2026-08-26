import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/database/daos/settings_dao.dart';
import '../../core/database/daos/miscellaneous_dao.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';

class MiscellaneousScreen extends StatefulWidget {
  final int? initialSchemeId;
  final String? initialSchemeName;
  final int? initialSetId;
  final String? initialSetLabel;

  const MiscellaneousScreen({
    super.key,
    this.initialSchemeId,
    this.initialSchemeName,
    this.initialSetId,
    this.initialSetLabel,
  });

  @override
  State<MiscellaneousScreen> createState() => _MiscellaneousScreenState();
}

class _MiscellaneousScreenState extends State<MiscellaneousScreen> {
  final _settingsDao = SettingsDao();
  final _miscDao = MiscellaneousDao();
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();

  List<String> _miscTypes = [];
  List<_MiscRecord> _records = [];
  List<Scheme> _schemes = [];
  Map<int, List<SetModel>> _setsBySchemeId = {};
  int? _schemeFilter;
  int? _setFilter;
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _schemeFilter = widget.initialSchemeId;
    _setFilter = widget.initialSetId;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final miscItemsRaw = await _settingsDao.getSetting('misc_items_json');
    final schemes = await _schemesDao.getAllSchemes();
    final setsBySchemeId = <int, List<SetModel>>{};
    for (final scheme in schemes) {
      if (scheme.schemeId != null) {
        setsBySchemeId[scheme.schemeId!] = await _setsDao.getSetsForScheme(
          scheme.schemeId!,
        );
      }
    }

    var miscTypes = <String>['Leakage', 'Starter', 'Pipes', 'Electrical'];
    if (miscItemsRaw != null && miscItemsRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(miscItemsRaw);
        if (decoded is List) {
          final loaded = decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList();
          if (loaded.isNotEmpty) {
            miscTypes = loaded;
          }
        }
      } catch (_) {}
    }

    final dbRecordsRaw = await _miscDao.getAllRecords();
    final records = dbRecordsRaw
        .map((e) => _MiscRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    for (final record in records) {
      if (!miscTypes.any(
        (t) => t.toLowerCase() == record.category.toLowerCase(),
      )) {
        miscTypes.add(record.category);
      }
    }

    if (!mounted) return;
    setState(() {
      _miscTypes = miscTypes;
      _records = records;
      _schemes = schemes;
      _setsBySchemeId = setsBySchemeId;
      _isLoading = false;
    });
  }

  Future<void> _persistRecords() async {
    await _miscDao.replaceAllRecords(_records.map((r) => r.toJson()).toList());

    final groupedTitles = <String, List<String>>{};
    for (final record in _records) {
      final list = groupedTitles.putIfAbsent(record.category, () => []);
      if (!list.any((v) => v.toLowerCase() == record.title.toLowerCase())) {
        list.add(record.title);
      }
    }
    try {
      await _settingsDao.setSetting(
        'misc_custom_values_json',
        jsonEncode(groupedTitles),
      );
    } catch (_) {
      // The SQLite record is the source of truth. A custom-value cache failure
      // must not make a successfully saved miscellaneous item appear to fail.
    }
  }

  Future<bool> _persistWithRollback(List<_MiscRecord> previousRecords) async {
    try {
      await _persistRecords();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _records = previousRecords);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save miscellaneous item: $e')),
      );
      return false;
    }
  }

  Future<void> _addRecord() async {
    await _showRecordDialog();
  }

  Future<void> _showRecordDialog({_MiscRecord? existing}) async {
    final titleCtrl = TextEditingController();
    titleCtrl.text = existing?.title ?? '';
    var selectedCategory =
        existing?.category ??
        (_miscTypes.isNotEmpty ? _miscTypes.first : 'Miscellaneous');
    int? selectedSchemeId = existing?.schemeId ?? widget.initialSchemeId;
    int? selectedSetId = existing?.setId ?? widget.initialSetId;
    String? validationError;

    final created = await showDialog<_MiscRecord>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Add Miscellaneous Item'
                : 'Edit Miscellaneous Item',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Tubewell Main Leakage',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedSchemeId,
                decoration: const InputDecoration(
                  labelText: 'Related Scheme (Optional)',
                ),
                items: _schemes
                    .map(
                      (scheme) => DropdownMenuItem<int>(
                        value: scheme.schemeId,
                        child: Text(scheme.schemeName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setLocalState(() {
                  selectedSchemeId = value;
                  selectedSetId = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(selectedSchemeId),
                initialValue: selectedSetId,
                decoration: const InputDecoration(
                  labelText: 'Related Set (Optional)',
                ),
                items: (_setsBySchemeId[selectedSchemeId] ?? const <SetModel>[])
                    .map(
                      (set) => DropdownMenuItem<int>(
                        value: set.setId,
                        child: Text(set.setLabel),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setLocalState(() => selectedSetId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _miscTypes
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setLocalState(() => selectedCategory = value);
                  }
                },
              ),
              if (validationError != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  setLocalState(
                    () => validationError = 'Please enter an item title.',
                  );
                  return;
                }
                final selectedScheme = _schemes
                    .where((scheme) => scheme.schemeId == selectedSchemeId)
                    .firstOrNull;
                final selectedSet =
                    (_setsBySchemeId[selectedSchemeId] ?? const <SetModel>[])
                        .where((set) => set.setId == selectedSetId)
                        .firstOrNull;
                Navigator.pop(
                  ctx,
                  _MiscRecord(
                    id:
                        existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    title: title,
                    category: selectedCategory,
                    schemeId: selectedSchemeId,
                    schemeName: selectedScheme?.schemeName,
                    setId: selectedSetId,
                    setLabel: selectedSet?.setLabel,
                    entries: existing?.entries ?? [],
                  ),
                );
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (created == null) return;

    final previousRecords = List<_MiscRecord>.from(_records);
    final index = _records.indexWhere((r) => r.id == created.id);
    setState(() {
      if (index == -1) {
        _records.add(created);
      } else {
        _records[index] = created;
      }
    });
    final saved = await _persistWithRollback(previousRecords);
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Miscellaneous item saved.')),
      );
    }
  }

  Future<void> _deleteRecord(_MiscRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Delete "${record.title}" and all expenditures?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _records.removeWhere((r) => r.id == record.id);
    });
    await _persistRecords();
  }

  Future<void> _openRecord(_MiscRecord record) async {
    final updated = await Navigator.push<_MiscRecord>(
      context,
      MaterialPageRoute(
        builder: (_) => _MiscRecordDetailScreen(
          record: record,
          categoryOptions: _miscTypes,
        ),
      ),
    );

    if (updated == null) return;

    final index = _records.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;

    setState(() {
      _records[index] = updated;
    });
    await _persistRecords();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialSetLabel != null
              ? 'Miscellaneous — ${widget.initialSetLabel}'
              : widget.initialSchemeName == null
              ? 'Miscellaneous'
              : 'Miscellaneous — ${widget.initialSchemeName}',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecord,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'No miscellaneous items yet.\nTap + to add title, category, and expenditures.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredRecords.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search miscellaneous records...',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) =>
                              setState(() => _searchQuery = value.trim()),
                        ),
                        const SizedBox(height: 10),
                        if (widget.initialSchemeId == null)
                          DropdownButtonFormField<int?>(
                            initialValue: _schemeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Scheme',
                              prefixIcon: Icon(Icons.filter_alt_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Schemes'),
                              ),
                              ..._schemes.map(
                                (scheme) => DropdownMenuItem<int?>(
                                  value: scheme.schemeId,
                                  child: Text(scheme.schemeName),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(() {
                              _schemeFilter = value;
                              _setFilter = null;
                            }),
                          ),
                        if (widget.initialSetId == null) ...[
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int?>(
                            key: ValueKey(_schemeFilter),
                            initialValue: _setFilter,
                            decoration: const InputDecoration(
                              labelText: 'Filter by Set',
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Sets'),
                              ),
                              ..._setsForFilter.map(
                                (set) => DropdownMenuItem<int?>(
                                  value: set.setId,
                                  child: Text(set.setLabel),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _setFilter = value),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                    );
                  }
                  final record = _filteredRecords[index - 1];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () => _openRecord(record),
                      leading: const CircleAvatar(
                        child: Icon(Icons.category_outlined),
                      ),
                      title: Text(record.title),
                      subtitle: Text(
                        '${record.schemeName ?? 'Unassigned Scheme'} • '
                        '${record.setLabel ?? 'Unassigned Set'} • ${record.category} • '
                        '${record.entries.length} entries • Rs. ${record.totalAmount.toStringAsFixed(0)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showRecordDialog(existing: record);
                          }
                          if (value == 'delete') {
                            _deleteRecord(record);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  List<_MiscRecord> get _filteredRecords {
    final query = _searchQuery.toLowerCase();
    return _records.where((record) {
      final matchesScheme =
          _schemeFilter == null || record.schemeId == _schemeFilter;
      final matchesSet = _setFilter == null || record.setId == _setFilter;
      final matchesSearch =
          query.isEmpty ||
          record.title.toLowerCase().contains(query) ||
          record.category.toLowerCase().contains(query) ||
          (record.schemeName?.toLowerCase().contains(query) ?? false);
      return matchesScheme && matchesSet && matchesSearch;
    }).toList();
  }

  List<SetModel> get _setsForFilter {
    if (_schemeFilter != null) {
      return _setsBySchemeId[_schemeFilter] ?? const <SetModel>[];
    }
    return _setsBySchemeId.values.expand((sets) => sets).toList();
  }
}

class _MiscRecordDetailScreen extends StatefulWidget {
  final _MiscRecord record;
  final List<String> categoryOptions;

  const _MiscRecordDetailScreen({
    required this.record,
    required this.categoryOptions,
  });

  @override
  State<_MiscRecordDetailScreen> createState() =>
      _MiscRecordDetailScreenState();
}

class _MiscRecordDetailScreenState extends State<_MiscRecordDetailScreen> {
  late _MiscRecord _record;

  @override
  void initState() {
    super.initState();
    _record = widget.record.copyWith(
      entries: widget.record.entries.map((e) => e.copyWith()).toList(),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  DateTime _parseDate(String value) {
    final parts = value.split('-');
    if (parts.length != 3) return DateTime.now();
    final day = int.tryParse(parts[0]) ?? 1;
    final month = int.tryParse(parts[1]) ?? 1;
    final year = int.tryParse(parts[2]) ?? DateTime.now().year;
    return DateTime(year, month, day);
  }

  Future<void> _showEntryDialog({_MiscEntry? existing}) async {
    final amountCtrl = TextEditingController();
    final voucherCtrl = TextEditingController();
    final regPageCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    var category = existing?.category ?? _record.category;
    var selectedDate = existing != null
        ? _parseDate(existing.entryDate)
        : DateTime.now();

    amountCtrl.text = existing != null
        ? existing.amount.toStringAsFixed(0)
        : '';
    voucherCtrl.text = existing?.voucherNo ?? '';
    regPageCtrl.text = existing?.regPageNo ?? '';
    noteCtrl.text = existing?.notes ?? '';
    dateCtrl.text = existing?.entryDate ?? _formatDate(selectedDate);

    final entry = await showDialog<_MiscEntry>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null ? 'Add Expenditure' : 'Edit Expenditure',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  readOnly: true,
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Date (DD-MM-YYYY)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        setLocalState(() {
                          selectedDate = picked;
                          dateCtrl.text = _formatDate(picked);
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: widget.categoryOptions
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setLocalState(() => category = v);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: voucherCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Voucher No. (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: regPageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reg. Page No. (optional)',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim());
                if (amount == null || amount <= 0) return;
                Navigator.pop(
                  ctx,
                  _MiscEntry(
                    id:
                        existing?.id ??
                        DateTime.now().microsecondsSinceEpoch.toString(),
                    category: category,
                    entryDate: dateCtrl.text.trim().isEmpty
                        ? _formatDate(selectedDate)
                        : dateCtrl.text.trim(),
                    voucherNo: voucherCtrl.text.trim().isEmpty
                        ? null
                        : voucherCtrl.text.trim(),
                    amount: amount,
                    regPageNo: regPageCtrl.text.trim().isEmpty
                        ? null
                        : regPageCtrl.text.trim(),
                    notes: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                  ),
                );
              },
              child: Text(existing == null ? 'Add' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (entry == null) return;
    setState(() {
      final idx = _record.entries.indexWhere((e) => e.id == entry.id);
      final updatedEntries = List<_MiscEntry>.from(_record.entries);
      if (idx == -1) {
        updatedEntries.add(entry);
      } else {
        updatedEntries[idx] = entry;
      }
      _record = _record.copyWith(entries: updatedEntries);
    });
  }

  void _deleteEntry(String entryId) {
    setState(() {
      _record = _record.copyWith(
        entries: _record.entries.where((e) => e.id != entryId).toList(),
      );
    });
  }

  void _saveAndClose() {
    Navigator.pop(context, _record);
  }

  Future<bool> _onWillPop() async {
    _saveAndClose();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _saveAndClose,
          ),
          title: Text(_record.title),
          actions: [
            IconButton(
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check),
              tooltip: 'Save',
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${_record.category}'),
                    const SizedBox(height: 4),
                    Text('Scheme: ${_record.schemeName ?? 'Unassigned'}'),
                    const SizedBox(height: 4),
                    Text('Set: ${_record.setLabel ?? 'Unassigned'}'),
                    const SizedBox(height: 4),
                    Text(
                      'Total: Rs. ${_record.totalAmount.toStringAsFixed(0)}',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_record.entries.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 18),
                child: Center(
                  child: Text('No expenditures yet. Tap + to add.'),
                ),
              )
            else
              Card(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(
                        label: Expanded(child: Center(child: Text('Sr.No'))),
                      ),
                      DataColumn(
                        label: Expanded(child: Center(child: Text('Date'))),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(child: Text('Voucher No.')),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(child: Text('Amount (PKR)')),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(
                          child: Center(child: Text('Reg. Page No.')),
                        ),
                      ),
                      DataColumn(
                        label: Expanded(child: Center(child: Text('Actions'))),
                      ),
                    ],
                    rows: _record.entries.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final row = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(Center(child: Text('${idx + 1}'))),
                          DataCell(Center(child: Text(row.entryDate))),
                          DataCell(Center(child: Text(row.voucherNo ?? '-'))),
                          DataCell(
                            Center(
                              child: Text(
                                'PKR ${row.amount.toStringAsFixed(0)}',
                              ),
                            ),
                          ),
                          DataCell(Center(child: Text(row.regPageNo ?? '-'))),
                          DataCell(
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () =>
                                      _showEntryDialog(existing: row),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                  ),
                                  onPressed: () => _deleteEntry(row.id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.center,
              child: OutlinedButton.icon(
                onPressed: () => _showEntryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Entry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiscRecord {
  final String id;
  final String title;
  final String category;
  final int? schemeId;
  final String? schemeName;
  final int? setId;
  final String? setLabel;
  final List<_MiscEntry> entries;

  _MiscRecord({
    required this.id,
    required this.title,
    required this.category,
    required this.schemeId,
    this.schemeName,
    required this.setId,
    this.setLabel,
    required this.entries,
  });

  double get totalAmount => entries.fold<double>(0, (sum, e) => sum + e.amount);

  _MiscRecord copyWith({
    String? id,
    String? title,
    String? category,
    int? schemeId,
    String? schemeName,
    int? setId,
    String? setLabel,
    List<_MiscEntry>? entries,
  }) {
    return _MiscRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      schemeId: schemeId ?? this.schemeId,
      schemeName: schemeName ?? this.schemeName,
      setId: setId ?? this.setId,
      setLabel: setLabel ?? this.setLabel,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category,
    'schemeId': schemeId,
    'schemeName': schemeName,
    'setId': setId,
    'setLabel': setLabel,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory _MiscRecord.fromJson(Map<String, dynamic> json) {
    return _MiscRecord(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'Miscellaneous').toString(),
      schemeId: json['schemeId'] as int?,
      schemeName: json['schemeName']?.toString(),
      setId: json['setId'] as int?,
      setLabel: json['setLabel']?.toString(),
      entries: (json['entries'] is List)
          ? (json['entries'] as List)
                .whereType<Map>()
                .map((e) => _MiscEntry.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : <_MiscEntry>[],
    );
  }
}

class _MiscEntry {
  final String id;
  final String category;
  final String entryDate;
  final String? voucherNo;
  final double amount;
  final String? regPageNo;
  final String? notes;

  _MiscEntry({
    required this.id,
    required this.category,
    required this.entryDate,
    this.voucherNo,
    required this.amount,
    this.regPageNo,
    this.notes,
  });

  _MiscEntry copyWith({
    String? id,
    String? category,
    String? entryDate,
    String? voucherNo,
    double? amount,
    String? regPageNo,
    String? notes,
  }) {
    return _MiscEntry(
      id: id ?? this.id,
      category: category ?? this.category,
      entryDate: entryDate ?? this.entryDate,
      voucherNo: voucherNo ?? this.voucherNo,
      amount: amount ?? this.amount,
      regPageNo: regPageNo ?? this.regPageNo,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'entryDate': entryDate,
    'voucherNo': voucherNo,
    'amount': amount,
    'regPageNo': regPageNo,
    'notes': notes,
  };

  factory _MiscEntry.fromJson(Map<String, dynamic> json) {
    return _MiscEntry(
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
