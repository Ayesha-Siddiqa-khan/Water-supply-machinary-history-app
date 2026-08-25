import 'package:flutter/material.dart';
import '../../core/services/import_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_utils.dart';

class ImportPreviewScreen extends StatefulWidget {
  final List<ParsedScheme> parsedSchemes;
  final String fileName;

  const ImportPreviewScreen({
    super.key,
    required this.parsedSchemes,
    required this.fileName,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  bool _isImporting = false;
  ImportResult? _result;
  String _schemeName = '';

  Map<String, _MachineryValidationSummary> get _machineryValidationSummary {
    final summary = <String, _MachineryValidationSummary>{};

    for (final scheme in widget.parsedSchemes) {
      for (final set in scheme.sets) {
        for (final machinery in set.machineryList) {
          final key = machinery.displayLabel;
          final current =
              summary[key] ?? const _MachineryValidationSummary(machineryCount: 0, entryCount: 0, totalAmount: 0);
          final entries = machinery.entries.length;
          final amount =
              machinery.entries.fold<double>(0.0, (sum, e) => sum + e.amount);

          summary[key] = _MachineryValidationSummary(
            machineryCount: current.machineryCount + 1,
            entryCount: current.entryCount + entries,
            totalAmount: current.totalAmount + amount,
          );
        }
      }
    }

    final sortedKeys = summary.keys.toList()..sort();
    return {for (final key in sortedKeys) key: summary[key]!};
  }

  @override
  void initState() {
    super.initState();
    if (widget.parsedSchemes.length == 1) {
      _schemeName = widget.parsedSchemes.first.schemeName;
    }
  }

  int get _totalSets =>
      widget.parsedSchemes.fold(0, (sum, s) => sum + s.sets.length);
  int get _totalMachinery => widget.parsedSchemes.fold(
      0, (sum, s) => sum + s.sets.fold(0, (s2, set) => s2 + set.machineryList.length));
  int get _totalEntries => widget.parsedSchemes.fold(
      0,
      (sum, s) =>
          sum +
          s.sets.fold(
              0,
              (s2, set) =>
                  s2 +
                  set.machineryList.fold(0, (s3, m) => s3 + m.entries.length)));
  double get _totalAmount => widget.parsedSchemes.fold(
      0.0,
      (sum, s) =>
          sum +
          s.sets.fold(
              0.0,
              (s2, set) =>
                  s2 +
                  set.machineryList.fold(
                      0.0,
                      (s3, m) =>
                          s3 + m.entries.fold(0.0, (s4, e) => s4 + e.amount))));

  Future<void> _commitImport() async {
    setState(() => _isImporting = true);

    try {
      final importService = ImportService();
      // Update scheme name only for single-scheme imports
      if (widget.parsedSchemes.length == 1 && _schemeName.trim().isNotEmpty) {
        widget.parsedSchemes.first.schemeName = _schemeName.trim();
      }
      final result = await importService.commitImport(widget.parsedSchemes);

      if (mounted) {
        setState(() {
          _result = result;
          _isImporting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _buildResultView();
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Preview')),
      body: ListView(
        padding: EdgeInsets.all(isCompact ? 12 : 16),
        children: [
          // File info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.description, color: AppColors.primary),
                        const SizedBox(height: 8),
                        Text(widget.fileName, style: Theme.of(context).textTheme.titleMedium),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.description, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(widget.fileName,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Scheme name editable for single-scheme imports only
          if (widget.parsedSchemes.length == 1)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Scheme Name',
                border: OutlineInputBorder(),
                helperText: 'You can change the scheme name before importing',
              ),
              controller: TextEditingController(text: _schemeName),
              onChanged: (v) => _schemeName = v,
            )
          else
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Multiple schemes detected. Scheme names will be imported from sheet names.',
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Summary
          Card(
            color: AppColors.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _summaryRow('Sets', _totalSets.toString(), compact: isCompact),
                  _summaryRow('Machinery', _totalMachinery.toString(), compact: isCompact),
                  _summaryRow('Billing Entries', _totalEntries.toString(), compact: isCompact),
                  _summaryRow('Total Amount', CurrencyUtils.formatAmount(_totalAmount),
                      compact: isCompact),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Validation by machinery
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Validation by Machinery',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  ..._machineryValidationSummary.entries.map((entry) {
                    final value = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            '${value.machineryCount} machinery · ${value.entryCount} entries · ${CurrencyUtils.formatAmount(value.totalAmount)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sets & Machinery preview
          Text('Data Preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          ...widget.parsedSchemes.expand((scheme) => scheme.sets.map((set) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    title: Text(set.setLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${set.machineryList.length} machinery'),
                    children: set.machineryList.map((m) {
                      final mTotal =
                          m.entries.fold(0.0, (sum, e) => sum + e.amount);
                      return ExpansionTile(
                        title: Text('  ${m.displayLabel}'),
                        subtitle: Text(
                            '  ${m.entries.length} entries · ${CurrencyUtils.formatAmount(mTotal)}'),
                        children: [
                          if (m.entries.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columnSpacing: 16,
                                columns: const [
                                  DataColumn(label: Text('Sr.No')),
                                  DataColumn(label: Text('Date')),
                                  DataColumn(label: Text('Voucher')),
                                  DataColumn(label: Text('Amount'), numeric: true),
                                  DataColumn(label: Text('Reg.')),
                                ],
                                rows: m.entries
                                    .take(10) // Show first 10 entries
                                    .map((e) => DataRow(cells: [
                                          DataCell(Text('${e.serialNo}')),
                                          DataCell(Text(e.date)),
                                          DataCell(Text(e.voucherNo?.toString() ?? '-')),
                                          DataCell(Text(CurrencyUtils.formatAmount(e.amount))),
                                          DataCell(Text(e.regPageNo ?? '-')),
                                        ]))
                                    .toList(),
                              ),
                            ),
                          if (m.entries.length > 10)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '...and ${m.entries.length - 10} more entries',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                );
              })),

          const SizedBox(height: 24),

          // Import button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isImporting ? null : _commitImport,
              icon: _isImporting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download),
              label: Text(_isImporting ? 'Importing...' : 'Import All Data'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    final r = _result!;
    final hasErrors = r.errors.isNotEmpty;
    final isCompact = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('Import Complete')),
      body: ListView(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        children: [
          Icon(
            hasErrors ? Icons.warning : Icons.check_circle,
            size: 80,
            color: hasErrors ? AppColors.warning : AppColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            hasErrors ? 'Import Completed with Warnings' : 'Import Successful!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _summaryRow('Schemes', r.schemesImported.toString(), compact: isCompact),
                  _summaryRow('Sets', r.setsImported.toString(), compact: isCompact),
                  _summaryRow('Machinery', r.machineryImported.toString(), compact: isCompact),
                  _summaryRow('Entries', r.entriesImported.toString(), compact: isCompact),
                ],
              ),
            ),
          ),
          if (r.warnings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.warning.withOpacity(0.1),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: r.warnings.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${r.warnings[i]}', style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
          if (r.errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.error.withOpacity(0.1),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: r.errors.length,
                itemBuilder: (ctx, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${r.errors[i]}',
                      style: const TextStyle(fontSize: 13, color: AppColors.error)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                // Pop back to root
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool compact = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
    );
  }
}

class _MachineryValidationSummary {
  final int machineryCount;
  final int entryCount;
  final double totalAmount;

  const _MachineryValidationSummary({
    required this.machineryCount,
    required this.entryCount,
    required this.totalAmount,
  });
}
