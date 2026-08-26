import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/database/daos/machinery_dao.dart';
import '../../core/database/daos/billing_entries_dao.dart';
import '../../core/models/machinery.dart';
import '../../core/models/billing_entry.dart';
import '../../core/services/export_service.dart';
import '../schemes/schemes_list_screen.dart';

class UselessItemsScreen extends StatefulWidget {
  final int? schemeId;
  final String? schemeName;
  final int? setId;
  final String? setLabel;

  const UselessItemsScreen({
    super.key,
    this.schemeId,
    this.schemeName,
    this.setId,
    this.setLabel,
  });

  @override
  State<UselessItemsScreen> createState() => _UselessItemsScreenState();
}

class _UselessItemsScreenState extends State<UselessItemsScreen> {
  Future<void> _showExportOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: Text(
                widget.schemeId == null
                    ? 'Print Complete Store Register'
                    : 'Export as PDF',
              ),
              subtitle: Text(
                widget.schemeId == null
                    ? 'All damaged and unusable items in one register'
                    : 'Professional A4 register for this record',
              ),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            if (widget.schemeId != null) ...[
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Export as Excel'),
                subtitle: const Text('Spreadsheet format for data entry'),
                onTap: () => Navigator.pop(ctx, 'excel'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Export as CSV'),
                subtitle: const Text('Plain text comma-separated values'),
                onTap: () => Navigator.pop(ctx, 'csv'),
              ),
            ],
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    if (result == 'pdf') {
      await _exportPdf();
    } else if (result == 'excel') {
      await _exportExcel();
    } else if (result == 'csv') {
      await _exportCsv();
    }
  }

  Future<void> _exportPdf() async {
    if (widget.schemeId == null) {
      try {
        final savedHeader = await ExportService.loadHeaderText();
        final headerText = await ExportService.showHeaderEditDialog(
          context,
          currentHeader: savedHeader,
        );
        if (!mounted) return;
        final effectiveHeader = (headerText != null && headerText.isNotEmpty)
            ? headerText
            : savedHeader;

        final bytes = await ExportService().exportAllUselessItemsRegister(
          headerText: effectiveHeader,
        );
        if (!mounted) return;

        if (headerText != null && headerText.isNotEmpty) {
          await ExportService.saveHeaderText(headerText);
        }

        const pdfName = 'Useless_Items_Store_Register.pdf';
        if (Platform.isAndroid || Platform.isIOS) {
          await Printing.sharePdf(bytes: bytes, filename: pdfName);
        } else {
          await Printing.layoutPdf(onLayout: (_) async => bytes, name: pdfName);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating register: $e')),
        );
      }
      return;
    }

    final schemesDao = SchemesDao();
    final setsDao = SetsDao();
    final machineryDao = MachineryDao();
    final entriesDao = BillingEntriesDao();

    try {
      final scheme = await schemesDao.getSchemeById(widget.schemeId!);
      if (scheme == null || !mounted) return;

      final savedHeader = await ExportService.loadHeaderText();
      final headerText = await ExportService.showHeaderEditDialog(
        context,
        currentHeader: savedHeader,
      );
      if (!mounted) return;
      final effectiveHeader = (headerText != null && headerText.isNotEmpty)
          ? headerText
          : savedHeader;

      final sets = await setsDao.getSetsForScheme(widget.schemeId!);
      final machineryBySetId = <int, List<Machinery>>{};
      final entriesByMachineryId = <int, List<BillingEntry>>{};

      for (final set in sets) {
        final machineryList = await machineryDao.getMachineryForSet(set.setId!);
        machineryBySetId[set.setId!] = machineryList;
        for (final m in machineryList) {
          entriesByMachineryId[m.machineryId!] = await entriesDao
              .getEntriesForMachinery(m.machineryId!);
        }
      }

      final bytes = await ExportService().buildUselessItemsRegister(
        scheme: scheme,
        sets: sets,
        machineryBySetId: machineryBySetId,
        entriesByMachineryId: entriesByMachineryId,
        headerText: effectiveHeader,
      );

      if (!mounted) return;

      if (headerText != null && headerText.isNotEmpty) {
        await ExportService.saveHeaderText(headerText);
      }

      final baseName = '${scheme.schemeName}_Useless_Items_Register'.replaceAll(
        RegExp(r'[^\w\s]'),
        '_',
      );
      final pdfName = '$baseName.pdf';

      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(bytes: bytes, filename: pdfName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: pdfName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error generating register: $e')));
    }
  }

  Future<void> _exportExcel() async {
    if (widget.schemeId == null) return;

    try {
      final filePath = await ExportService().exportSchemeToExcel(
        widget.schemeId!,
      );
      if (!mounted) return;

      final file = File(filePath);
      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(
          bytes: await file.readAsBytes(),
          filename: filePath.split(Platform.pathSeparator).last,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel saved to: $filePath')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting: $e')));
    }
  }

  Future<void> _exportCsv() async {
    if (widget.schemeId == null) return;

    try {
      final filePath = await ExportService().exportSchemeToCsv(
        widget.schemeId!,
      );
      if (!mounted) return;

      final file = File(filePath);
      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(
          bytes: await file.readAsBytes(),
          filename: filePath.split(Platform.pathSeparator).last,
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('CSV saved to: $filePath')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error exporting: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SchemesListScreen(
      title: widget.setLabel != null
          ? 'Useless Items — ${widget.setLabel}'
          : widget.schemeName == null
          ? 'Useless Items Store Register'
          : 'Useless Items — ${widget.schemeName}',
      schemeCategory: 'useless_item',
      emptyStateTitle: 'No store records yet',
      emptyStateSubtitle:
          'Record damaged, unusable, or out-of-service equipment kept in the store.',
      addButtonLabel: 'Add Store Record',
      parentSchemeId: widget.schemeId,
      parentSetId: widget.setId,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.print_outlined),
          onPressed: _showExportOptions,
          tooltip: 'Print / Export Register',
        ),
      ],
    );
  }
}
