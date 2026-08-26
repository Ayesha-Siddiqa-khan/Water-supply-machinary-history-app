import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
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
import '../models/machinery.dart';
import '../models/set_model.dart';
import '../models/scheme.dart';
import '../models/billing_entry.dart';

class ExportService {
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
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Prepared by City Water Works',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
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
              border: pw.Border.all(color: PdfColors.grey400),
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
                  style: const pw.TextStyle(fontSize: 11),
                ),
                pw.Text(
                  'Schemes with Pumps: ${schemeTypeCounts['pump'] ?? 0}',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
              fontFallback: _fontFallback ?? [],
            ),
            headerDecoration: pw.BoxDecoration(color: headerColor),
            cellStyle: pw.TextStyle(
              fontSize: 8,
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
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
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
  }) async {
    return _exportSetToPdfInternal(setId, includeSpecs: includeSpecs);
  }

  Future<Uint8List> exportSingleMachineryToPdf(
    int setId,
    int machineryId,
  ) async {
    final machineryList = await _machineryDao.getMachineryForSet(setId);
    final selected = machineryList
        .where((m) => m.machineryId == machineryId)
        .firstOrNull;
    if (selected == null) {
      throw Exception('Selected machinery not found');
    }
    return _exportSetToPdfInternal(setId, machineryOverride: [selected]);
  }

  Future<Uint8List> _exportSetToPdfInternal(
    int setId, {
    List<Machinery>? machineryOverride,
    bool includeSpecs = false,
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

    final entriesByMachinery = <int, List<dynamic>>{};
    int maxRows = 1;
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
    maxRows = math.max(maxRows, 2);

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
        margin: const pw.EdgeInsets.all(18),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              '${scheme?.schemeName ?? 'Unknown Scheme'} ${setModel.setLabel}',
              textAlign: pw.TextAlign.left,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              _excelStyleSetHeading(
                scheme?.schemeName ?? 'Unknown Scheme',
                setModel.setLabel,
              ),
              textAlign: pw.TextAlign.left,
              style: const pw.TextStyle(fontSize: 10),
            ),
            if (isUselessScheme) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                'Useless Items Transfer Report',
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Prepared by City Water Works',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => [
          if (setInfo.isNotEmpty) ...[
            _compactSetInformation(setInfo),
            pw.SizedBox(height: 6),
          ],
          ...machineryBlocks.asMap().entries.expand((blockEntry) {
            final blockIndex = blockEntry.key;
            final block = blockEntry.value;
            final tableWidth = PdfPageFormat.a4.landscape.width - 36;
            final perMachineryCols = isUselessScheme ? 6 : 4;
            final totalCols = 1 + (block.length * perMachineryCols);
            final colWidth = tableWidth / totalCols;
            final firstHeaderWidth = colWidth * (perMachineryCols + 1);
            final otherHeaderWidth = colWidth * perMachineryCols;

            return <pw.Widget>[
              if (blockIndex > 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                    'Continued',
                    style: pw.TextStyle(
                      fontSize: 9,
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
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _machineryHeaderLabel(machinery),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            specs
                                .map((e) => '${e.key}: ${e.value}')
                                .join(' | '),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 2),
                  ];
                }),
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
                    width: colWidth,
                    bold: true,
                    align: pw.TextAlign.center,
                  ),
                  ...block.expand(
                    (_) => isUselessScheme
                        ? [
                            _pdfCell(
                              'Reg. Page No.',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Disabled/Closed',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Submitted To Store',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Transfer Date',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Transferred To Scheme',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Remarks',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                          ]
                        : [
                            _pdfCell(
                              'Date',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'W.O. No.',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Voucher No.',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                            _pdfCell(
                              'Amount',
                              width: colWidth,
                              bold: true,
                              align: pw.TextAlign.center,
                            ),
                          ],
                  ),
                ],
              ),
              ...List.generate(maxRows, (rowIndex) {
                return pw.Row(
                  children: [
                    _pdfCell(
                      '${rowIndex + 1}',
                      width: colWidth,
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
                            entry?.regPageNo ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            (entry?.isDisabled ?? false) ? 'Yes' : '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.submittedToStoreDate ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.transferDate ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.transferredToScheme ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.remarks ?? entry?.notes ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                        ];
                      }
                      return [
                        _pdfCell(
                          entry?.entryDate ?? '-',
                          width: colWidth,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          entry?.workOrderNo ?? '-',
                          width: colWidth,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          entry?.voucherNo?.toString() ?? '-',
                          width: colWidth,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          entry != null ? _formatAmount(entry.amount) : '-',
                          width: colWidth,
                          align: pw.TextAlign.center,
                        ),
                      ];
                    }),
                  ],
                );
              }),
              pw.SizedBox(height: 8),
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

  pw.Widget _compactSetInformation(
    List<MapEntry<String, String>> entries,
  ) {
    String compactLabel(String label) {
      switch (label.trim().toLowerCase()) {
        case 'location / gps coordinates':
          return 'Location / GPS';
        case 'electricity bill reference no.':
          return 'Bill Ref. No.';
        case 'electricity distribution company':
          return 'Company';
        default:
          return label;
      }
    }

    final details = entries
        .map((entry) => '${compactLabel(entry.key)}: ${entry.value}')
        .join(' | ');

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'Set Information',
            style: pw.TextStyle(
              color: PdfColors.black,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              fontFallback: _fontFallback ?? [],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Text(
              details,
              style: pw.TextStyle(
                color: PdfColors.black,
                fontSize: 7.5,
                fontFallback: _fontFallback ?? [],
              ),
            ),
          ),
        ],
      ),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      decoration: pw.BoxDecoration(
        color: background,
        border: pw.Border.all(width: 0.4, color: PdfColors.black),
      ),
      child: pw.Text(
        text,
        textAlign: effectiveAlign,
        textDirection: hasArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        style: pw.TextStyle(
          fontSize: 9,
          // Use Arabic font as primary when Arabic/Urdu characters are present.
          font: hasArabic ? _arabicFont : (bold ? _boldFont : _baseFont),
          fontBold: _boldFont,
          fontFallback: _fontFallback ?? [],
          color: background != null ? PdfColors.white : PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
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
  }) async {
    await _ensureFontsLoaded();
    final pdf = pw.Document(theme: _pdfTheme());

    final schemeName = scheme?.schemeName ?? '';
    final headerStyle = pw.TextStyle(
      fontSize: 8,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
      fontFallback: _fontFallback ?? [],
    );
    final cellStyle = pw.TextStyle(
      fontSize: 8,
      fontFallback: _fontFallback ?? [],
    );
    final tableBorder = pw.TableBorder.all(
      color: PdfColors.grey600,
      width: 0.5,
    );

    pw.Widget sectionTable(List<String> headers, List<List<String>> rows) {
      return pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: headerStyle,
        headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
        headerAlignment: pw.Alignment.center,
        cellStyle: cellStyle,
        cellAlignment: pw.Alignment.center,
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        border: tableBorder,
      );
    }

    final content = <pw.Widget>[
      pw.Text(
        'Water Supply Scheme History',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '$schemeName - ${set.setLabel}',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 12),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        'Total: ${_formatAmount(set.totalAmount)} | Printed on ${_nowFormatted()}',
        textAlign: pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
    ];

    final setInfo = set.details.entries
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    if (setInfo.isNotEmpty) {
      content.add(_compactSetInformation(setInfo));
      content.add(pw.SizedBox(height: 6));
    }

    for (final machinery in machineryList) {
      final entries = entriesByMachineryId[machinery.machineryId] ?? const [];
      final total = entries.fold<double>(0, (s, e) => s + e.amount);

      content.add(
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: pw.BoxDecoration(color: PdfColors.grey300),
          child: pw.Text(
            '${machinery.displayLabel} (${machinery.machineryType}) | ${entries.length} entries | Total: ${_formatAmount(total)}',
            style: pw.TextStyle(
              color: PdfColors.black,
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      );
      content.add(pw.SizedBox(height: 4));

      if (includeSpecs) {
        final specs = machinery.specs.entries
            .where((e) => e.value.trim().isNotEmpty)
            .toList();
        if (specs.isNotEmpty) {
          content.add(
            sectionTable(
              [for (final e in specs) e.key],
              [
                [for (final e in specs) e.value],
              ],
            ),
          );
          content.add(pw.SizedBox(height: 6));
        }
      }

      if (entries.isEmpty) {
        content.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              'No billing entries yet.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
        );
      } else {
        content.add(
          sectionTable(
            const [
              'Sr.No',
              'Date',
              'W.O. No.',
              'Voucher No.',
              'Amount (PKR)',
              'Reg. Page No.',
            ],
            [
              for (final e in entries)
                [
                  '${e.serialNo}',
                  e.entryDate,
                  e.workOrderNo ?? '-',
                  e.voucherNo?.toString() ?? '-',
                  _formatAmount(e.amount),
                  e.regPageNo ?? '-',
                ],
              ['Total', '', '', '', _formatAmount(total), ''],
            ],
          ),
        );
      }
      content.add(pw.SizedBox(height: 12));
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => content,
      ),
    );

    return pdf.save();
  }

  static bool _containsArabic(String text) {
    // Arabic Unicode block: U+0600–U+06FF (covers Arabic, Urdu, Persian)
    return text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
  }

  Future<Uint8List> exportSchemeToPdf(int schemeId) async {
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

      final entriesByMachinery = <int, List<dynamic>>{};
      int maxRows = 1;
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
      maxRows = isUselessScheme ? math.max(maxRows, 1) : math.max(maxRows, 2);

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
          style: const pw.TextStyle(fontSize: 9),
        ),
      );
      sectionWidgets.add(pw.SizedBox(height: 4));

      if (effectiveMachineryList.isEmpty) {
        sectionWidgets.add(
          pw.Text('No machinery data', style: pw.TextStyle(fontSize: 9)),
        );
        sectionWidgets.add(pw.SizedBox(height: 10));
        continue;
      }

      if (isUselessScheme) {
        const dataColCount = 7;
        final tableWidth = PdfPageFormat.a4.landscape.width - 36;
        final uselessColWidth = tableWidth / dataColCount;

        pw.Widget tableCell(String text, {bool bold = false}) {
          final isRtl = _containsArabic(text);
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                    fontSize: 9,
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
          final rowCount = math.max(mEntries.length, 1);

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
                  tableCell('${rowIndex + 1}'),
                  tableCell(entry?.regPageNo ?? '-'),
                  tableCell((entry?.isDisabled ?? false) ? 'Yes' : '-'),
                  tableCell(entry?.submittedToStoreDate ?? '-'),
                  tableCell(entry?.transferDate ?? '-'),
                  tableCell(entry?.transferredToScheme ?? '-'),
                  tableCell(entry?.remarks ?? entry?.notes ?? '-'),
                ],
              ),
            );
          }

          sectionWidgets.add(
            pw.Table(
              columnWidths: {
                for (int i = 0; i < dataColCount; i++)
                  i: pw.FixedColumnWidth(uselessColWidth),
              },
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
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
        final totalCols = 1 + (block.length * perMachineryCols);
        final colWidth = tableWidth / totalCols;
        final firstHeaderWidth = colWidth * (perMachineryCols + 1);
        final otherHeaderWidth = colWidth * perMachineryCols;

        if (blockIndex > 0) {
          sectionWidgets.add(
            pw.Text(
              '${setModel.setLabel} (continued)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          );
          sectionWidgets.add(pw.SizedBox(height: 3));
        }

        if (isUselessScheme) {
          final rowCount = maxRows;
          final dataColCount = totalCols;
          final uselessColWidth = colWidth;

          pw.Widget _tableCell(String text, {bool bold = false}) {
            final isRtl = _containsArabic(text);
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
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
                      fontSize: 9,
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
                _tableCell('Sr.No', bold: true),
                ...block.expand(
                  (_) => [
                    _tableCell('Reg. Page No.', bold: true),
                    _tableCell('Disabled/Closed', bold: true),
                    _tableCell('Submitted To Store', bold: true),
                    _tableCell('Transfer Date', bold: true),
                    _tableCell('Transferred To Scheme', bold: true),
                    _tableCell('Remarks', bold: true),
                  ],
                ),
              ],
            ),
          ];

          for (int rowIndex = 0; rowIndex < rowCount; rowIndex++) {
            tableRows.add(
              pw.TableRow(
                children: [
                  _tableCell('${rowIndex + 1}'),
                  ...block.expand((machinery) {
                    final mEntries =
                        entriesByMachinery[machinery.machineryId!] ?? [];
                    final entry = rowIndex < mEntries.length
                        ? mEntries[rowIndex]
                        : null;
                    return [
                      _tableCell(entry?.regPageNo ?? '-'),
                      _tableCell((entry?.isDisabled ?? false) ? 'Yes' : '-'),
                      _tableCell(entry?.submittedToStoreDate ?? '-'),
                      _tableCell(entry?.transferDate ?? '-'),
                      _tableCell(entry?.transferredToScheme ?? '-'),
                      _tableCell(entry?.remarks ?? entry?.notes ?? '-'),
                    ];
                  }),
                ],
              ),
            );
          }

          sectionWidgets.add(
            pw.Table(
              columnWidths: {
                for (int i = 0; i < dataColCount; i++)
                  i: pw.FixedColumnWidth(uselessColWidth),
              },
              border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
              children: tableRows,
            ),
          );
          sectionWidgets.add(pw.SizedBox(height: 8));
          continue;
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
        sectionWidgets.add(
          pw.Row(
            children: [
              _pdfCell(
                'Sr.No',
                width: colWidth,
                bold: true,
                align: pw.TextAlign.center,
              ),
              ...block.expand(
                (_) => isUselessScheme
                    ? [
                        _pdfCell(
                          'Reg. Page No.',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Disabled/Closed',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Submitted To Store',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Transfer Date',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Transferred To Scheme',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Remarks',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                      ]
                    : [
                        _pdfCell(
                          'Date',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Work Order No.',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Voucher No.',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Amount',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                      ],
              ),
            ],
          ),
        );

        for (int rowIndex = 0; rowIndex < maxRows; rowIndex++) {
          sectionWidgets.add(
            pw.Row(
              children: [
                _pdfCell(
                  '${rowIndex + 1}',
                  width: colWidth,
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
                        entry?.regPageNo ?? '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        (entry?.isDisabled ?? false) ? 'Yes' : '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        entry?.submittedToStoreDate ?? '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        entry?.transferDate ?? '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        entry?.transferredToScheme ?? '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      _pdfCell(
                        entry?.remarks ?? entry?.notes ?? '-',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                    ];
                  }
                  return [
                    _pdfCell(
                      entry?.entryDate ?? '-',
                      width: colWidth,
                      align: pw.TextAlign.center,
                    ),
                    _pdfCell(
                      entry?.workOrderNo ?? '-',
                      width: colWidth,
                      align: pw.TextAlign.center,
                    ),
                    _pdfCell(
                      entry?.voucherNo?.toString() ?? '-',
                      width: colWidth,
                      align: pw.TextAlign.center,
                    ),
                    _pdfCell(
                      entry != null ? _formatAmount(entry.amount) : '-',
                      width: colWidth,
                      align: pw.TextAlign.center,
                    ),
                  ];
                }),
              ],
            ),
          );
        }

        sectionWidgets.add(pw.SizedBox(height: 8));
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
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Prepared by City Water Works',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
        build: (context) => sectionWidgets,
      ),
    );

    return pdf.save();
  }

  Future<Uint8List> exportAllMachineryToPdf({
    bool includeSpecs = false,
  }) async {
    await _ensureFontsLoaded();
    final schemes = await _schemesDao.getAllSchemes();
    final schemeTypeCounts = await _countSchemesByKeyTypes();
    final allMachinery = await _machineryDao.getAllMachineryWithStats();
    final machineryCountsByType = <String, int>{};
    for (final machinery in allMachinery) {
      final type = _normalizeType(machinery.machineryType);
      machineryCountsByType[type] = (machineryCountsByType[type] ?? 0) + 1;
    }
    final motorCount = machineryCountsByType['Motor'] ?? 0;
    final pumpCount = machineryCountsByType['Pump'] ?? 0;
    final transformerCount = machineryCountsByType['Transformer'] ?? 0;
    final turbineCount = machineryCountsByType['Turbine'] ?? 0;
    final pdf = pw.Document(theme: _pdfTheme());

    if (schemes.isEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(18),
          header: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                'Water Supply Scheme History - Complete Machinery Export',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Total Machinery: Motor $motorCount | Pump $pumpCount | Transformer $transformerCount | Turbine $turbineCount',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.Text(
                'Date: ${_nowFormatted()}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),
            ],
          ),
          footer: (context) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Prepared by City Water Works',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
          build: (context) => [
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 24),
              child: pw.Text(
                'No schemes found.',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      );

      return pdf.save();
    }

    for (int schemeIndex = 0; schemeIndex < schemes.length; schemeIndex++) {
      final scheme = schemes[schemeIndex];
      final schemeId = scheme.schemeId;
      if (schemeId == null) continue;

      final sets = await _setsDao.getSetsForScheme(schemeId);
      final machineryBySet = <int, List<Machinery>>{};
      final summaryByType = <String, Map<String, int>>{};
      final totalByType = <String, int>{};
      int schemeTotalMachinery = 0;

      for (final setModel in sets) {
        final setId = setModel.setId;
        if (setId == null) continue;
        final machineryList = await _machineryDao.getMachineryForSet(setId);
        machineryBySet[setId] = machineryList;

        for (final machinery in machineryList) {
          final type = _normalizeType(machinery.machineryType);
          final spec = _extractSpecLabel(machinery);
          totalByType[type] = (totalByType[type] ?? 0) + 1;
          final typeMap = summaryByType.putIfAbsent(
            type,
            () => <String, int>{},
          );
          typeMap[spec] = (typeMap[spec] ?? 0) + 1;
          schemeTotalMachinery++;
        }
      }

      final schemeSummaryLines = <String>[
        'Total Sets: ${sets.length} | Total Machinery: $schemeTotalMachinery',
      ];

      const preferred = ['Motor', 'Pump', 'Transformer', 'Turbine'];
      final presentTypes = summaryByType.keys.toSet();
      final orderedTypes = <String>[];
      for (final type in preferred) {
        if (presentTypes.contains(type)) orderedTypes.add(type);
      }
      final others = presentTypes.where((t) => !preferred.contains(t)).toList()
        ..sort();
      orderedTypes.addAll(others);

      for (final type in orderedTypes) {
        final specs = summaryByType[type] ?? const <String, int>{};
        final specLabels = specs.keys.toList()..sort();
        final specText = specLabels.isEmpty
            ? '-'
            : specLabels.map((label) => '$label × ${specs[label]}').join(', ');
        schemeSummaryLines.add('$type (${totalByType[type] ?? 0}): $specText');
      }

      if (sets.isEmpty) {
        final emptyWidgets = <pw.Widget>[
          pw.Text(
            scheme.schemeName,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 4),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: schemeSummaryLines
                  .map(
                    (line) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('No sets found.', style: const pw.TextStyle(fontSize: 9)),
        ];

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(18),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'Water Supply Scheme History - Complete Machinery Export',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (schemeIndex == 0 && context.pageNumber == 1)
                  pw.Text(
                    'Total Machinery: Motor $motorCount | Pump $pumpCount | Transformer $transformerCount | Turbine $turbineCount',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.Text(
                  'Scheme: ${scheme.schemeName}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Date: ${_nowFormatted()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Prepared by City Water Works',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
            build: (context) => emptyWidgets,
          ),
        );
        continue;
      }

      for (int setIndex = 0; setIndex < sets.length; setIndex++) {
        final setModel = sets[setIndex];
        final setId = setModel.setId;
        if (setId == null) continue;
        final machineryList = machineryBySet[setId] ?? const <Machinery>[];
        final entries = await _entriesDao.getEntriesForSet(setId);

        final setWidgets = <pw.Widget>[];
        final rowsPerPageWithSummary = includeSpecs ? 10 : 18;
        final rowsPerPage = includeSpecs ? 14 : 22;
        bool firstSetPage = true;

        void addSchemeSummaryBlock() {
          setWidgets.add(
            pw.Text(
              scheme.schemeName,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          );
          setWidgets.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 4),
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: schemeSummaryLines
                    .map(
                      (line) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 2),
                        child: pw.Text(
                          line,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
          setWidgets.add(pw.SizedBox(height: 6));
        }

        void addSetHeader({required bool continued}) {
          final label = continued
              ? '${setModel.setLabel} (continued)'
              : setModel.setLabel;
          setWidgets.add(
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          );
          setWidgets.add(
            pw.Text(
              _excelStyleSetHeading(scheme.schemeName, setModel.setLabel),
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
          setWidgets.add(pw.SizedBox(height: 4));
        }

        if (machineryList.isEmpty) {
          if (setIndex == 0) {
            addSchemeSummaryBlock();
          }
          addSetHeader(continued: false);
          setWidgets.add(
            pw.Text(
              'No machinery data',
              style: const pw.TextStyle(fontSize: 9),
            ),
          );
          setWidgets.add(pw.SizedBox(height: 10));
        } else {
          final entriesByMachinery = <int, List<dynamic>>{};
          int maxRows = 1;
          for (final machinery in machineryList) {
            final machineryEntries =
                entries
                    .where(
                      (entry) => entry.machineryId == machinery.machineryId,
                    )
                    .toList()
                  ..sort((a, b) => a.serialNo.compareTo(b.serialNo));
            entriesByMachinery[machinery.machineryId!] = machineryEntries;
            if (machineryEntries.length > maxRows) {
              maxRows = machineryEntries.length;
            }
          }
          maxRows = math.max(maxRows, 2);

          const maxMachineryPerBlock = 3;
          final machineryBlocks = <List<Machinery>>[];
          for (int i = 0; i < machineryList.length; i += maxMachineryPerBlock) {
            final end = (i + maxMachineryPerBlock) > machineryList.length
                ? machineryList.length
                : (i + maxMachineryPerBlock);
            machineryBlocks.add(machineryList.sublist(i, end));
          }

          for (
            int blockIndex = 0;
            blockIndex < machineryBlocks.length;
            blockIndex++
          ) {
            final block = machineryBlocks[blockIndex];
            final tableWidth = PdfPageFormat.a4.landscape.width - 36;
            final totalCols = 1 + (block.length * 4);
            final colWidth = tableWidth / totalCols;
            final firstHeaderWidth = colWidth * 5;
            final otherHeaderWidth = colWidth * 4;

            for (
              int start = 0;
              start < maxRows;
              start += ((setIndex == 0 && firstSetPage)
                  ? rowsPerPageWithSummary
                  : rowsPerPage)
            ) {
              final chunkSize = (setIndex == 0 && firstSetPage)
                  ? rowsPerPageWithSummary
                  : rowsPerPage;
              final end = math.min(start + chunkSize, maxRows);

              if (!firstSetPage) {
                setWidgets.add(pw.NewPage());
              }

              if (setIndex == 0 && firstSetPage) {
                addSchemeSummaryBlock();
              }

              final isContinued = !(blockIndex == 0 && start == 0);
              addSetHeader(continued: isContinued);

              if (includeSpecs && start == 0) {
                for (final machinery in block) {
                  final specs = machinery.specs.entries
                      .where((entry) => entry.value.trim().isNotEmpty)
                      .toList();
                  if (specs.isEmpty) continue;

                  setWidgets.add(
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: pw.BoxDecoration(color: PdfColors.grey200),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            _machineryHeaderLabel(machinery),
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 8,
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Text(
                            specs
                                .map(
                                  (entry) =>
                                      '${entry.key}: ${entry.value}',
                                )
                                .join(' | '),
                            style: const pw.TextStyle(fontSize: 7),
                          ),
                        ],
                      ),
                    ),
                  );
                  setWidgets.add(pw.SizedBox(height: 2));
                }
                setWidgets.add(pw.SizedBox(height: 2));
              }

              setWidgets.add(
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
              setWidgets.add(
                pw.Row(
                  children: [
                    _pdfCell(
                      'Sr.No',
                      width: colWidth,
                      bold: true,
                      align: pw.TextAlign.center,
                    ),
                    ...block.expand(
                      (_) => [
                        _pdfCell(
                          'Date',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Work Order No.',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Voucher No.',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                        _pdfCell(
                          'Amount',
                          width: colWidth,
                          bold: true,
                          align: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              );

              for (int rowIndex = start; rowIndex < end; rowIndex++) {
                setWidgets.add(
                  pw.Row(
                    children: [
                      _pdfCell(
                        '${rowIndex + 1}',
                        width: colWidth,
                        align: pw.TextAlign.center,
                      ),
                      ...block.expand((machinery) {
                        final mEntries =
                            entriesByMachinery[machinery.machineryId!] ?? [];
                        final entry = rowIndex < mEntries.length
                            ? mEntries[rowIndex]
                            : null;
                        return [
                          _pdfCell(
                            entry?.entryDate ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.workOrderNo ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry?.voucherNo?.toString() ?? '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                          _pdfCell(
                            entry != null ? _formatAmount(entry.amount) : '-',
                            width: colWidth,
                            align: pw.TextAlign.center,
                          ),
                        ];
                      }),
                    ],
                  ),
                );
              }

              setWidgets.add(pw.SizedBox(height: 8));
              firstSetPage = false;
            }
          }
        }

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(18),
            header: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  'Water Supply Scheme History - Complete Machinery Export',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                if (schemeIndex == 0 &&
                    setIndex == 0 &&
                    context.pageNumber == 1)
                  pw.Text(
                    'Total Machinery: Motor $motorCount | Pump $pumpCount | Transformer $transformerCount | Turbine $turbineCount',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                pw.Text(
                  'Scheme: ${scheme.schemeName}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Date: ${_nowFormatted()}',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1),
              ],
            ),
            footer: (context) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Prepared by City Water Works',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ),
            build: (context) => setWidgets,
          ),
        );
      }
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
                'Work Order No.',
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
              'Work Order No.',
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
            'Work Order No.',
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
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Work Order No.,Voucher No.,Amount,Reg. Page No.,Notes',
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
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Work Order No.,Voucher No.,Amount,Reg. Page No.,Notes',
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
        'Scheme,Set,Machinery Type,Specs,Sr.No,Date,Work Order No.,Voucher No.,Amount,Reg. Page No.,Notes',
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
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Prepared by City Water Works',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
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
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 12),
          ...records.map((record) {
            final rows = record.entries.isEmpty
                ? [
                    ['-', '-', '-', '-', '-', '-'],
                  ]
                : record.entries
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

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Text(
                    '${record.title} (${record.category}) | Scheme: ${record.schemeName ?? 'Unassigned'} | Set: ${record.setLabel ?? 'Unassigned'} | Entries: ${record.entries.length} | Total: ${_formatAmount(record.totalAmount)}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    fontSize: 9,
                    fontFallback: _fontFallback ?? [],
                  ),
                  headerDecoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#1E3A5F'),
                  ),
                  cellStyle: pw.TextStyle(
                    fontSize: 8,
                    fontFallback: _fontFallback ?? [],
                  ),
                  cellAlignment: pw.Alignment.center,
                  headerAlignment: pw.Alignment.center,
                  headers: const [
                    'Sr.No',
                    'Date',
                    'Work Order No.',
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
      'Work Order No.',
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
      'Title,Category,Sr.No,Date,Work Order No.,Voucher No.,Amount (PKR),Reg. Page No.,Scheme',
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
