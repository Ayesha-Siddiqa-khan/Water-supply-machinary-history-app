import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/machinery_dao.dart';
import '../../core/database/daos/billing_entries_dao.dart';
import '../../core/models/set_model.dart';
import '../../core/models/scheme.dart';
import '../../core/models/machinery.dart';
import '../../core/models/billing_entry.dart';
import '../../core/models/equipment_specs.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_utils.dart';
import '../entries/billing_entry_form.dart';
import '../entries/useless_entry_form.dart';
import '../machinery/machinery_form.dart';
import '../machinery/specs_editor_dialog.dart';
import 'set_form.dart';
import '../../core/services/export_service.dart';

class SetDetailScreen extends StatefulWidget {
  final int setId;

  const SetDetailScreen({super.key, required this.setId});

  @override
  State<SetDetailScreen> createState() => _SetDetailScreenState();
}

class _SetDetailScreenState extends State<SetDetailScreen> {
  final _setsDao = SetsDao();
  final _schemesDao = SchemesDao();
  final _machineryDao = MachineryDao();
  final _entriesDao = BillingEntriesDao();

  SetModel? _set;
  Scheme? _scheme;
  List<_MachineryWithEntries> _machineryList = [];
  bool _isLoading = true;

  bool get _isUselessItemFlow => (_scheme?.category ?? '').toLowerCase() == 'useless_item';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final set = await _setsDao.getSetById(widget.setId);
      if (set == null) {
        if (mounted) Navigator.pop(context);
        return;
      }

      final scheme = await _schemesDao.getSchemeById(set.schemeId);
      final machineryList = await _machineryDao.getMachineryForSet(widget.setId);

      final List<_MachineryWithEntries> machWithEntries = [];
      for (final m in machineryList) {
        final entries = await _entriesDao.getEntriesForMachinery(m.machineryId!);
        machWithEntries.add(_MachineryWithEntries(machinery: m, entries: entries));
      }

