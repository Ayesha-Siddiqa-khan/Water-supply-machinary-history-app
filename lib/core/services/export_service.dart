import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart' as xl;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../database/daos/schemes_dao.dart';
import '../database/daos/sets_dao.dart';
import '../database/daos/machinery_dao.dart';
import '../database/daos/billing_entries_dao.dart';
import '../database/daos/miscellaneous_dao.dart';
import '../database/daos/settings_dao.dart';
import '../models/machinery.dart';
import '../models/set_model.dart';
import '../models/scheme.dart';
import '../models/billing_entry.dart';

class _CompleteSetReport {
  final SetModel set;
  final List<Machinery> machinery;
  final Map<int, List<BillingEntry>> entriesByMachinery;

  const _CompleteSetReport({
    required this.set,
    required this.machinery,
    required this.entriesByMachinery,
  });
}

class _CompleteSchemeReport {
  final Scheme scheme;
  final List<_CompleteSetReport> sets;
  final Map<String, Map<String, int>> breakdown;

  const _CompleteSchemeReport({
    required this.scheme,
    required this.sets,
    required this.breakdown,
  });

  int get machineryCount =>
      sets.fold(0, (total, setReport) => total + setReport.machinery.length);
}

class _CompleteDetailPage {
  final _CompleteSchemeReport schemeReport;
  final _CompleteSetReport? setReport;
  final List<Machinery> machinery;
  final int rowStart;
  final int rowEnd;
  final bool continued;
  final bool showSetInformation;
  final bool showSpecifications;

  const _CompleteDetailPage({
    required this.schemeReport,
    required this.setReport,
    this.machinery = const [],
    this.rowStart = 0,
    this.rowEnd = 0,
    this.continued = false,
    this.showSetInformation = false,
    this.showSpecifications = false,
  });
}

class ExportService {
  static const double _reportTableFontSize = 10;
  static const double _reportTableHeaderFontSize = 10;
  static const int _manualWritingRows = 6;

  final SchemesDao _schemesDao = SchemesDao();
  final SetsDao _setsDao = SetsDao();

  // Cached fonts for PDF rendering (supports Latin + Urdu/Arabic)
  pw.Font? _baseFont;
  pw.Font? _boldFont;
  pw.Font? _arabicFont;
  List<pw.Font>? _fontFallback;

