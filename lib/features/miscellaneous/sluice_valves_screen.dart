import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/database/daos/miscellaneous_dao.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';
import '../../core/services/export_service.dart';
import '../../shared/theme/app_colors.dart';

const _valveSizes = ['2 Inch', '3 Inch', '4 Inch', '5 Inch', '6 Inch', '7 Inch', '8 Inch'];
const _conditions = ['New', 'Working', 'Faulty', 'Replaced'];

class SluiceValvesScreen extends StatefulWidget {
  const SluiceValvesScreen({super.key});

  @override
  State<SluiceValvesScreen> createState() => _SluiceValvesScreenState();
}

class _SluiceValvesScreenState extends State<SluiceValvesScreen> {
  final _miscDao = MiscellaneousDao();
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();

  List<_SluiceValveRecord> _records = [];
  List<Scheme> _schemes = [];
  Map<int, List<SetModel>> _setsBySchemeId = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final schemes = await _schemesDao.getAllSchemes();
    final setsBySchemeId = <int, List<SetModel>>{};
    for (final scheme in schemes) {
      if (scheme.schemeId != null) {
        setsBySchemeId[scheme.schemeId!] = await _setsDao.getSetsForScheme(scheme.schemeId!);
      }
    }

    final dbRecords = await _miscDao.getAllRecords(category: 'Sluice Valves');
    final records = dbRecords.map((e) => _SluiceValveRecord.fromJson(Map<String, dynamic>.from(e))).toList();

