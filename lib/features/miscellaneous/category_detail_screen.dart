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
import '../../shared/utils/currency_utils.dart';
import 'misc_entry_form.dart';

class CategoryDetailScreen extends StatefulWidget {
  final String categoryName;
  const CategoryDetailScreen({super.key, required this.categoryName});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  final _miscDao = MiscellaneousDao();
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();

  List<MiscRecord> _records = [];
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

    final dbRecords = await _miscDao.getAllRecords(category: widget.categoryName);
    final records = dbRecords.map((e) => MiscRecord.fromJson(Map<String, dynamic>.from(e))).toList();

    if (!mounted) return;
    setState(() {
      _records = records;
      _schemes = schemes;
      _setsBySchemeId = setsBySchemeId;
      _isLoading = false;
    });
  }

  Future<void> _persistRecords() async {
    await _miscDao.replaceRecordsByCategory(widget.categoryName, _records.map((r) => r.toJson()).toList());
  }

  double get _totalAmount => _records.fold<double>(0, (sum, r) => sum + r.totalAmount);

  // ─── CRUD Actions ─────────────────────────────────────────────────

  Future<void> _addEntry() async {
    final created = await showDialog<MiscRecord>(
      context: context,
      builder: (ctx) => MiscEntryForm(
        category: widget.categoryName,
        schemes: _schemes,
        setsBySchemeId: _setsBySchemeId,
      ),
    );
    if (created == null) return;
    setState(() => _records.add(created));
    await _persistRecords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry saved.')),
      );
    }
  }

  Future<void> _editEntry(MiscRecord record) async {
    final updated = await showDialog<MiscRecord>(
      context: context,
      builder: (ctx) => MiscEntryForm(
        category: widget.categoryName,
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

  Future<void> _duplicateEntry(MiscRecord record) async {
    final duplicate = record.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    final created = await showDialog<MiscRecord>(
      context: context,
      builder: (ctx) => MiscEntryForm(
        category: widget.categoryName,
        schemes: _schemes,
        setsBySchemeId: _setsBySchemeId,
        existing: duplicate,
      ),
    );
    if (created == null) return;
    setState(() => _records.add(created));
    await _persistRecords();
  }

  Future<void> _deleteRecord(MiscRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete "${record.title}"?'),
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

  // ─── PDF Export ───────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    try {
      final savedHeader = await ExportService.loadHeaderText();
      final headerText = await ExportService.showHeaderEditDialog(context, currentHeader: savedHeader);
      if (!mounted) return;

      final header = (headerText != null && headerText.isNotEmpty) ? headerText : (savedHeader ?? '');
      final bytes = await _buildPdf(header: header);

      if (headerText != null && headerText.isNotEmpty) {
        await ExportService.saveHeaderText(headerText);
      }

      final pdfName = '${widget.categoryName.replaceAll(RegExp(r'[^\w\s]'), '_')}_Register.pdf';
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
            if (header.isNotEmpty) ...[
              pw.Text(header, style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 4),
            ],
            pw.Text('${widget.categoryName} Register', style: pw.TextStyle(font: boldFont, fontSize: 12)),
            pw.SizedBox(height: 2),
            pw.Text(
              'Total Entries: ${_records.length}  |  Total Amount: ${CurrencyUtils.formatAmount(_totalAmount)}',
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
            headerStyle: pw.TextStyle(font: boldFont, fontSize: 7),
            cellStyle: pw.TextStyle(font: font, fontSize: 6.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellHeight: 20,
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
              8: pw.Alignment.centerLeft,
            },
            headers: [
              'Sr.No',
              'Date',
              'Title',
              'Location',
              'Scheme Ref',
              'Amount',
              'Voucher',
              'W.O.No',
              'Notes',
            ],
            data: _records.asMap().entries.map((entry) {
              final r = entry.value;
              final location = r.locationType == 'external'
                  ? [r.locationName, r.locationAddress].where((e) => e != null && e.isNotEmpty).join(', ')
                  : '';
              final schemeRef = r.locationType == 'scheme'
                  ? [r.schemeName, r.setLabel].where((e) => e != null && e.isNotEmpty).join(' - ')
                  : '';
              return [
                '${entry.key + 1}',
                r.date,
                r.title,
                location,
                schemeRef,
                CurrencyUtils.formatAmount(r.amount),
                r.voucherNo ?? '',
                r.workOrderNo ?? '',
                r.notes ?? '',
              ];
            }).toList(),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.4),
              1: const pw.FlexColumnWidth(0.8),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.4),
              4: const pw.FlexColumnWidth(1.3),
              5: const pw.FlexColumnWidth(0.8),
              6: const pw.FlexColumnWidth(0.8),
              7: const pw.FlexColumnWidth(0.7),
              8: const pw.FlexColumnWidth(1.5),
            },
            border: pw.TableBorder.all(width: 0.5),
          ),
          // Manual writing rows
          if (_records.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(font: boldFont, fontSize: 7),
              cellStyle: pw.TextStyle(font: font, fontSize: 6.5),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellHeight: 20,
              headerAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerLeft,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
                7: pw.Alignment.center,
                8: pw.Alignment.centerLeft,
              },
              headers: [
                'Sr.No',
                'Date',
                'Title',
                'Location',
                'Scheme Ref',
                'Amount',
                'Voucher',
                'W.O.No',
                'Notes',
              ],
              data: List.generate(6, (i) => [
                '${_records.length + i + 1}',
                '', '', '', '', '', '', '', '',
              ]),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.4),
                1: const pw.FlexColumnWidth(0.8),
                2: const pw.FlexColumnWidth(1.6),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(0.8),
                6: const pw.FlexColumnWidth(0.8),
                7: const pw.FlexColumnWidth(0.7),
                8: const pw.FlexColumnWidth(1.5),
              },
              border: pw.TableBorder.all(width: 0.5),
            ),
          ],
        ],
      ),
    );
    return pdf.save();
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.categoryName} Register'),
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
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRegisterTable(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'No ${widget.categoryName.toLowerCase()} entries yet.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            const Text('Tap + to add an entry.', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTable() {
    return Column(
      children: [
        // Summary bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                '${_records.length} records',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                'Total: ${CurrencyUtils.formatAmount(_totalAmount)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        // Table
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Expanded(child: Center(child: Text('Sr.No')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Date')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Title')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Location')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Scheme Ref')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Amount')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Voucher')))),
                    DataColumn(label: Expanded(child: Center(child: Text('W.O.No')))),
                    DataColumn(label: Expanded(child: Center(child: Text('Actions')))),
                  ],
                  rows: _records.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final r = entry.value;
                    final location = r.locationType == 'external'
                        ? [r.locationName, r.locationAddress].where((e) => e != null && e.isNotEmpty).join(', ')
                        : '';
                    final schemeRef = r.locationType == 'scheme'
                        ? [r.schemeName, r.setLabel].where((e) => e != null && e.isNotEmpty).join(' - ')
                        : '';
                    return DataRow(cells: [
                      DataCell(Center(child: Text('${idx + 1}'))),
                      DataCell(Center(child: Text(r.date))),
                      DataCell(Text(r.title, style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(location, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DataCell(Text(schemeRef, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      DataCell(Center(child: Text(CurrencyUtils.formatAmount(r.amount)))),
                      DataCell(Center(child: Text(r.voucherNo ?? ''))),
                      DataCell(Center(child: Text(r.workOrderNo ?? ''))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editEntry(r),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy, size: 18),
                              onPressed: () => _duplicateEntry(r),
                              tooltip: 'Duplicate',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              onPressed: () => _deleteRecord(r),
                              tooltip: 'Delete',
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
        ),
      ],
    );
  }
}