  Future<void> _ensureFontsLoaded() async {
    if (_baseFont != null) return;
    final regularData = await rootBundle.load(
      'assets/fonts/NotoSans-Regular.ttf',
    );
    final boldData = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final arabicData = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );
    _baseFont = pw.Font.ttf(regularData);
    _boldFont = pw.Font.ttf(boldData);
    _arabicFont = pw.Font.ttf(arabicData);
    _fontFallback = [_arabicFont!];
  }

  pw.ThemeData _pdfTheme() {
    return pw.ThemeData.withFont(base: _baseFont!, bold: _boldFont!);
  }

  static const String _headerSettingKey = 'report_header_text';

  static Future<String?> showHeaderEditDialog(
    BuildContext context, {
    String? currentHeader,
  }) async {
    final controller = TextEditingController(text: currentHeader ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Report Header'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize the heading text that appears at the top of the PDF report.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Report Title',
                hintText: 'e.g., Canal Water Works Machinery Record',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Reset to Default'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    return result;
  }

  static Future<void> saveHeaderText(String text) async {
    final settingsDao = SettingsDao();
    if (text.isEmpty) {
      await settingsDao.setSetting(_headerSettingKey, '');
    } else {
      await settingsDao.setSetting(_headerSettingKey, text);
    }
  }

  static Future<String?> loadHeaderText() async {
    final settingsDao = SettingsDao();
    final saved = await settingsDao.getSetting(_headerSettingKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return null;
  }

  final MachineryDao _machineryDao = MachineryDao();
  final BillingEntriesDao _entriesDao = BillingEntriesDao();
  final MiscellaneousDao _miscDao = MiscellaneousDao();

  String _formatAmount(double amount) {
    final f = NumberFormat('#,##0', 'en_US');
    return 'PKR ${f.format(amount)}';
  }

  String _nowFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  String _normalizeType(String rawType) {
    final lower = rawType.trim().toLowerCase();
    if (lower == 'motor') return 'Motor';
    if (lower == 'pump') return 'Pump';
    if (lower == 'transformer') return 'Transformer';
    if (lower == 'turbine') return 'Turbine';
    return rawType.trim().isEmpty ? 'Unknown' : rawType.trim();
  }

  String _extractSpecLabel(Machinery machinery) {
    final specs = machinery.specs;
    final type = _normalizeType(machinery.machineryType);

    if (type == 'Motor') {
      final hp = specs['Horsepower'] ?? specs['HP'];
      return hp?.trim().isNotEmpty == true ? hp!.trim() : 'Unknown HP';
    }
    if (type == 'Pump') {
      final size = specs['Size'];
      return size?.trim().isNotEmpty == true ? size!.trim() : 'Unknown Size';
    }
    if (type == 'Transformer') {
      final kv =
          specs['kVA Rating'] ??
          specs['KVA Rating'] ??
          specs['kVA'] ??
          specs['KV'];
      if (kv?.trim().isNotEmpty == true) {
        return kv!.trim().replaceAll(
          RegExp(r'kva', caseSensitive: false),
          'Kv',
        );
      }
      return 'Unknown Kv';
    }
    if (type == 'Turbine') {
      return 'Turbine';
    }

    return machinery.displayLabel.trim().isNotEmpty
        ? machinery.displayLabel.trim()
        : 'Unspecified';
  }

  Future<Map<String, int>> _countSchemesByKeyTypes() async {
    final schemes = await _schemesDao.getAllSchemes();
    int schemesWithTurbine = 0;
    int schemesWithPump = 0;

    for (int schemeIndex = 0; schemeIndex < schemes.length; schemeIndex++) {
      final scheme = schemes[schemeIndex];
      final schemeId = scheme.schemeId;
      if (schemeId == null) continue;

      final sets = await _setsDao.getSetsForScheme(schemeId);
      bool hasTurbine = false;
      bool hasPump = false;

      for (final setModel in sets) {
        final setId = setModel.setId;
        if (setId == null) continue;

        final machineryList = await _machineryDao.getMachineryForSet(setId);
        for (final machinery in machineryList) {
          final type = _normalizeType(machinery.machineryType).toLowerCase();
          if (type == 'turbine') hasTurbine = true;
          if (type == 'pump') hasPump = true;
          if (hasTurbine && hasPump) break;
        }

        if (hasTurbine && hasPump) break;
      }

      if (hasTurbine) schemesWithTurbine++;
      if (hasPump) schemesWithPump++;
    }

    return {'turbine': schemesWithTurbine, 'pump': schemesWithPump};
  }

  Future<Uint8List> exportMachineryReportToPdf() async {
    await _ensureFontsLoaded();
    final machineryList = await _machineryDao.getAllMachineryWithStats();
    final schemeTypeCounts = await _countSchemesByKeyTypes();

    final totalByType = <String, int>{};
    final functionalByType = <String, int>{};
    final amountByType = <String, double>{};
    final specCountsByType = <String, Map<String, int>>{};

    for (final machinery in machineryList) {
      final type = _normalizeType(machinery.machineryType);
      totalByType[type] = (totalByType[type] ?? 0) + 1;
      functionalByType[type] = totalByType[type]!;
      amountByType[type] = (amountByType[type] ?? 0.0) + machinery.totalAmount;

      final specLabel = _extractSpecLabel(machinery);
      final typeMap = specCountsByType.putIfAbsent(type, () => <String, int>{});
      typeMap[specLabel] = (typeMap[specLabel] ?? 0) + 1;
    }

    const preferred = ['Motor', 'Pump', 'Transformer', 'Turbine'];
    final typeSet = totalByType.keys.toSet();
    final orderedTypes = <String>[];
    for (final type in preferred) {
      if (typeSet.contains(type)) orderedTypes.add(type);
    }
    final others = typeSet.where((t) => !preferred.contains(t)).toList()
      ..sort();
    orderedTypes.addAll(others);

    final totalFunctional = functionalByType.values.fold<int>(
      0,
      (sum, v) => sum + v,
    );
    final totalMachinery = totalByType.values.fold<int>(0, (sum, v) => sum + v);
    final grandTotalAmount = amountByType.values.fold<double>(
      0.0,
      (sum, v) => sum + v,
    );

    final pdf = pw.Document(theme: _pdfTheme());
    final headerColor = PdfColor.fromHex('#1E3A5F');

    pdf.addPage(
      pw.MultiPage(
        // The summary contains four wide KPI columns. Landscape keeps the
        // type names and complete specification breakdown on one line.
        pageFormat: PdfPageFormat.a4.landscape,
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Machinery Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_nowFormatted()}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Total Functional Machinery: $totalFunctional / $totalMachinery',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Total Amount: ${_formatAmount(grandTotalAmount)}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Schemes with Turbines: ${schemeTypeCounts['turbine'] ?? 0}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Schemes with Pumps: ${schemeTypeCounts['pump'] ?? 0}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: _reportTableHeaderFontSize,
              fontFallback: _fontFallback ?? [],
            ),
            headerDecoration: pw.BoxDecoration(color: headerColor),
            cellStyle: pw.TextStyle(
              fontSize: _reportTableFontSize,
              fontFallback: _fontFallback ?? [],
            ),
            columnWidths: {
              0: pw.FixedColumnWidth(95),
              1: pw.FixedColumnWidth(110),
              2: pw.FixedColumnWidth(145),
              3: pw.FlexColumnWidth(1),
            },
            cellAlignment: pw.Alignment.center,
            headerAlignment: pw.Alignment.center,
            headers: const [
              'Type',
              'Functional / Total',
              'Total Amount (PKR)',
              'Specification Breakdown',
            ],
            data: orderedTypes.map((type) {
              final functional = functionalByType[type] ?? 0;
              final total = totalByType[type] ?? 0;
              final typeAmount = amountByType[type] ?? 0.0;
              final specs = specCountsByType[type] ?? const <String, int>{};
              final specRows = specs.keys.toList()..sort();
              final specText = specRows.isEmpty
                  ? '-'
                  : specRows.map((spec) => '$spec × ${specs[spec]}').join(', ');
              return [
                type,
                '$functional / $total',
                _formatAmount(typeAmount),
                specText,
              ];
            }).toList(),
          ),
          if (orderedTypes.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Text(
                'No machinery data available.',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
              ),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  // ─────────────────── PDF Export ───────────────────

  Future<Uint8List> exportSetToPdf(
    int setId, {
    bool includeSpecs = false,
    String? headerText,
  }) async {
    return _exportSetToPdfInternal(
      setId,
      includeSpecs: includeSpecs,
      headerText: headerText,
    );
  }

  Future<Uint8List> exportSingleMachineryToPdf(
    int setId,
    int machineryId, {
    String? headerText,
  }) async {
    final machineryList = await _machineryDao.getMachineryForSet(setId);
    final selected = machineryList
        .where((m) => m.machineryId == machineryId)
        .firstOrNull;
    if (selected == null) {
      throw Exception('Selected machinery not found');
    }
    return _exportSetToPdfInternal(
      setId,
      machineryOverride: [selected],
      headerText: headerText,
    );
  }

  Future<Uint8List> _exportSetToPdfInternal(
    int setId, {
    List<Machinery>? machineryOverride,
    bool includeSpecs = false,
    String? headerText,
  }) async {
    await _ensureFontsLoaded();
    final setModel = await _setsDao.getSetById(setId);
    if (setModel == null) throw Exception('Set not found');

    final scheme = await _schemesDao.getSchemeById(setModel.schemeId);
    final isUselessScheme =
        (scheme?.category ?? '').toLowerCase() == 'useless_item';
    final machineryList =
        machineryOverride ?? await _machineryDao.getMachineryForSet(setId);
    if (machineryList.isEmpty) {
      throw Exception('No machinery found in selected set');
    }
    final entries = await _entriesDao.getEntriesForSet(setId);

    final entriesByMachinery = <int, List<BillingEntry>>{};
    int maxRows = 0;
    for (final machinery in machineryList) {
      final machineryEntries =
          entries
              .where((entry) => entry.machineryId == machinery.machineryId)
              .toList()
            ..sort((a, b) => a.serialNo.compareTo(b.serialNo));
      entriesByMachinery[machinery.machineryId!] = machineryEntries;
      if (machineryEntries.length > maxRows) {
        maxRows = machineryEntries.length;
      }
    }
    final existingRowCount = maxRows;
    final minimumRegisterRows = includeSpecs ? 9 : 14;
    maxRows = math.max(
      existingRowCount + _manualWritingRows,
      minimumRegisterRows,
    );

    const maxMachineryPerBlock = 3;
    final machineryBlocks = <List<Machinery>>[];
    for (int i = 0; i < machineryList.length; i += maxMachineryPerBlock) {
      final end = (i + maxMachineryPerBlock) > machineryList.length
          ? machineryList.length
          : (i + maxMachineryPerBlock);
      machineryBlocks.add(machineryList.sublist(i, end));
    }

    final pdf = pw.Document(theme: _pdfTheme());
    final setInfo = setModel.details.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              scheme?.schemeName ?? 'Unknown Scheme',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            if (isUselessScheme) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                headerText ?? 'Useless Items Transfer Report',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Text(
            setModel.setLabel,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          if (setInfo.isNotEmpty) ...[
            _setInformationTable(setModel),
            pw.SizedBox(height: 6),
          ],
          ...machineryBlocks.asMap().entries.expand((blockEntry) {
            final blockIndex = blockEntry.key;
            final block = blockEntry.value;
            final tableWidth = PdfPageFormat.a4.landscape.width - 36;
            final perMachineryCols = isUselessScheme ? 6 : 4;
            final srNoWidth = 40.0;
            final dataCols = block.length * perMachineryCols;
            final dataColWidth = (tableWidth - srNoWidth) / dataCols;
            final firstHeaderWidth =
                srNoWidth + dataColWidth * perMachineryCols;
            final otherHeaderWidth = dataColWidth * perMachineryCols;

            return <pw.Widget>[
              if (blockIndex > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    'Continued',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              if (includeSpecs)
                ...block.expand((machinery) {
                  final specs = machinery.specs.entries
                      .where((e) => e.value.trim().isNotEmpty)
                      .toList();
                  if (specs.isEmpty) return <pw.Widget>[];
                  return [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.black,
                          width: 0.45,
                        ),
                      ),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text:
                                  '${_normalizeType(machinery.machineryType)} Specifications - ${_machineryHeaderLabel(machinery)}\n',
                              style: pw.TextStyle(
                                fontSize: _reportTableHeaderFontSize,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: specs
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(' | '),
                              style: const pw.TextStyle(
                                fontSize: _reportTableFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                  ];
                }),
              if (!isUselessScheme) ...[
                _machineryRegisterTable(
                  machinery: block,
                  entriesByMachinery: entriesByMachinery,
                  startRow: 0,
                  rowCount: maxRows,
                  tableWidth: tableWidth,
                  dataRowHeight: includeSpecs ? 28 : 27,
                ),
                pw.SizedBox(height: 2),
              ] else ...[
                pw.Row(
                  children: [
                    ...block.asMap().entries.map((entry) {
                      final index = entry.key;
                      final machinery = entry.value;
                      return _pdfCell(
                        _machineryHeaderLabel(machinery),
                        width: index == 0 ? firstHeaderWidth : otherHeaderWidth,
                        bold: true,
                        align: pw.TextAlign.center,
                      );
                    }),
                  ],
                ),
                pw.Row(
                  children: [
                    _pdfCell(
                      'Sr.No',
                      width: srNoWidth,
                      bold: true,
                      align: pw.TextAlign.center,
                    ),
                    ...block.expand(
                      (_) => isUselessScheme
                          ? [
                              _pdfCell(
                                'Reg. Page No.',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Disabled/Closed',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Submitted To Store',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Transfer Date',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Transferred To Scheme',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Remarks',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                            ]
                          : [
                              _pdfCell(
                                'Date',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'W.O. No.',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Voucher No.',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                              _pdfCell(
                                'Amount',
                                width: dataColWidth,
                                bold: true,

                                align: pw.TextAlign.center,
                              ),
                            ],
                    ),
                  ],
                ),
                ...List.generate(maxRows, (rowIndex) {
                  final rowHasEntry = block.any((machinery) {
                    final machineryEntries =
                        entriesByMachinery[machinery.machineryId!] ?? [];
                    return rowIndex < machineryEntries.length;
                  });
                  return pw.Row(
                    children: [
                      _pdfCell(
                        rowHasEntry ? '${rowIndex + 1}' : '',
                        width: srNoWidth,
                        align: pw.TextAlign.center,
                      ),
                      ...block.expand((machinery) {
                        final mEntries =
                            entriesByMachinery[machinery.machineryId!] ?? [];
                        final entry = rowIndex < mEntries.length
                            ? mEntries[rowIndex]
                            : null;
                        if (isUselessScheme) {
                          return [
                            _pdfCell(
                              entry?.regPageNo ?? '',
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              entry == null
                                  ? ''
                                  : (entry.isDisabled ? 'Yes' : 'Active'),
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              entry?.submittedToStoreDate ?? '',
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              entry?.transferDate ?? '',
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              entry?.transferredToScheme ?? '',
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              entry?.remarks ?? entry?.notes ?? '',
                              width: dataColWidth,
                              align: pw.TextAlign.center,
                            ),
                          ];
                        }
                        return [
                          _pdfCell(
                            entry?.entryDate ?? '',
                            width: dataColWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.workOrderNo ?? '',
                            width: dataColWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.voucherNo?.toString() ?? '',
                            width: dataColWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry != null ? _formatAmount(entry.amount) : '',
                            width: dataColWidth,
                            align: pw.TextAlign.center,
                          ),
                        ];
                      }),
                    ],
                  );
                }),
                pw.SizedBox(height: 8),
              ],
            ];
          }),
          pw.SizedBox(height: 2),
        ],
      ),
    );

    return pdf.save();
  }

  String _machineryHeaderLabel(Machinery machinery) {
    final type = machinery.machineryType;
    final specs = machinery.specs;
    final lowerType = type.toLowerCase();

    String? keySpec;
    if (lowerType == 'motor') {
      keySpec = specs['Horsepower'];
    } else if (lowerType == 'pump') {
      keySpec = specs['Size'];
    } else if (lowerType == 'transformer') {
      keySpec = specs['kVA Rating'];
    }

    final parts = <String>[type];
    if (keySpec != null && keySpec.trim().isNotEmpty) {
      parts.add(keySpec.trim());
    }
    if (machinery.brand != null && machinery.brand!.trim().isNotEmpty) {
      parts.add(machinery.brand!.trim());
    }

    final computed = parts.join(' ').trim();
    if (computed.toLowerCase() == type.toLowerCase() &&
        machinery.displayLabel.trim().isNotEmpty) {
      return machinery.displayLabel.trim();
    }
    return computed;
  }

  String _excelStyleSetHeading(String schemeName, String setLabel) {
    final normalizedSet = setLabel.replaceFirst('Set No. ', 'Set No.');
    return '$schemeName $normalizedSet';
  }

  pw.Widget _setInformationTable(SetModel set) {
    const fields = [
      'Location / GPS Coordinates',
      'Electricity Bill Reference No.',
      'Electricity Distribution Company',
    ];
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Location / GPS',
        'Electricity Bill Reference No.',
        'Electricity Distribution Company',
      ],
      data: [fields.map((field) => set.details[field] ?? '-').toList()],
      headerStyle: pw.TextStyle(
        fontSize: _reportTableHeaderFontSize,
        fontWeight: pw.FontWeight.bold,
      ),
      cellStyle: const pw.TextStyle(fontSize: _reportTableFontSize),
      headerDecoration: const pw.BoxDecoration(),
      headerAlignment: pw.Alignment.center,
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
    );
  }

  pw.Widget _pdfCell(
    String text, {
    required double width,
    bool bold = false,
    PdfColor? background,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    final hasArabic = _containsArabic(text);
    final effectiveAlign = hasArabic ? pw.TextAlign.right : align;

    return pw.Container(
      width: width,
      constraints: const pw.BoxConstraints(minHeight: 22),
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border.all(width: 0.8, color: PdfColors.black),
      ),
      child: pw.Text(
        text,
        textAlign: effectiveAlign,
        textDirection: hasArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: pw.TextStyle(
          fontSize: _reportTableFontSize,
          font: hasArabic ? _arabicFont : (bold ? _boldFont : _baseFont),
          fontBold: _boldFont,
          fontFallback: _fontFallback ?? [],
          color: PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _machineryRegisterTable({
    required List<Machinery> machinery,
    required Map<int, List<BillingEntry>> entriesByMachinery,
    required int startRow,
    required int rowCount,
    required double tableWidth,
    double dataRowHeight = 27,
  }) {
    const borderSide = pw.BorderSide(color: PdfColors.black, width: 0.65);
    final totalColumns = 1 + (machinery.length * 4);

    pw.Widget cell(String text, {bool bold = false, double height = 27}) {
      final hasArabic = _containsArabic(text);
      return pw.Container(
        height: height,
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          textDirection: hasArabic
              ? pw.TextDirection.rtl
              : pw.TextDirection.ltr,
          style: pw.TextStyle(
            fontSize: _reportTableFontSize,
            font: hasArabic ? _arabicFont : (bold ? _boldFont : _baseFont),
            fontBold: _boldFont,
            fontFallback: _fontFallback ?? [],
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: machinery.asMap().entries.map((machineEntry) {
        final machineIndex = machineEntry.key;
        final item = machineEntry.value;
        final isFirst = machineIndex == 0;
        final columnCount = isFirst ? 5 : 4;
        final blockWidth = tableWidth * columnCount / totalColumns;
        final itemEntries =
            entriesByMachinery[item.machineryId] ?? const <BillingEntry>[];
        final headers = <String>[
          if (isFirst) 'Sr.No',
          'Date',
          'W.O. No.',
          'Voucher No.',
          'Amount',
        ];

        final tableRows = <pw.TableRow>[
          pw.TableRow(
            children: headers
                .map((header) => cell(header, bold: true, height: 32))
                .toList(),
          ),
          for (int offset = 0; offset < rowCount; offset++)
            pw.TableRow(
              children: () {
                final rowIndex = startRow + offset;
                final entry = rowIndex < itemEntries.length
                    ? itemEntries[rowIndex]
                    : null;
                final rowHasAnyEntry = machinery.any((machineryItem) {
                  final entries =
                      entriesByMachinery[machineryItem.machineryId] ??
                      const <BillingEntry>[];
                  return rowIndex < entries.length;
                });
                return [
                  if (isFirst) rowHasAnyEntry ? '${rowIndex + 1}' : '',
                  entry?.entryDate ?? '',
                  entry?.workOrderNo ?? '',
                  entry?.voucherNo?.toString() ?? '',
                  entry == null ? '' : _formatAmount(entry.amount),
                ].map((value) => cell(value, height: dataRowHeight)).toList();
              }(),
            ),
        ];

        return pw.SizedBox(
          width: blockWidth,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                height: 28,
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: isFirst ? borderSide : pw.BorderSide.none,
                    top: borderSide,
                    right: borderSide,
                  ),
                ),
                child: pw.Text(
                  _machineryHeaderLabel(item),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: _reportTableHeaderFontSize,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Table(
                columnWidths: {
                  for (int index = 0; index < columnCount; index++)
                    index: const pw.FlexColumnWidth(),
                },
                border: pw.TableBorder(
                  left: isFirst ? borderSide : pw.BorderSide.none,
                  top: borderSide,
                  right: borderSide,
                  bottom: borderSide,
                  horizontalInside: borderSide,
                  verticalInside: borderSide,
                ),
                children: tableRows,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Printable A4 report for the set detail page: equipment info and billing
  /// entries, optionally including full specification tables.
  Future<Uint8List> buildSetDetailReport({
    required SetModel set,
    Scheme? scheme,
    required List<Machinery> machineryList,
    required Map<int, List<BillingEntry>> entriesByMachineryId,
    bool includeSpecs = false,
    String? headerText,
  }) async {
    await _ensureFontsLoaded();
    final pdf = pw.Document(theme: _pdfTheme());

    final schemeName = scheme?.schemeName ?? '';
    final content = <pw.Widget>[
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            schemeName,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
      pw.SizedBox(height: 7),
      pw.Text(
        set.setLabel,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 5),
    ];

    final setInfo = set.details.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    if (setInfo.isNotEmpty) {
      content.add(_setInformationTable(set));
      content.add(pw.SizedBox(height: 6));
    }

    if (includeSpecs) {
      for (final machinery in machineryList) {
        final specs = machinery.specs.entries
            .where((e) => e.value.trim().isNotEmpty)
            .toList();
        if (specs.isNotEmpty) {
          content.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 3,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 0.45),
              ),
              child: pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text:
                          '${_normalizeType(machinery.machineryType)} Specifications - ${_machineryHeaderLabel(machinery)}\n',
                      style: pw.TextStyle(
                        fontSize: _reportTableHeaderFontSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.TextSpan(
                      text: specs
                          .map((entry) => '${entry.key}: ${entry.value}')
                          .join(' | '),
                      style: const pw.TextStyle(fontSize: _reportTableFontSize),
                    ),
                  ],
                ),
              ),
            ),
          );
          content.add(pw.SizedBox(height: 2));
        }
      }
      content.add(pw.SizedBox(height: 2));
    }

    const maxMachineryPerBlock = 3;
    for (
      int start = 0;
      start < machineryList.length;
      start += maxMachineryPerBlock
    ) {
      final end = math.min(start + maxMachineryPerBlock, machineryList.length);
      final block = machineryList.sublist(start, end);
      int existingRows = 0;
      for (final machinery in block) {
        existingRows = math.max(
          existingRows,
          entriesByMachineryId[machinery.machineryId]?.length ?? 0,
        );
      }
      final rowCount = math.max(
        existingRows + _manualWritingRows,
        includeSpecs ? 10 : 14,
      );
      content.add(
        _machineryRegisterTable(
          machinery: block,
          entriesByMachinery: entriesByMachineryId,
          startRow: 0,
          rowCount: rowCount,
          tableWidth: PdfPageFormat.a4.landscape.width - 36,
        ),
      );
      content.add(pw.SizedBox(height: 2));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => content,
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> buildUselessItemsRegister({
    required Scheme scheme,
    required List<SetModel> sets,
    required Map<int, List<Machinery>> machineryBySetId,
    required Map<int, List<BillingEntry>> entriesByMachineryId,
    String? headerText,
  }) async {
    await _ensureFontsLoaded();
    final pdf = pw.Document(theme: _pdfTheme());

    final headerStyle = pw.TextStyle(
      fontSize: _reportTableHeaderFontSize,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
      fontFallback: _fontFallback ?? [],
    );
    final cellStyle = pw.TextStyle(
      fontSize: _reportTableFontSize,
      fontFallback: _fontFallback ?? [],
    );
    final tableBorder = pw.TableBorder.all(color: PdfColors.black, width: 0.8);

    int srNo = 0;
    final tableRows = <List<String>>[];

    for (final set in sets) {
      final machineryList = machineryBySetId[set.setId!] ?? const [];
      for (final machinery in machineryList) {
        final entries =
            entriesByMachineryId[machinery.machineryId!] ?? const [];
        for (final entry in entries) {
          srNo++;
          tableRows.add([
            '$srNo',
            entry.entryDate,
            scheme.parentSchemeName ?? scheme.schemeName,
            scheme.parentSetLabel ?? set.setLabel,
            machinery.displayLabel,
            entry.isDisabled ? 'Disabled/Closed' : 'Active',
            entry.submittedToStoreDate ?? '-',
            entry.transferDate ?? '-',
            entry.transferredToScheme ?? '-',
            entry.regPageNo ?? '-',
            entry.remarks ?? entry.notes ?? '-',
          ]);
        }
      }
    }

    final content = <pw.Widget>[
      pw.Text(
        headerText ?? 'Useless Items Register',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        scheme.schemeName,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 12),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Total Items: $srNo | Printed on ${_nowFormatted()}',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 12, color: PdfColors.black),
      ),
      pw.SizedBox(height: 10),
    ];

    tableRows.addAll(
      List.generate(_manualWritingRows, (_) => List<String>.filled(11, '')),
    );
    content.add(
      pw.TableHelper.fromTextArray(
        headers: [
          'Sr.No',
          'Date',
          'Scheme',
          'Set',
          'Item',
          'Status',
          'Store Date',
          'Transfer Date',
          'Transferred To',
          'Reg. Page',
          'Remarks',
        ],
        data: tableRows,
        headerStyle: headerStyle,
        headerDecoration: pw.BoxDecoration(),
        headerAlignment: pw.Alignment.center,
        cellStyle: cellStyle,
        cellAlignment: pw.Alignment.center,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        border: tableBorder,
        columnWidths: {
          0: const pw.FlexColumnWidth(0.6),
          1: const pw.FlexColumnWidth(1.0),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(1.0),
          4: const pw.FlexColumnWidth(1.2),
          5: const pw.FlexColumnWidth(0.9),
          6: const pw.FlexColumnWidth(1.0),
          7: const pw.FlexColumnWidth(1.0),
          8: const pw.FlexColumnWidth(1.2),
          9: const pw.FlexColumnWidth(0.7),
          10: const pw.FlexColumnWidth(1.5),
        },
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        build: (context) => content,
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> exportAllUselessItemsRegister({String? headerText}) async {
    await _ensureFontsLoaded();
    final records = await _schemesDao.getSchemesByCategory('useless_item');
    final rows = <List<String>>[];
    int serialNo = 0;

    for (final record in records) {
      final recordId = record.schemeId;
      if (recordId == null) continue;
      final sets = await _setsDao.getSetsForScheme(recordId);
      for (final set in sets) {
        final setId = set.setId;
        if (setId == null) continue;
        final machineryList = await _machineryDao.getMachineryForSet(setId);
        for (final machinery in machineryList) {
          final machineryId = machinery.machineryId;
          if (machineryId == null) continue;
          final entries = await _entriesDao.getEntriesForMachinery(machineryId);

          if (entries.isEmpty) {
            serialNo++;
            rows.add([
              '$serialNo',
              '-',
              record.parentSchemeName ?? 'Unassigned Scheme',
              record.parentSetLabel ?? 'Unassigned Set',
              machinery.displayLabel,
              'In Store',
              '-',
              '-',
              '-',
              '-',
              record.description ?? '-',
            ]);
            continue;
          }

          for (final entry in entries) {
            serialNo++;
            rows.add([
              '$serialNo',
              entry.entryDate,
              record.parentSchemeName ?? 'Unassigned Scheme',
              record.parentSetLabel ?? 'Unassigned Set',
              machinery.displayLabel,
              entry.isDisabled ? 'Damaged / Unusable' : 'In Store',
              entry.submittedToStoreDate ?? '-',
              entry.transferDate ?? '-',
              entry.transferredToScheme ?? '-',
              entry.regPageNo ?? '-',
              entry.remarks ?? entry.notes ?? record.description ?? '-',
            ]);
          }
        }
      }
    }

    final pdf = pw.Document(theme: _pdfTheme());
    rows.addAll(
      List.generate(_manualWritingRows, (_) => List<String>.filled(11, '')),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(14),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Text(
            headerText ?? 'Useless Items Store Register',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            'Damaged, unusable, and out-of-service equipment held in store',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Sr.No',
              'Date',
              'Scheme',
              'Set',
              'Item',
              'Condition',
              'Store Date',
              'Transfer Date',
              'Transferred To',
              'Reg. Page',
              'Remarks',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              fontSize: _reportTableHeaderFontSize,
              fontWeight: pw.FontWeight.bold,
              fontFallback: _fontFallback ?? [],
            ),
            cellStyle: pw.TextStyle(
              fontSize: _reportTableFontSize,
              fontFallback: _fontFallback ?? [],
            ),
            headerAlignment: pw.Alignment.center,
            cellAlignment: pw.Alignment.center,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 5,
            ),
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
            columnWidths: const {
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(0.9),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(0.8),
              4: pw.FlexColumnWidth(1.4),
              5: pw.FlexColumnWidth(1.1),
              6: pw.FlexColumnWidth(0.9),
              7: pw.FlexColumnWidth(0.9),
              8: pw.FlexColumnWidth(1.2),
              9: pw.FlexColumnWidth(0.7),
              10: pw.FlexColumnWidth(1.5),
            },
          ),
        ],
      ),
    );
    return pdf.save();
  }

  static bool _containsArabic(String text) {
    // Arabic Unicode block: U+0600–U+06FF (covers Arabic, Urdu, Persian)
    return text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  }

  Future<Uint8List> exportSchemeToPdf(
    int schemeId, {
    String? headerText,
  }) async {
    await _ensureFontsLoaded();
    final scheme = await _schemesDao.getSchemeById(schemeId);
    if (scheme == null) throw Exception('Scheme not found');
    final isUselessScheme = scheme.category.toLowerCase() == 'useless_item';

    final sets = await _setsDao.getSetsForScheme(schemeId);
    final pdf = pw.Document(theme: _pdfTheme());

    final masterTemplates = <_MachineryTemplate>[];
    if (sets.isNotEmpty) {
      final firstSetMachinery = await _machineryDao.getMachineryForSet(
        sets.first.setId!,
      );
      for (final machinery in firstSetMachinery) {
        masterTemplates.add(
          _MachineryTemplate(
            type: machinery.machineryType,
            label: _machineryHeaderLabel(machinery),
          ),
        );
      }
    }

    final sectionWidgets = <pw.Widget>[];
    for (final setModel in sets) {
      final machineryList = await _machineryDao.getMachineryForSet(
        setModel.setId!,
      );
      final entries = await _entriesDao.getEntriesForSet(setModel.setId!);

      final actualTypes = machineryList
          .map((m) => _normalizeType(m.machineryType).toLowerCase())
          .toSet();
      final hasTurbine = actualTypes.contains('turbine');
      final hasPump = actualTypes.contains('pump');

      final effectiveMachineryList = <Machinery>[];
      final remainingMachinery = <Machinery>[...machineryList];

      for (final template in masterTemplates) {
        final templateType = _normalizeType(template.type).toLowerCase();
        if (hasTurbine && templateType == 'pump') continue;
        if (hasPump && templateType == 'turbine') continue;

        final idx = remainingMachinery.indexWhere(
          (m) => _normalizeType(m.machineryType).toLowerCase() == templateType,
        );

        if (idx >= 0) {
          effectiveMachineryList.add(remainingMachinery.removeAt(idx));
        } else {
          effectiveMachineryList.add(
            Machinery(
              machineryId: -1,
              setId: setModel.setId!,
              machineryType: template.type,
              displayLabel: template.label,
              specs: const {},
              brand: null,
            ),
          );
        }
      }

      effectiveMachineryList.addAll(remainingMachinery);

      if (isUselessScheme) {
        const typePriority = {
          'transformer': 0,
          'motor': 1,
          'pump': 2,
          'turbine': 3,
        };

        effectiveMachineryList.sort((a, b) {
          final aType = _normalizeType(a.machineryType).toLowerCase();
          final bType = _normalizeType(b.machineryType).toLowerCase();
          final aRank = typePriority[aType] ?? 99;
          final bRank = typePriority[bType] ?? 99;
          if (aRank != bRank) return aRank.compareTo(bRank);
          return _machineryHeaderLabel(a).compareTo(_machineryHeaderLabel(b));
        });
      }

      final entriesByMachinery = <int, List<BillingEntry>>{};
      int maxRows = 0;
      for (final machinery in effectiveMachineryList) {
        final machineryEntries =
            entries
                .where((entry) => entry.machineryId == machinery.machineryId)
                .toList()
              ..sort((a, b) => a.serialNo.compareTo(b.serialNo));
        entriesByMachinery[machinery.machineryId!] = machineryEntries;
        if (machineryEntries.length > maxRows) {
          maxRows = machineryEntries.length;
        }
      }
      maxRows = math.max(maxRows + _manualWritingRows, 14);

      const maxMachineryPerBlock = 3;
      final machineryBlocks = <List<Machinery>>[];
      for (
        int i = 0;
        i < effectiveMachineryList.length;
        i += maxMachineryPerBlock
      ) {
        final end = (i + maxMachineryPerBlock) > effectiveMachineryList.length
            ? effectiveMachineryList.length
            : (i + maxMachineryPerBlock);
        machineryBlocks.add(effectiveMachineryList.sublist(i, end));
      }

      if (isUselessScheme && sectionWidgets.isNotEmpty) {
        // Keep exactly one tubewell/set per page for useless export.
        sectionWidgets.add(pw.NewPage());
      }

      sectionWidgets.add(
        pw.Text(
          setModel.setLabel,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
      sectionWidgets.add(
        pw.Text(
          _excelStyleSetHeading(scheme.schemeName, setModel.setLabel),
          style: const pw.TextStyle(fontSize: 12),
        ),
      );
      sectionWidgets.add(pw.SizedBox(height: 4));

      if (effectiveMachineryList.isEmpty) {
        sectionWidgets.add(
          pw.Text('No machinery data', style: pw.TextStyle(fontSize: 12)),
        );
        sectionWidgets.add(pw.SizedBox(height: 10));
        continue;
      }

      if (isUselessScheme) {
        const dataColCount = 7;
        final tableWidth = PdfPageFormat.a4.landscape.width - 36;
        final uselessColWidth = (tableWidth - 40) / (dataColCount - 1);

        pw.Widget tableCell(String text, {bool bold = false}) {
          final isRtl = _containsArabic(text);
          return pw.Container(
            constraints: const pw.BoxConstraints(minHeight: 22),
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            child: pw.Directionality(
              textDirection: isRtl
                  ? pw.TextDirection.rtl
                  : pw.TextDirection.ltr,
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  text,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: _reportTableFontSize,
                    font: isRtl ? _arabicFont : (bold ? _boldFont : _baseFont),
                    fontBold: _boldFont,
                    fontFallback: _fontFallback ?? [],
                    fontWeight: bold
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }

        for (
          int machineIndex = 0;
          machineIndex < effectiveMachineryList.length;
          machineIndex++
        ) {
          final machinery = effectiveMachineryList[machineIndex];
          final mEntries = entriesByMachinery[machinery.machineryId!] ?? [];
          final rowCount = math.max(
            mEntries.length + _manualWritingRows,
            _manualWritingRows,
          );

          sectionWidgets.add(
            _pdfCell(
              _machineryHeaderLabel(machinery),
              width: tableWidth,
              bold: true,
              align: pw.TextAlign.center,
            ),
          );

          final tableRows = <pw.TableRow>[
            pw.TableRow(
              children: [
                tableCell('Sr.No', bold: true),
                tableCell('Reg. Page No.', bold: true),
                tableCell('Disabled/Closed', bold: true),
                tableCell('Submitted To Store', bold: true),
                tableCell('Transfer Date', bold: true),
                tableCell('Transferred To Scheme', bold: true),
                tableCell('Remarks', bold: true),
              ],
            ),
          ];

          for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
            final entry = rowIndex < mEntries.length
                ? mEntries[rowIndex]
                : null;
            tableRows.add(
              pw.TableRow(
                children: [
                  tableCell(entry == null ? '' : '${rowIndex + 1}'),
                  tableCell(entry?.regPageNo ?? ''),
                  tableCell(
                    entry == null ? '' : (entry.isDisabled ? 'Yes' : 'Active'),
                  ),
                  tableCell(entry?.submittedToStoreDate ?? ''),
                  tableCell(entry?.transferDate ?? ''),
                  tableCell(entry?.transferredToScheme ?? ''),
                  tableCell(entry?.remarks ?? entry?.notes ?? ''),
                ],
              ),
            );
          }

          sectionWidgets.add(
            pw.Table(
              columnWidths: {
                0: pw.FixedColumnWidth(40),
                for (int i = 1; i < dataColCount; i++)
                  i: pw.FixedColumnWidth(uselessColWidth),
              },
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: tableRows,
            ),
          );

          if (machineIndex < effectiveMachineryList.length - 1) {
            sectionWidgets.add(pw.SizedBox(height: 8));
          }
        }

        sectionWidgets.add(pw.SizedBox(height: 10));
        continue;
      }

      for (
        int blockIndex = 0;
        blockIndex < machineryBlocks.length;
        blockIndex++
      ) {
        final block = machineryBlocks[blockIndex];
        final tableWidth = PdfPageFormat.a4.landscape.width - 36;
        final perMachineryCols = isUselessScheme ? 6 : 3;
        final srNoWidth = 40.0;
        final dataCols = block.length * perMachineryCols;
        final dataColWidth = (tableWidth - srNoWidth) / dataCols;
        final firstHeaderWidth = srNoWidth + dataColWidth * perMachineryCols;
        final otherHeaderWidth = dataColWidth * perMachineryCols;

        if (blockIndex > 0) {
          sectionWidgets.add(
            pw.Text(
              '${setModel.setLabel} (continued)',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          );
          sectionWidgets.add(pw.SizedBox(height: 3));
        }

        if (isUselessScheme) {
          final rowCount = maxRows;
          final dataColCount = 1 + dataCols;
          final uselessColWidths = <int, pw.TableColumnWidth>{
            0: pw.FixedColumnWidth(srNoWidth),
            for (int i = 1; i < dataColCount; i++)
              i: pw.FixedColumnWidth(dataColWidth),
          };

          pw.Widget tableCell(String text, {bool bold = false}) {
            final isRtl = _containsArabic(text);
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 3,
              ),
              child: pw.Directionality(
                textDirection: isRtl
                    ? pw.TextDirection.rtl
                    : pw.TextDirection.ltr,
                child: pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    text,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: _reportTableFontSize,
                      fontWeight: bold
                          ? pw.FontWeight.bold
                          : pw.FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }

          sectionWidgets.add(
            pw.Row(
              children: [
                ...block.asMap().entries.map((entry) {
                  final index = entry.key;
                  final machinery = entry.value;
                  return _pdfCell(
                    _machineryHeaderLabel(machinery),
                    width: index == 0 ? firstHeaderWidth : otherHeaderWidth,
                    bold: true,
                    align: pw.TextAlign.center,
                  );
                }),
              ],
            ),
          );

          final tableRows = <pw.TableRow>[
            pw.TableRow(
              children: [
                tableCell('Sr.No', bold: true),
                ...block.expand(
                  (_) => [
                    tableCell('Reg. Page No.', bold: true),
                    tableCell('Disabled/Closed', bold: true),
                    tableCell('Submitted To Store', bold: true),
                    tableCell('Transfer Date', bold: true),
                    tableCell('Transferred To Scheme', bold: true),
                    tableCell('Remarks', bold: true),
                  ],
                ),
              ],
            ),
          ];

          for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
            final rowHasEntry = block.any((machinery) {
              final machineryEntries =
                  entriesByMachinery[machinery.machineryId!] ?? [];
              return rowIndex < machineryEntries.length;
            });
            tableRows.add(
              pw.TableRow(
                children: [
                  tableCell(rowHasEntry ? '${rowIndex + 1}' : ''),
                  ...block.expand((machinery) {
                    final mEntries =
                        entriesByMachinery[machinery.machineryId!] ?? [];
                    final entry = rowIndex < mEntries.length
                        ? mEntries[rowIndex]
                        : null;
                    return [
                      tableCell(entry?.regPageNo ?? ''),
                      tableCell(
                        entry == null
                            ? ''
                            : (entry.isDisabled ? 'Yes' : 'Active'),
                      ),
                      tableCell(entry?.submittedToStoreDate ?? ''),
                      tableCell(entry?.transferDate ?? ''),
                      tableCell(entry?.transferredToScheme ?? ''),
                      tableCell(entry?.remarks ?? entry?.notes ?? ''),
                    ];
                  }),
                ],
              ),
            );
          }

          sectionWidgets.add(
            pw.Table(
              columnWidths: uselessColWidths,
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              children: tableRows,
            ),
          );
          sectionWidgets.add(pw.SizedBox(height: 2));
          continue;
        }

        sectionWidgets.add(
          _machineryRegisterTable(
            machinery: block,
            entriesByMachinery: entriesByMachinery,
            startRow: 0,
            rowCount: maxRows,
            tableWidth: tableWidth,
          ),
        );

        sectionWidgets.add(pw.SizedBox(height: 2));
      }

      sectionWidgets.add(pw.SizedBox(height: 2));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              scheme.schemeName,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  isUselessScheme
                      ? 'Useless Items Transfer Summary'
                      : 'Scheme Summary Report',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Date: ${_nowFormatted()}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
          ],
        ),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => sectionWidgets,
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> exportAllMachineryToPdf({
    bool includeSpecs = false,
    String? headerText,
  }) async {
    await _ensureFontsLoaded();
    final schemes = await _schemesDao.getAllSchemes();
    final pdf = pw.Document(theme: _pdfTheme());
    final reports = <_CompleteSchemeReport>[];

    for (final scheme in schemes) {
      final schemeId = scheme.schemeId;
      if (schemeId == null) continue;
      final setReports = <_CompleteSetReport>[];
      final breakdown = <String, Map<String, int>>{};

      for (final set in await _setsDao.getSetsForScheme(schemeId)) {
        final setId = set.setId;
        if (setId == null) continue;
        final machinery = await _machineryDao.getMachineryForSet(setId);
        final entries = await _entriesDao.getEntriesForSet(setId);
        final entriesByMachinery = <int, List<BillingEntry>>{};

        for (final item in machinery) {
          final itemId = item.machineryId;
          if (itemId == null) continue;
          final itemEntries =
              entries.where((entry) => entry.machineryId == itemId).toList()
                ..sort((a, b) => a.serialNo.compareTo(b.serialNo));
          entriesByMachinery[itemId] = itemEntries;

          final type = _normalizeType(item.machineryType);
          final specification = _extractSpecLabel(item);
          final typeBreakdown = breakdown.putIfAbsent(
            type,
            () => <String, int>{},
          );
          typeBreakdown[specification] =
              (typeBreakdown[specification] ?? 0) + 1;
        }

        setReports.add(
          _CompleteSetReport(
            set: set,
            machinery: machinery,
            entriesByMachinery: entriesByMachinery,
          ),
        );
      }

      reports.add(
        _CompleteSchemeReport(
          scheme: scheme,
          sets: setReports,
          breakdown: breakdown,
        ),
      );
    }

    String breakdownText(_CompleteSchemeReport report, String type) {
      final values = report.breakdown[type];
      if (values == null || values.isEmpty) return '-';
      final labels = values.keys.toList()..sort();
      return labels.map((label) => '$label × ${values[label]}').join(', ');
    }

    final detailPages = <_CompleteDetailPage>[];
    final firstPageByScheme = <int, int>{};
    const maxMachineryPerPage = 3;
    final firstRowsPerPage = includeSpecs ? 10 : 14;
    const continuedRowsPerPage = 16;

    for (final report in reports) {
      firstPageByScheme[report.scheme.schemeId!] = detailPages.length + 3;
      if (report.sets.isEmpty) {
        detailPages.add(
          _CompleteDetailPage(schemeReport: report, setReport: null),
        );
        continue;
      }

      for (final setReport in report.sets) {
        if (setReport.machinery.isEmpty) {
          detailPages.add(
            _CompleteDetailPage(
              schemeReport: report,
              setReport: setReport,
              showSetInformation: true,
            ),
          );
          continue;
        }

        for (
          int machineryStart = 0;
          machineryStart < setReport.machinery.length;
          machineryStart += maxMachineryPerPage
        ) {
          final machineryEnd = math.min(
            machineryStart + maxMachineryPerPage,
            setReport.machinery.length,
          );
          final block = setReport.machinery.sublist(
            machineryStart,
            machineryEnd,
          );
          int existingRows = 0;
          for (final item in block) {
            existingRows = math.max(
              existingRows,
              setReport.entriesByMachinery[item.machineryId]?.length ?? 0,
            );
          }

          int rowStart = 0;
          bool firstChunk = true;
          do {
            final pageCapacity = firstChunk
                ? firstRowsPerPage
                : continuedRowsPerPage;
            detailPages.add(
              _CompleteDetailPage(
                schemeReport: report,
                setReport: setReport,
                machinery: block,
                rowStart: rowStart,
                rowEnd: rowStart + pageCapacity,
                continued: machineryStart > 0 || rowStart > 0,
                showSetInformation: machineryStart == 0 && rowStart == 0,
                showSpecifications: includeSpecs && rowStart == 0,
              ),
            );
            rowStart += pageCapacity;
            firstChunk = false;
          } while (rowStart < existingRows);
        }
      }
    }

    pw.Widget pageFooter(pw.Context context) => pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text(
        'Page ${context.pageNumber}',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );

    pw.Widget pageLayout(pw.Context context, pw.Widget content) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(child: content),
        pw.SizedBox(height: 2),
        pageFooter(context),
      ],
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pageLayout(
          context,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Index',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: const ['Sr. No.', 'Scheme Name', 'Page No.'],
                data: reports.asMap().entries.map((entry) {
                  final report = entry.value;
                  return [
                    '${entry.key + 1}',
                    report.scheme.schemeName,
                    'Page ${firstPageByScheme[report.scheme.schemeId] ?? '-'}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerDecoration: const pw.BoxDecoration(),
                headerAlignment: pw.Alignment.center,
                cellAlignments: const {
                  0: pw.Alignment.center,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 5,
                ),
                columnWidths: const {
                  0: pw.FixedColumnWidth(58),
                  1: pw.FlexColumnWidth(),
                  2: pw.FixedColumnWidth(75),
                },
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.6),
              ),
              if (reports.isEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 20),
                  child: pw.Text(
                    'No schemes found.',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(22),
        build: (context) => pageLayout(
          context,
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Overall Machinery Summary',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 17,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Scheme Name',
                  'Total Sets',
                  'Total Machinery',
                  'Motor Details',
                  'Pump Details',
                  'Transformer Details',
                  'Turbine Details',
                ],
                data: reports
                    .map(
                      (report) => [
                        report.scheme.schemeName,
                        '${report.sets.length}',
                        '${report.machineryCount}',
                        breakdownText(report, 'Motor'),
                        breakdownText(report, 'Pump'),
                        breakdownText(report, 'Transformer'),
                        breakdownText(report, 'Turbine'),
                      ],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  fontSize: _reportTableHeaderFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: _reportTableFontSize),
                headerDecoration: const pw.BoxDecoration(),
                headerAlignment: pw.Alignment.center,
                cellAlignments: const {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                },
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 3,
                  vertical: 5,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.6),
                  1: pw.FlexColumnWidth(0.65),
                  2: pw.FlexColumnWidth(0.85),
                  3: pw.FlexColumnWidth(1.2),
                  4: pw.FlexColumnWidth(1.1),
                  5: pw.FlexColumnWidth(1.35),
                  6: pw.FlexColumnWidth(1.05),
                },
                border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
              ),
            ],
          ),
        ),
      ),
    );

    for (final detail in detailPages) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(18, 14, 18, 14),
          build: (context) {
            final report = detail.schemeReport;
            final setReport = detail.setReport;
            final children = <pw.Widget>[
              pw.Text(
                report.scheme.schemeName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
            ];

            if (setReport == null) {
              children.add(
                pw.Text(
                  'No sets found.',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              );
            } else {
              children.add(
                pw.Text(
                  detail.continued
                      ? '${setReport.set.setLabel} (continued)'
                      : setReport.set.setLabel,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              );
              children.add(pw.SizedBox(height: 5));

              if (detail.showSetInformation) {
                children.add(_setInformationTable(setReport.set));
                children.add(pw.SizedBox(height: 5));
              }

              if (detail.showSpecifications) {
                for (final machinery in detail.machinery) {
                  final specs = machinery.specs.entries
                      .where((entry) => entry.value.trim().isNotEmpty)
                      .toList();
                  if (specs.isEmpty) continue;
                  children.add(
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.black,
                          width: 0.45,
                        ),
                      ),
                      child: pw.RichText(
                        text: pw.TextSpan(
                          children: [
                            pw.TextSpan(
                              text:
                                  '${_normalizeType(machinery.machineryType)} Specifications - ${_machineryHeaderLabel(machinery)}\n',
                              style: pw.TextStyle(
                                fontSize: _reportTableHeaderFontSize,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.TextSpan(
                              text: specs
                                  .map(
                                    (entry) => '${entry.key}: ${entry.value}',
                                  )
                                  .join(' | '),
                              style: const pw.TextStyle(
                                fontSize: _reportTableFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                  children.add(pw.SizedBox(height: 2));
                }
                children.add(pw.SizedBox(height: 2));
              }

              if (detail.machinery.isEmpty) {
                children.add(
                  pw.Text(
                    'No machinery data.',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                );
              } else {
                final tableWidth = PdfPageFormat.a4.landscape.width - 36;
                children.add(
                  _machineryRegisterTable(
                    machinery: detail.machinery,
                    entriesByMachinery: setReport.entriesByMachinery,
                    startRow: detail.rowStart,
                    rowCount: detail.rowEnd - detail.rowStart,
                    tableWidth: tableWidth,
                    dataRowHeight: detail.showSpecifications ? 25 : 27,
                  ),
                );
              }
            }

            return pageLayout(
              context,
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: children,
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  Future<String> savePdf(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String> savePdfToDownloads(Uint8List bytes, String filename) async {
    final downloadsDir = await getDownloadsDirectory();
    final targetDir = downloadsDir ?? await getApplicationDocumentsDirectory();
    final file = File('${targetDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ─────────────────── Excel Export ───────────────────

  Future<String> exportSchemeToExcel(int schemeId) async {
    final scheme = await _schemesDao.getSchemeById(schemeId);
    if (scheme == null) throw Exception('Scheme not found');
    final isUselessScheme = scheme.category.toLowerCase() == 'useless_item';

    final sets = await _setsDao.getSetsForScheme(schemeId);
    final excel = xl.Excel.createExcel();

    final sheetName = scheme.schemeName.length > 31
        ? scheme.schemeName.substring(0, 31)
        : scheme.schemeName;
    final sheet = excel[sheetName];

    int colOffset = 0;
    for (final setModel in sets) {
      final machineryList = await _machineryDao.getMachineryForSet(
        setModel.setId!,
      );

      // Row 0: Set header
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: colOffset, rowIndex: 0),
          )
          .value = xl.TextCellValue(
        '${scheme.schemeName} ${setModel.setLabel}',
      );

      int machColOffset = colOffset;
      for (final machinery in machineryList) {
        // Row 1: Machinery label
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(
                columnIndex: machColOffset,
                rowIndex: 1,
              ),
            )
            .value = xl.TextCellValue(
          machinery.displayLabel,
        );

        final headers = isUselessScheme
            ? [
                'Sr.No',
                'Date',
                'Reg. Page No.',
                'Disabled/Closed',
                'Submitted To Store Date',
                'Transfer Date',
                'Transferred To Scheme',
                'Remarks',
              ]
            : [
                'Sr.No',
                'Date',
                'W.O. No.',
                'Voucher No.',
                'Amount',
                'Reg. Page No.',
              ];
        for (int h = 0; h < headers.length; h++) {
          final cell = sheet.cell(
            xl.CellIndex.indexByColumnRow(
              columnIndex: machColOffset + h,
              rowIndex: 2,
            ),
          );
          cell.value = xl.TextCellValue(headers[h]);
          cell.cellStyle = xl.CellStyle(
            bold: true,
            backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
            fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
          );
        }

        // Data rows
        final entries = await _entriesDao.getEntriesForMachinery(
          machinery.machineryId!,
        );
        for (int i = 0; i < entries.length; i++) {
          final e = entries[i];
          if (isUselessScheme) {
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.IntCellValue(
              e.serialNo,
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 1,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.entryDate,
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 2,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.regPageNo ?? '',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 3,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.isDisabled ? 'Yes' : 'No',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 4,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.submittedToStoreDate ?? '',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 5,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.transferDate ?? '',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 6,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.transferredToScheme ?? '',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 7,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.remarks ?? e.notes ?? '',
            );
          } else {
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.IntCellValue(
              e.serialNo,
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 1,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.entryDate,
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 2,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.workOrderNo ?? '',
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 3,
                    rowIndex: 3 + i,
                  ),
                )
                .value = e.voucherNo != null
                ? xl.IntCellValue(e.voucherNo!)
                : xl.TextCellValue('');
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 4,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.DoubleCellValue(
              e.amount,
            );
            sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(
                    columnIndex: machColOffset + 5,
                    rowIndex: 3 + i,
                  ),
                )
                .value = xl.TextCellValue(
              e.regPageNo ?? '',
            );
          }
        }

        machColOffset += headers.length + 1;
      }
      colOffset = machColOffset + 1; // gap between sets
    }

    // Remove default Sheet1 if exists
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${scheme.schemeName.replaceAll(RegExp(r'[^\w\s]'), '_')}_Export.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  Future<String> exportSetToExcel(int setId) async {
    final setModel = await _setsDao.getSetById(setId);
    if (setModel == null) throw Exception('Set not found');

    final scheme = await _schemesDao.getSchemeById(setModel.schemeId);
    final isUselessScheme =
        (scheme?.category ?? '').toLowerCase() == 'useless_item';
    final excel = xl.Excel.createExcel();
    final baseName = '${scheme?.schemeName ?? 'Scheme'} ${setModel.setLabel}';
    final sheetName = baseName.length > 31
        ? baseName.substring(0, 31)
        : baseName;
    final sheet = excel[sheetName];

    final machineryList = await _machineryDao.getMachineryForSet(setId);
    int machColOffset = 0;
    for (final machinery in machineryList) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(
              columnIndex: machColOffset,
              rowIndex: 0,
            ),
          )
          .value = xl.TextCellValue(
        baseName,
      );

      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(
              columnIndex: machColOffset,
              rowIndex: 1,
            ),
          )
          .value = xl.TextCellValue(
        machinery.displayLabel,
      );

      final headers = isUselessScheme
          ? [
              'Sr.No',
              'Date',
              'Reg. Page No.',
              'Disabled/Closed',
              'Submitted To Store Date',
              'Transfer Date',
              'Transferred To Scheme',
              'Remarks',
            ]
          : [
              'Sr.No',
              'Date',
              'W.O. No.',
              'Voucher No.',
              'Amount',
              'Reg. Page No.',
            ];
      for (int h = 0; h < headers.length; h++) {
        final cell = sheet.cell(
          xl.CellIndex.indexByColumnRow(
            columnIndex: machColOffset + h,
            rowIndex: 2,
          ),
        );
        cell.value = xl.TextCellValue(headers[h]);
        cell.cellStyle = xl.CellStyle(
          bold: true,
          backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
          fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
        );
      }

      final entries = await _entriesDao.getEntriesForMachinery(
        machinery.machineryId!,
      );
      for (int i = 0; i < entries.length; i++) {
        final e = entries[i];
        if (isUselessScheme) {
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.IntCellValue(
            e.serialNo,
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 1,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.entryDate,
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 2,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.regPageNo ?? '',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 3,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.isDisabled ? 'Yes' : 'No',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 4,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.submittedToStoreDate ?? '',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 5,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.transferDate ?? '',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 6,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.transferredToScheme ?? '',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 7,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.remarks ?? e.notes ?? '',
          );
        } else {
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.IntCellValue(
            e.serialNo,
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 1,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.entryDate,
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 2,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.workOrderNo ?? '',
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 3,
                  rowIndex: 3 + i,
                ),
              )
              .value = e.voucherNo != null
              ? xl.IntCellValue(e.voucherNo!)
              : xl.TextCellValue('');
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 4,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.DoubleCellValue(
            e.amount,
          );
          sheet
              .cell(
                xl.CellIndex.indexByColumnRow(
                  columnIndex: machColOffset + 5,
                  rowIndex: 3 + i,
                ),
              )
              .value = xl.TextCellValue(
            e.regPageNo ?? '',
          );
        }
      }

      machColOffset += headers.length + 1;
    }

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${baseName.replaceAll(RegExp(r'[^\\w\\s]'), '_')}_Export.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  Future<String> exportSingleMachineryToExcel(
    int setId,
    int machineryId,
  ) async {
    final setModel = await _setsDao.getSetById(setId);
    if (setModel == null) throw Exception('Set not found');

    final scheme = await _schemesDao.getSchemeById(setModel.schemeId);
    final isUselessScheme =
        (scheme?.category ?? '').toLowerCase() == 'useless_item';
    final machineryList = await _machineryDao.getMachineryForSet(setId);
    final machinery = machineryList
        .where((m) => m.machineryId == machineryId)
        .firstOrNull;
    if (machinery == null) throw Exception('Selected machinery not found');

    final excel = xl.Excel.createExcel();
    final baseName = '${scheme?.schemeName ?? 'Scheme'} ${setModel.setLabel}';
    final sheetName = baseName.length > 31
        ? baseName.substring(0, 31)
        : baseName;
    final sheet = excel[sheetName];

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
        .value = xl.TextCellValue(
      baseName,
    );

    sheet
        .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
        .value = xl.TextCellValue(
      machinery.displayLabel,
    );

    final headers = isUselessScheme
        ? [
            'Sr.No',
            'Date',
            'Reg. Page No.',
            'Disabled/Closed',
            'Submitted To Store Date',
            'Transfer Date',
            'Transferred To Scheme',
            'Remarks',
          ]
        : [
            'Sr.No',
            'Date',
            'W.O. No.',
            'Voucher No.',
            'Amount',
            'Reg. Page No.',
          ];
    for (int h = 0; h < headers.length; h++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: h, rowIndex: 2),
      );
      cell.value = xl.TextCellValue(headers[h]);
      cell.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    final entries = await _entriesDao.getEntriesForMachinery(
      machinery.machineryId!,
    );
    for (int i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (isUselessScheme) {
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i),
            )
            .value = xl.IntCellValue(
          e.serialNo,
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.entryDate,
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.regPageNo ?? '',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.isDisabled ? 'Yes' : 'No',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.submittedToStoreDate ?? '',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.transferDate ?? '',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.transferredToScheme ?? '',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.remarks ?? e.notes ?? '',
        );
      } else {
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3 + i),
            )
            .value = xl.IntCellValue(
          e.serialNo,
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.entryDate,
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.workOrderNo ?? '',
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 3 + i),
            )
            .value = e.voucherNo != null
            ? xl.IntCellValue(e.voucherNo!)
            : xl.TextCellValue('');
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 3 + i),
            )
            .value = xl.DoubleCellValue(
          e.amount,
        );
        sheet
            .cell(
              xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: 3 + i),
            )
            .value = xl.TextCellValue(
          e.regPageNo ?? '',
        );
      }
    }

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${baseName.replaceAll(RegExp(r'[^\\w\\s]'), '_')}_${machinery.machineryType}_Export.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  // ─────────────────── CSV Export ───────────────────

  Future<String> exportSchemeToCsv(int schemeId) async {
    final scheme = await _schemesDao.getSchemeById(schemeId);
    if (scheme == null) throw Exception('Scheme not found');
    final isUselessScheme = scheme.category.toLowerCase() == 'useless_item';

    final sets = await _setsDao.getSetsForScheme(schemeId);

    final buffer = StringBuffer();
    // BOM for Excel UTF-8 compatibility
    buffer.write('\uFEFF');
    if (isUselessScheme) {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Reg. Page No.,Disabled/Closed,Submitted To Store Date,Transfer Date,Transferred To Scheme,Remarks',
      );
    } else {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,W.O. No.,Voucher No.,Amount,Reg. Page No.,Notes',
      );
    }

    for (final setModel in sets) {
      final machineryList = await _machineryDao.getMachineryForSet(
        setModel.setId!,
      );

      for (final machinery in machineryList) {
        final entries = await _entriesDao.getEntriesForMachinery(
          machinery.machineryId!,
        );

        for (final e in entries) {
          if (isUselessScheme) {
            buffer.writeln(
              '"${scheme.schemeName}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.regPageNo ?? ''}","${e.isDisabled ? 'Yes' : 'No'}","${e.submittedToStoreDate ?? ''}","${e.transferDate ?? ''}","${e.transferredToScheme ?? ''}","${e.remarks ?? e.notes ?? ''}"',
            );
          } else {
            buffer.writeln(
              '"${scheme.schemeName}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.workOrderNo ?? ''}",${e.voucherNo ?? ''},${e.amount},"${e.regPageNo ?? ''}","${e.notes ?? ''}"',
            );
          }
        }
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${scheme.schemeName.replaceAll(RegExp(r'[^\w\s]'), '_')}_Export.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportSetToCsv(int setId) async {
    final setModel = await _setsDao.getSetById(setId);
    if (setModel == null) throw Exception('Set not found');
    final scheme = await _schemesDao.getSchemeById(setModel.schemeId);
    final isUselessScheme =
        (scheme?.category ?? '').toLowerCase() == 'useless_item';
    final machineryList = await _machineryDao.getMachineryForSet(setId);

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    if (isUselessScheme) {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Reg. Page No.,Disabled/Closed,Submitted To Store Date,Transfer Date,Transferred To Scheme,Remarks',
      );
    } else {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,W.O. No.,Voucher No.,Amount,Reg. Page No.,Notes',
      );
    }

    for (final machinery in machineryList) {
      final entries = await _entriesDao.getEntriesForMachinery(
        machinery.machineryId!,
      );
      for (final e in entries) {
        if (isUselessScheme) {
          buffer.writeln(
            '"${scheme?.schemeName ?? ''}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.regPageNo ?? ''}","${e.isDisabled ? 'Yes' : 'No'}","${e.submittedToStoreDate ?? ''}","${e.transferDate ?? ''}","${e.transferredToScheme ?? ''}","${e.remarks ?? e.notes ?? ''}"',
          );
        } else {
          buffer.writeln(
            '"${scheme?.schemeName ?? ''}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.workOrderNo ?? ''}",${e.voucherNo ?? ''},${e.amount},"${e.regPageNo ?? ''}","${e.notes ?? ''}"',
          );
        }
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${'${scheme?.schemeName ?? 'Scheme'} ${setModel.setLabel}'.replaceAll(RegExp(r'[^\\w\\s]'), '_')}_Export.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> exportSingleMachineryToCsv(int setId, int machineryId) async {
    final setModel = await _setsDao.getSetById(setId);
    if (setModel == null) throw Exception('Set not found');
    final scheme = await _schemesDao.getSchemeById(setModel.schemeId);
    final isUselessScheme =
        (scheme?.category ?? '').toLowerCase() == 'useless_item';

    final machineryList = await _machineryDao.getMachineryForSet(setId);
    final machinery = machineryList
        .where((m) => m.machineryId == machineryId)
        .firstOrNull;
    if (machinery == null) throw Exception('Selected machinery not found');

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    if (isUselessScheme) {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Reg. Page No.,Disabled/Closed,Submitted To Store Date,Transfer Date,Transferred To Scheme,Remarks',
      );
    } else {
      buffer.writeln(
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,W.O. No.,Voucher No.,Amount,Reg. Page No.,Notes',
      );
    }

    final entries = await _entriesDao.getEntriesForMachinery(
      machinery.machineryId!,
    );
    for (final e in entries) {
      if (isUselessScheme) {
        buffer.writeln(
          '"${scheme?.schemeName ?? ''}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.regPageNo ?? ''}","${e.isDisabled ? 'Yes' : 'No'}","${e.submittedToStoreDate ?? ''}","${e.transferDate ?? ''}","${e.transferredToScheme ?? ''}","${e.remarks ?? e.notes ?? ''}"',
        );
      } else {
        buffer.writeln(
          '"${scheme?.schemeName ?? ''}","${setModel.setLabel}","${machinery.machineryType}","${machinery.displayLabel}",${e.serialNo},"${e.entryDate}","${e.workOrderNo ?? ''}",${e.voucherNo ?? ''},${e.amount},"${e.regPageNo ?? ''}","${e.notes ?? ''}"',
        );
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename =
        '${'${scheme?.schemeName ?? 'Scheme'} ${setModel.setLabel}'.replaceAll(RegExp(r'[^\\w\\s]'), '_')}_${machinery.machineryType}_Export.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // ─────────────────── Miscellaneous Export ───────────────────

  Future<List<_MiscRecordExport>> _loadMiscRecords({
    String? recordId,
    int? schemeId,
    int? setId,
  }) async {
    final rawRecords = await _miscDao.getAllRecords(
      schemeId: schemeId,
      setId: setId,
    );
    final all = rawRecords
        .map((e) => _MiscRecordExport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (recordId == null || recordId.trim().isEmpty) return all;
    return all.where((r) => r.id == recordId).toList();
  }

  Future<Uint8List> exportMiscellaneousToPdf({
    String? recordId,
    int? schemeId,
    int? setId,
  }) async {
    await _ensureFontsLoaded();
    final records = await _loadMiscRecords(
      recordId: recordId,
      schemeId: schemeId,
      setId: setId,
    );
    if (records.isEmpty) {
      throw Exception('No miscellaneous data found to export');
    }

    final pdf = pw.Document(theme: _pdfTheme());
    final totalEntries = records.fold<int>(
      0,
      (sum, r) => sum + r.entries.length,
    );
    final totalAmount = records.fold<double>(
      0,
      (sum, r) => sum + r.totalAmount,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(18),
        footer: (context) => pw.Container(
          width: double.infinity,
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Miscellaneous Expenditure Report',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated on ${_nowFormatted()}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Total Items: ${records.length} | Total Entries: $totalEntries | Total Amount: ${_formatAmount(totalAmount)}',
            style: const pw.TextStyle(fontSize: 12),
          ),
          pw.SizedBox(height: 12),
          ...records.map((record) {
            final rows = record.entries
                .asMap()
                .entries
                .map(
                  (entry) => [
                    '${entry.key + 1}',
                    entry.value.entryDate,
                    entry.value.workOrderNo ?? '-',
                    entry.value.voucherNo ?? '-',
                    _formatAmount(entry.value.amount),
                    entry.value.regPageNo ?? '-',
                  ],
                )
                .toList();
            rows.addAll(
              List.generate(
                _manualWritingRows,
                (_) => List<String>.filled(6, ''),
              ),
            );

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(),
                  child: pw.Text(
                    '${record.title} (${record.category}) | Scheme: ${record.schemeName ?? 'Unassigned'} | Set: ${record.setLabel ?? 'Unassigned'} | Entries: ${record.entries.length} | Total: ${_formatAmount(record.totalAmount)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                    fontSize: _reportTableHeaderFontSize,
                    fontFallback: _fontFallback ?? [],
                  ),
                  headerDecoration: const pw.BoxDecoration(),
                  cellStyle: pw.TextStyle(
                    fontSize: _reportTableFontSize,
                    fontFallback: _fontFallback ?? [],
                  ),
                  cellAlignment: pw.Alignment.center,
                  headerAlignment: pw.Alignment.center,
                  headers: const [
                    'Sr.No',
                    'Date',
                    'W.O. No.',
                    'Voucher No.',
                    'Amount (PKR)',
                    'Reg. Page No.',
                  ],
                  data: rows,
                ),
                pw.SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );

    return pdf.save();
  }

  Future<String> exportMiscellaneousToExcel({
    String? recordId,
    int? schemeId,
    int? setId,
  }) async {
    final records = await _loadMiscRecords(
      recordId: recordId,
      schemeId: schemeId,
      setId: setId,
    );
    if (records.isEmpty) {
      throw Exception('No miscellaneous data found to export');
    }

    final excel = xl.Excel.createExcel();
    final sheet = excel['Miscellaneous'];
    final headers = [
      'Title',
      'Category',
      'Sr.No',
      'Date',
      'W.O. No.',
      'Voucher No.',
      'Amount (PKR)',
      'Reg. Page No.',
      'Scheme',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        xl.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = xl.TextCellValue(headers[i]);
      cell.cellStyle = xl.CellStyle(
        bold: true,
        backgroundColorHex: xl.ExcelColor.fromHexString('#1E3A5F'),
        fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
      );
    }

    int row = 1;
    for (final record in records) {
      if (record.entries.isEmpty) {
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = xl.TextCellValue(
          record.title,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = xl.TextCellValue(
          record.category,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = xl.TextCellValue(
          record.schemeName ?? 'Unassigned',
        );
        row++;
        continue;
      }

      for (int i = 0; i < record.entries.length; i++) {
        final e = record.entries[i];
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
            .value = xl.TextCellValue(
          record.title,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
            .value = xl.TextCellValue(
          record.category,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
            .value = xl.IntCellValue(
          i + 1,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
            .value = xl.TextCellValue(
          e.entryDate,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
            .value = xl.TextCellValue(
          e.workOrderNo ?? '',
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
            .value = xl.TextCellValue(
          e.voucherNo ?? '',
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = xl.DoubleCellValue(
          e.amount,
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
            .value = xl.TextCellValue(
          e.regPageNo ?? '',
        );
        sheet
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
            .value = xl.TextCellValue(
          record.schemeName ?? 'Unassigned',
        );
        row++;
      }
    }

    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'Miscellaneous_Export.xlsx';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(excel.encode()!);
    return file.path;
  }

  Future<String> exportMiscellaneousToCsv({
    String? recordId,
    int? schemeId,
    int? setId,
  }) async {
    final records = await _loadMiscRecords(
      recordId: recordId,
      schemeId: schemeId,
      setId: setId,
    );
    if (records.isEmpty) {
      throw Exception('No miscellaneous data found to export');
    }

    final buffer = StringBuffer();
    buffer.write('\uFEFF');
    buffer.writeln(
      'Title,Category,Sr.No,Date,W.O. No.,Voucher No.,Amount (PKR),Reg. Page No.,Scheme',
    );

    for (final record in records) {
      if (record.entries.isEmpty) {
        buffer.writeln(
          '"${record.title}","${record.category}",,,,,,,"${record.schemeName ?? 'Unassigned'}"',
        );
        continue;
      }

      for (int i = 0; i < record.entries.length; i++) {
        final e = record.entries[i];
        buffer.writeln(
          '"${record.title}","${record.category}",${i + 1},"${e.entryDate}","${e.workOrderNo ?? ''}","${e.voucherNo ?? ''}",${e.amount},"${e.regPageNo ?? ''}","${record.schemeName ?? 'Unassigned'}"',
        );
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final filename = 'Miscellaneous_Export.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(buffer.toString());
    return file.path;
  }
}

class _MachineryTemplate {
  final String type;
  final String label;

  _MachineryTemplate({required this.type, required this.label});
}

class _MiscRecordExport {
  final String id;
  final String title;
  final String category;
  final String? schemeName;
  final String? setLabel;
  final List<_MiscEntryExport> entries;

  _MiscRecordExport({
    required this.id,
    required this.title,
    required this.category,
    this.schemeName,
    this.setLabel,
    required this.entries,
  });

  double get totalAmount => entries.fold<double>(0, (sum, e) => sum + e.amount);

  factory _MiscRecordExport.fromJson(Map<String, dynamic> json) {
    return _MiscRecordExport(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'Miscellaneous').toString(),
      schemeName: json['schemeName']?.toString(),
      setLabel: json['setLabel']?.toString(),
      entries: (json['entries'] is List)
          ? (json['entries'] as List)
                .whereType<Map>()
                .map(
                  (e) =>
                      _MiscEntryExport.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : <_MiscEntryExport>[],
    );
  }
}

class _MiscEntryExport {
  final String entryDate;
  final String? workOrderNo;
  final String? voucherNo;
  final double amount;
  final String? regPageNo;

  _MiscEntryExport({
    required this.entryDate,
    this.workOrderNo,
    this.voucherNo,
    required this.amount,
    this.regPageNo,
  });

  factory _MiscEntryExport.fromJson(Map<String, dynamic> json) {
    return _MiscEntryExport(
      entryDate: (json['entryDate'] ?? '').toString(),
      workOrderNo: json['workOrderNo']?.toString(),
      voucherNo: json['voucherNo']?.toString(),
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      regPageNo: json['regPageNo']?.toString(),
    );
  }
}
