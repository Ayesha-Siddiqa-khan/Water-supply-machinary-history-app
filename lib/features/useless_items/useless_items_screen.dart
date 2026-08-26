import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';

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
    if (widget.schemeId == null) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              subtitle: const Text('Professional A4 register for this scheme'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
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
    if (widget.schemeId == null) return;

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
      final effectiveHeader = (headerText != null && headerText.isNotEmpty) ? headerText : savedHeader;

      final sets = await setsDao.getSetsForScheme(widget.schemeId!);
      final machineryBySetId = <int, List<Machinery>>{};
      final entriesByMachineryId = <int, List<BillingEntry>>{};

      for (final set in sets) {
        final machineryList = await machineryDao.getMachineryForSet(set.setId!);
        machineryBySetId[set.setId!] = machineryList;
        for (final m in machineryList) {
          entriesByMachineryId[m.machineryId!] =
              await entriesDao.getEntriesForMachinery(m.machineryId!);
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

      final baseName = '${scheme.schemeName}_Useless_Items_Register'
          .replaceAll(RegExp(r'[^\w\s]'), '_');
      final pdfName = '$baseName.pdf';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Excel saved to: $filePath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting: $e')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV saved to: $filePath')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SchemesListScreen(
      title: widget.setLabel != null
          ? 'Useless Items — ${widget.setLabel}'
          : widget.schemeName == null
          ? l10n.navUselessItems
          : 'Useless Items — ${widget.schemeName}',
      schemeCategory: 'useless_item',
      emptyStateTitle: l10n.uselessEmptyTitle,
      emptyStateSubtitle: l10n.uselessEmptySubtitle,
      addButtonLabel: l10n.uselessAddButton,
      parentSchemeId: widget.schemeId,
      parentSetId: widget.setId,
      appBarActions: [
        if (widget.schemeId != null)
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _showExportOptions,
            tooltip: 'Print / Export',
          ),
      ],
    );
  }
}