    if (!mounted) return;
    setState(() {
      _records = records;
      _schemes = schemes;
      _setsBySchemeId = setsBySchemeId;
      _isLoading = false;
    });
  }

  Future<void> _persistRecords() async {
    await _miscDao.replaceAllRecords(
      _records.map((r) => r.toJson()).toList(),
    );
  }

  Future<void> _addRecord() async {
    final created = await showDialog<_SluiceValveRecord>(
      context: context,
      builder: (ctx) => _AddValveDialog(
        schemes: _schemes,
        setsBySchemeId: _setsBySchemeId,
      ),
    );
    if (created == null) return;
    setState(() => _records.add(created));
    await _persistRecords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sluice valve record saved.')),
      );
    }
  }

  Future<void> _editRecord(_SluiceValveRecord record) async {
    final updated = await showDialog<_SluiceValveRecord>(
      context: context,
      builder: (ctx) => _AddValveDialog(
        schemes: _schemes,
        setsBySchemeId: _setsBySchemeId,
        existing: record,
      ),
    );
    if (updated == null) return;
    final idx = _records.indexWhere((r) => r.id == record.id);
    if (idx == -1) return;
    setState(() => _records[idx] = updated);
    await _persistRecords();
  }

  Future<void> _deleteRecord(_SluiceValveRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('Delete this sluice valve record?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _records.removeWhere((r) => r.id == record.id));
    await _persistRecords();
  }

  Future<void> _exportPdf() async {
    try {
      final savedHeader = await ExportService.loadHeaderText();
      final headerText = await ExportService.showHeaderEditDialog(context, currentHeader: savedHeader);
      if (!mounted) return;

      final bytes = await _buildPdf(
        header: (headerText != null && headerText.isNotEmpty) ? headerText : (savedHeader ?? ''),
      );

      if (headerText != null && headerText.isNotEmpty) {
        await ExportService.saveHeaderText(headerText);
      }

      final pdfName = 'Sluice_Valves_Register.pdf';
      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(bytes: bytes, filename: pdfName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: pdfName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<Uint8List> _buildPdf({required String header}) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(header, style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 4),
            pw.Text('Sluice Valves Register', style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.SizedBox(height: 2),
            pw.Text(
              'Total Records: ${_records.length}',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
            pw.Divider(thickness: 1),
          ],
        ),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text('Page ${context.pageNumber}', style: pw.TextStyle(font: font, fontSize: 8)),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
            cellStyle: pw.TextStyle(font: font, fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
              8: pw.Alignment.centerLeft,
            },
            headers: [
              'Sr.No',
              'Valve Size',
              'Qty',
              'Scheme',
              'Set',
              'Location',
              'Condition',
              'Install Date',
              'Remarks',
            ],
            data: _records.asMap().entries.map((entry) {
              final r = entry.value;
               final location = r.locationType == 'scheme'
                   ? (r.schemeName ?? '')
                   : (r.locationName ?? '');
              final setLabel = r.locationType == 'scheme' ? (r.setLabel ?? '') : '';
              return [
                '${entry.key + 1}',
                r.valveSize,
                '${r.quantity}',
                r.schemeName ?? '',
                setLabel,
                location,
                r.condition,
                r.installationDate,
                r.remarks ?? '',
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(0.4),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(0.7),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(0.8),
              7: const pw.FlexColumnWidth(0.9),
              8: const pw.FlexColumnWidth(1.2),
            },
            border: pw.TableBorder.all(width: 0.5),
          ),
          // Manual writing rows
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
            cellStyle: pw.TextStyle(font: font, fontSize: 7),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 22,
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
              8: pw.Alignment.centerLeft,
            },
            headers: [
              'Sr.No',
              'Valve Size',
              'Qty',
              'Scheme',
              'Set',
              'Location',
              'Condition',
              'Install Date',
              'Remarks',
            ],
            data: List.generate(6, (i) => [
              '${_records.length + i + 1}',
              '', '', '', '', '', '', '', '',
            ]),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(0.4),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(0.7),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(0.8),
              7: const pw.FlexColumnWidth(0.9),
              8: const pw.FlexColumnWidth(1.2),
            },
            border: pw.TableBorder.all(width: 0.5),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sluice Valves Register'),
        actions: [
          IconButton(
            onPressed: _exportPdf,
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print / Export PDF',
          ),
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRecord,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.power_outlined, size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        Text(
                          'No sluice valve records yet.',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        const Text('Tap + to add a record.', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Expanded(child: Center(child: Text('Sr.No')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Valve Size')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Qty')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Scheme')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Set No.')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Location')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Condition')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Install Date')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Remarks')))),
                          DataColumn(label: Expanded(child: Center(child: Text('Actions')))),
                        ],
                        rows: _records.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final r = entry.value;
                          final location = r.locationType == 'scheme'
                              ? (r.schemeName ?? '')
                              : (r.locationName ?? '');
                          final setLabel = r.locationType == 'scheme' ? (r.setLabel ?? '') : '';
                          return DataRow(cells: [
                            DataCell(Center(child: Text('${idx + 1}'))),
                            DataCell(Center(child: Text(r.valveSize))),
                            DataCell(Center(child: Text('${r.quantity}'))),
                            DataCell(Text(r.schemeName ?? '')),
                            DataCell(Center(child: Text(setLabel))),
                            DataCell(Text(location)),
                            DataCell(Center(child: _conditionBadge(r.condition))),
                            DataCell(Center(child: Text(r.installationDate))),
                            DataCell(Text(r.remarks ?? '')),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () => _editRecord(r),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => _deleteRecord(r),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _conditionBadge(String condition) {
    Color color;
    switch (condition) {
      case 'New':
        color = const Color(0xFF43A047);
        break;
      case 'Working':
        color = const Color(0xFF1E88E5);
        break;
      case 'Faulty':
        color = const Color(0xFFE53935);
        break;
      case 'Replaced':
        color = const Color(0xFFFDD835);
        break;
      default:
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(condition, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Add/Edit Dialog ─────────────────────────────────────────────────

class _AddValveDialog extends StatefulWidget {
  final List<Scheme> schemes;
  final Map<int, List<SetModel>> setsBySchemeId;
  final _SluiceValveRecord? existing;

  const _AddValveDialog({
    required this.schemes,
    required this.setsBySchemeId,
    this.existing,
  });

  @override
  State<_AddValveDialog> createState() => _AddValveDialogState();
}

class _AddValveDialogState extends State<_AddValveDialog> {
  final _formKey = GlobalKey<FormState>();
  String _valveSize = '4 Inch';
  final _quantityCtrl = TextEditingController();
  String _condition = 'Working';
  String _locationType = 'scheme';
  int? _selectedSchemeId;
  int? _selectedSetId;
  final _locationNameCtrl = TextEditingController();
  final _locationAddressCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final e = widget.existing!;
      _valveSize = e.valveSize;
      _quantityCtrl.text = e.quantity.toString();
      _condition = e.condition;
      _locationType = e.locationType;
      _selectedSchemeId = e.schemeId;
      _selectedSetId = e.setId;
      _locationNameCtrl.text = e.locationName ?? '';
      _locationAddressCtrl.text = e.locationAddress ?? '';
      _remarksCtrl.text = e.remarks ?? '';
      if (e.installationDate.isNotEmpty) {
        _dateCtrl.text = e.installationDate;
        _selectedDate = _parseDate(e.installationDate);
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
        constraints: const BoxConstraints(maxWidth: 600),
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
                    isEditing ? 'Edit Sluice Valve' : 'Add Sluice Valve',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),

                  // Valve Size
                  DropdownButtonFormField<String>(
                    initialValue: _valveSize,
                    decoration: const InputDecoration(
                      labelText: 'Valve Size *',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    items: _valveSizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _valveSize = v); },
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Quantity
                  TextFormField(
                    controller: _quantityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (int.tryParse(v.trim()) == null) return 'Must be a number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // Condition
                  DropdownButtonFormField<String>(
                    initialValue: _condition,
                    decoration: const InputDecoration(
                      labelText: 'Condition *',
                      prefixIcon: Icon(Icons.health_and_safety_outlined),
                    ),
                    items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) { if (v != null) setState(() => _condition = v); },
                  ),
                  const SizedBox(height: 12),

                  // Installation Date
                  TextFormField(
                    readOnly: true,
                    controller: _dateCtrl,
                    decoration: InputDecoration(
                      labelText: 'Installation Date',
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
                  ),
                  const SizedBox(height: 16),

                  // Location Type
                  Text('Location Type', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'scheme', label: Text('Related to Scheme'), icon: Icon(Icons.account_tree_outlined)),
                      ButtonSegment(value: 'external', label: Text('Other Location'), icon: Icon(Icons.location_on_outlined)),
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
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationAddressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _remarksCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Notes',
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
                          onPressed: _save,
                          child: Text(isEditing ? 'Save' : 'Add'),
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    int? schemeId;
    String? schemeName;
    int? setId;
    String? setLabel;

    if (_locationType == 'scheme') {
      schemeId = _selectedSchemeId;
      schemeName = widget.schemes.firstWhere((s) => s.schemeId == _selectedSchemeId).schemeName;
      setId = _selectedSetId;
      setLabel = widget.setsBySchemeId[_selectedSchemeId]?.firstWhere((s) => s.setId == _selectedSetId).setLabel;
    }

    Navigator.pop(
      context,
      _SluiceValveRecord(
        id: isEditing ? widget.existing!.id : DateTime.now().microsecondsSinceEpoch.toString(),
        valveSize: _valveSize,
        quantity: int.tryParse(_quantityCtrl.text.trim()) ?? 1,
        condition: _condition,
        schemeId: schemeId,
        schemeName: schemeName,
        setId: setId,
        setLabel: setLabel,
        locationType: _locationType,
        locationName: _locationType == 'external' ? _locationNameCtrl.text.trim() : null,
        locationAddress: _locationType == 'external' ? _locationAddressCtrl.text.trim() : null,
        installationDate: _dateCtrl.text.trim(),
        remarks: _remarksCtrl.text.trim().isEmpty ? null : _remarksCtrl.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _locationNameCtrl.dispose();
    _locationAddressCtrl.dispose();
    _dateCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }
}

// ─── Model ───────────────────────────────────────────────────────────

class _SluiceValveRecord {
  final String id;
  final String valveSize;
  final int quantity;
  final String condition;
  final int? schemeId;
  final String? schemeName;
  final int? setId;
  final String? setLabel;
  final String locationType;
  final String? locationName;
  final String? locationAddress;
  final String installationDate;
  final String? remarks;

  _SluiceValveRecord({
    required this.id,
    required this.valveSize,
    required this.quantity,
    required this.condition,
    this.schemeId,
    this.schemeName,
    this.setId,
    this.setLabel,
    required this.locationType,
    this.locationName,
    this.locationAddress,
    required this.installationDate,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': 'Sluice Valve - $valveSize',
    'category': 'Sluice Valves',
    'schemeId': schemeId,
    'schemeName': schemeName,
    'setId': setId,
    'setLabel': setLabel,
    'locationType': locationType,
    'locationName': locationName,
    'locationAddress': locationAddress,
    'date': installationDate,
    'amount': 0,
    'entries': [
      {
        'id': id,
        'category': 'Sluice Valves',
        'entryDate': installationDate,
        'amount': 0,
        'notes': 'Size: $valveSize | Qty: $quantity | Condition: $condition${remarks != null ? ' | $remarks' : ''}',
      },
    ],
    // Custom fields stored in description for persistence
    'description': '$valveSize||$quantity||$condition||$installationDate||${remarks ?? ''}||$locationType||${locationName ?? ''}||${locationAddress ?? ''}',
  };

  factory _SluiceValveRecord.fromJson(Map<String, dynamic> json) {
    // Try to parse custom fields from description
    final desc = (json['description'] ?? '').toString();
    final parts = desc.split('||');

    String valveSize = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : '4 Inch';
    int quantity = parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1;
    String condition = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : 'Working';
    String installDate = (json['date'] ?? '').toString();
    String? remarks = parts.length > 4 && parts[4].isNotEmpty ? parts[4] : null;
    String locType = parts.length > 5 && parts[5].isNotEmpty ? parts[5] : (json['locationType'] ?? 'scheme').toString();
    String? locName = parts.length > 6 && parts[6].isNotEmpty ? parts[6] : json['locationName']?.toString();
    String? locAddr = parts.length > 7 && parts[7].isNotEmpty ? parts[7] : json['locationAddress']?.toString();

    // Fallback: try to extract size from title
    if (valveSize == '4 Inch' && (json['title'] ?? '').toString().contains(' - ')) {
      final titleParts = (json['title'] as String).split(' - ');
      if (titleParts.length > 1) {
        valveSize = titleParts.last;
      }
    }

    return _SluiceValveRecord(
      id: (json['id'] ?? '').toString(),
      valveSize: valveSize,
      quantity: quantity,
      condition: condition,
      schemeId: json['schemeId'] is int ? json['schemeId'] as int : int.tryParse((json['schemeId'] ?? '').toString()),
      schemeName: json['schemeName']?.toString(),
      setId: json['setId'] is int ? json['setId'] as int : int.tryParse((json['setId'] ?? '').toString()),
      setLabel: json['setLabel']?.toString(),
      locationType: locType,
      locationName: locName,
      locationAddress: locAddr,
      installationDate: installDate,
      remarks: remarks,
    );
  }
}