      if (mounted) {
        setState(() {
          _set = set;
          _scheme = scheme;
          _machineryList = machWithEntries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _printReport() async {
    if (_set == null) return;
    final isUseless = _isUselessItemFlow;
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUseless) ...[
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Print Useless Items Register'),
                subtitle: const Text('Professional landscape register with all item details'),
                onTap: () => Navigator.pop(ctx, 'register'),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.print),
              title: const Text('Print without Specifications'),
              subtitle: const Text('Equipment info and billing entries only'),
              onTap: () => Navigator.pop(ctx, 'basic'),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Print with Full Specifications'),
              subtitle: const Text('Includes specification tables for every equipment'),
              onTap: () => Navigator.pop(ctx, 'specs'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted || _set == null) return;

    final savedHeader = await ExportService.loadHeaderText();
    final headerText = await ExportService.showHeaderEditDialog(
      context,
      currentHeader: savedHeader,
    );
    if (!mounted) return;
    final effectiveHeader = (headerText != null && headerText.isNotEmpty) ? headerText : savedHeader;

    Uint8List? bytes;
    String pdfName;
    try {
      if (result == 'register' && _scheme != null) {
        final setsDao = SetsDao();
        final sets = await setsDao.getSetsForScheme(_set!.schemeId);
        final machineryBySetId = <int, List<Machinery>>{};
        final entriesByMachineryId = <int, List<BillingEntry>>{};
        for (final set in sets) {
          final machineryList = await _machineryDao.getMachineryForSet(set.setId!);
          machineryBySetId[set.setId!] = machineryList;
          for (final m in machineryList) {
            entriesByMachineryId[m.machineryId!] =
                await _entriesDao.getEntriesForMachinery(m.machineryId!);
          }
        }
        bytes = await ExportService().buildUselessItemsRegister(
          scheme: _scheme!,
          sets: sets,
          machineryBySetId: machineryBySetId,
          entriesByMachineryId: entriesByMachineryId,
          headerText: effectiveHeader,
        );
        pdfName = '${_scheme!.schemeName}_Useless_Items_Register.pdf'
            .replaceAll(RegExp(r'[^\w\s]'), '_');
      } else {
        bytes = await ExportService().buildSetDetailReport(
          set: _set!,
          scheme: _scheme,
          machineryList: [for (final mw in _machineryList) mw.machinery],
          entriesByMachineryId: {
            for (final mw in _machineryList) mw.machinery.machineryId!: mw.entries,
          },
          includeSpecs: result == 'specs',
          headerText: effectiveHeader,
        );
        final baseName =
            '${_scheme?.schemeName ?? 'Scheme'} ${_set!.setLabel}'.replaceAll(RegExp(r'[^\w\s]'), '_');
        pdfName = '${baseName}_Report.pdf';
      }
      if (!mounted) return;

      if (headerText != null && headerText.isNotEmpty) {
        await ExportService.saveHeaderText(headerText);
      }

      if (Platform.isAndroid || Platform.isIOS) {
        await Printing.sharePdf(bytes: bytes, filename: pdfName);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes!, name: pdfName);
      }
    } catch (e) {
      if (!mounted) return;
      try {
        if (bytes == null) throw e;
        final dir = await getApplicationDocumentsDirectory();
        final baseName = '${_scheme?.schemeName ?? 'Scheme'} ${_set!.setLabel}'
            .replaceAll(RegExp(r'[^\w\s]'), '_');
        final file = File('${dir.path}/${baseName}_Report.pdf');
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open print dialog. PDF saved to: ${file.path}')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error generating report: $e')),
          );
        }
      }
    }
  }

  Future<void> _editSetDetails() async {
    final result = await SpecsEditorDialog.show(
      context,
      title: '${_set!.setLabel} Information',
      fields: setDetailFields,
      values: _set!.details,
    );
    if (result == null || !mounted) return;
    final merged = mergeSpecValues(_set!.details, setDetailFields, result);

    await _setsDao.updateSet(_set!.copyWith(details: merged));
    _loadData();
  }

  Future<void> _editSet() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SetForm(
            schemeId: _set!.schemeId,
            nextSetNumber: _set!.setNumber,
            set: _set,
          ),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _editMachinerySpecs(Machinery machinery) async {
    final fields = specFieldsFor(machinery.machineryType);

    // Same-type equipment with saved specs, offered as "copy from" sources.
    Map<String, Map<String, String>> copyTemplates = {};
    try {
      copyTemplates = buildCopyTemplates(
        machinery.machineryType,
        await _machineryDao.getAllMachineryWithStats(),
        excludeId: machinery.machineryId,
      );
    } catch (_) {}
    if (!mounted) return;

    final result = await SpecsEditorDialog.show(
      context,
      title: '${machinery.displayLabel} Specifications',
      fields: fields,
      values: machinery.specs,
      machineryType: machinery.machineryType,
      copyTemplates: copyTemplates,
    );
    if (result == null || !mounted) return;
    final merged = mergeSpecValues(machinery.specs, fields, result);

    await _machineryDao.updateMachinery(machinery.copyWith(specs: merged));
    _loadData();
  }

  Future<void> _addMachinery() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: MachineryForm(setId: widget.setId),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteMachinery(Machinery machinery) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Machinery'),
        content: Text('Delete "${machinery.displayLabel}" and all its billing entries?'),
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
    if (confirmed == true) {
      await _machineryDao.deleteMachinery(machinery.machineryId!);
      _loadData();
    }
  }

  Future<void> _addEntry(int machineryId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _isUselessItemFlow
              ? UselessEntryForm(machineryId: machineryId)
              : BillingEntryForm(machineryId: machineryId),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _editEntry(BillingEntry entry) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: _isUselessItemFlow
              ? UselessEntryForm(machineryId: entry.machineryId, entry: entry)
              : BillingEntryForm(machineryId: entry.machineryId, entry: entry),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteEntry(BillingEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete entry #${entry.serialNo} (${CurrencyUtils.formatAmount(entry.amount)})?'),
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
    if (confirmed == true) {
      await _entriesDao.deleteEntry(entry.entryId!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(_set?.setLabel ?? 'Set Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editSet,
            tooltip: 'Edit Set',
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _printReport,
            tooltip: 'Print Report',
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: _addMachinery, tooltip: 'Add Machinery'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _machineryList.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.precision_manufacturing_outlined,
                                  size: 64, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text('No machinery yet',
                                  style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              Text('Add a machinery sub-head to start',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _addMachinery,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Machinery'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Breadcrumb
                        if (_scheme != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '${_scheme!.schemeName} > ${_set!.setLabel}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),

                        // Set header with total
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: isCompact
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _set!.setLabel,
                                              style: Theme.of(context).textTheme.titleLarge,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: _editSet,
                                            icon: const Icon(Icons.edit_outlined),
                                            tooltip: 'Edit Set',
                                          ),
                                        ],
                                      ),
                                      if (_scheme != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${_scheme!.schemeName} ${_set!.setLabel.replaceFirst('Set No. ', 'Set No.')}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Text(
                                        'Total: ${CurrencyUtils.formatAmount(_set!.totalAmount)}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${_machineryList.length} machinery',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_set!.setLabel,
                                                style: Theme.of(context).textTheme.titleLarge),
                                            if (_scheme != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                '${_scheme!.schemeName} ${_set!.setLabel.replaceFirst('Set No. ', 'Set No.')}',
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              'Total: ${CurrencyUtils.formatAmount(_set!.totalAmount)}',
                                              style: const TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                       ),
                                      IconButton(
                                        onPressed: _editSet,
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit Set',
                                      ),
                                      Text(
                                        '${_machineryList.length} machinery',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Set information (location, electricity bill, company)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Set Information',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      tooltip: 'Edit Set Information',
                                      onPressed: _editSetDetails,
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _SpecRows(
                                    specs: _set!.details,
                                    emptyHint:
                                        'No set information yet. Add location / GPS, electricity bill reference numbers and distribution company details.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Machinery sections
                        ..._machineryList.map((mw) => _buildMachinerySection(mw)),

                        const SizedBox(height: 80),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addMachinery,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMachinerySection(_MachineryWithEntries mw) {
    final machinery = mw.machinery;
    final entries = mw.entries;
    final totalAmount = entries.fold(0.0, (sum, e) => sum + e.amount);
    final isUseless = _isUselessItemFlow;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: _getMachineryIcon(machinery.machineryType),
        title: Text(
          machinery.displayLabel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${entries.length} entries · Total: ${CurrencyUtils.formatAmount(totalAmount)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'add_entry') _addEntry(machinery.machineryId!);
            if (value == 'delete') _deleteMachinery(machinery);
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'add_entry', child: Text('Add Entry')),
            const PopupMenuItem(value: 'delete', child: Text('Delete Machinery')),
          ],
        ),
        children: [
          // Detailed specifications for this equipment
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fact_check_outlined,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${machinery.machineryType} Specifications',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      tooltip: 'Copy Specifications',
                      onPressed: () {
                        if (machinery.specs.values.every((v) => v.trim().isEmpty)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No specifications to copy on this equipment')),
                          );
                          return;
                        }
                        SpecClipboard.copy(machinery.machineryType, machinery.specs);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Specifications copied. Open another ${machinery.machineryType} and tap Paste Specifications.',
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Edit Specifications',
                      onPressed: () => _editMachinerySpecs(machinery),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _SpecTable(
                    specs: machinery.specs,
                    emptyHint:
                        'No specifications added yet. Tap the edit icon to enter detailed ${machinery.machineryType.toLowerCase()} information.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No billing entries yet.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.05)),
                columns: [
                  DataColumn(label: Text('Sr.No', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (!isUseless)
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (!isUseless)
                    DataColumn(label: Text('Work Order No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (!isUseless)
                    DataColumn(label: Text('Voucher No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (!isUseless)
                    DataColumn(
                      label: Text('Amount (PKR)', style: TextStyle(fontWeight: FontWeight.bold)),
                      numeric: true,
                    ),
                  DataColumn(label: Text('Reg. Page No.', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (isUseless)
                    DataColumn(label: Text('Disabled/Closed', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (isUseless)
                    DataColumn(label: Text('Submitted To Store', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (isUseless)
                    DataColumn(label: Text('Transfer Date', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (isUseless)
                    DataColumn(label: Text('Transferred To Scheme', style: TextStyle(fontWeight: FontWeight.bold))),
                  if (isUseless)
                    DataColumn(label: Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: entries.map((e) => DataRow(
                  cells: [
                    DataCell(Text('${e.serialNo}')),
                    if (!isUseless) DataCell(Text(e.entryDate)),
                    if (!isUseless) DataCell(Text(e.workOrderNo ?? '-')),
                    if (!isUseless) DataCell(Text(e.voucherNo?.toString() ?? '-')),
                    if (!isUseless) DataCell(Text(CurrencyUtils.formatAmount(e.amount))),
                    DataCell(Text(e.regPageNo ?? '-')),
                    if (isUseless) DataCell(Text(e.isDisabled ? 'Yes' : 'No')),
                    if (isUseless) DataCell(Text(e.submittedToStoreDate ?? '-')),
                    if (isUseless) DataCell(Text(e.transferDate ?? '-')),
                    if (isUseless) DataCell(Text(e.transferredToScheme ?? '-')),
                    if (isUseless) DataCell(Text(e.remarks ?? e.notes ?? '-')),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                          onPressed: () => _editEntry(e),
                          tooltip: 'Edit',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 18, color: AppColors.error),
                          onPressed: () => _deleteEntry(e),
                          tooltip: 'Delete',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )),
                  ],
                )).toList(),
              ),
            ),
          // Add Entry button at bottom
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () => _addEntry(machinery.machineryId!),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Entry'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getMachineryIcon(String type) {
    IconData icon;
    Color color;
    switch (type.toLowerCase()) {
      case 'motor':
        icon = Icons.electric_bolt;
        color = Colors.blue;
        break;
      case 'pump':
        icon = Icons.water;
        color = Colors.teal;
        break;
      case 'transformer':
        icon = Icons.transform;
        color = Colors.orange;
        break;
      case 'electrical items':
        icon = Icons.electrical_services;
        color = Colors.deepPurple;
        break;
      case 'turbine':
        icon = Icons.wind_power;
        color = Colors.green;
        break;
      default:
        icon = Icons.precision_manufacturing;
        color = AppColors.primary;
    }
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _MachineryWithEntries {
  final Machinery machinery;
  final List<BillingEntry> entries;

  _MachineryWithEntries({required this.machinery, required this.entries});
}

/// Label/value table for spec sheets; shows only non-empty values.
class _SpecRows extends StatelessWidget {
  final Map<String, String> specs;
  final String emptyHint;

  const _SpecRows({required this.specs, required this.emptyHint});

  @override
  Widget build(BuildContext context) {
    final filled = specs.entries.where((e) => e.value.trim().isNotEmpty).toList();
    if (filled.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(emptyHint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    return Table(
      columnWidths: const {0: IntrinsicColumnWidth()},
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        for (final e in filled)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6, right: 16),
                child: Text(
                  e.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(e.value, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
      ],
    );
  }
}

/// Horizontal spec sheet: header row holds the spec names, one data row holds
/// the values — one row per equipment instead of a long vertical list.
/// Scrolls horizontally on narrow screens, like the entries table.
class _SpecTable extends StatelessWidget {
  final Map<String, String> specs;
  final String emptyHint;

  const _SpecTable({required this.specs, required this.emptyHint});

  @override
  Widget build(BuildContext context) {
    final filled = specs.entries.where((e) => e.value.trim().isNotEmpty).toList();
    if (filled.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(emptyHint, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      );
    }
    const cellPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 6);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: AppColors.textHint.withOpacity(0.4), width: 0.5),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {for (int i = 0; i < filled.length; i++) i: const IntrinsicColumnWidth()},
        children: [
          TableRow(
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05)),
            children: [
              for (final e in filled)
                Padding(
                  padding: cellPadding,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(
                      e.key,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          TableRow(
            children: [
              for (final e in filled)
                Padding(
                  padding: cellPadding,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Text(e.value, style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
