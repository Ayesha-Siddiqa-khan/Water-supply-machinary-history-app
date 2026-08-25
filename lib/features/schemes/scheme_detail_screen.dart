import 'package:flutter/material.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_utils.dart';
import '../sets/set_detail_screen.dart';
import '../sets/set_form.dart';
import '../export/export_screen.dart';

class SchemeDetailScreen extends StatefulWidget {
  final int schemeId;

  const SchemeDetailScreen({super.key, required this.schemeId});

  @override
  State<SchemeDetailScreen> createState() => _SchemeDetailScreenState();
}

class _SchemeDetailScreenState extends State<SchemeDetailScreen> {
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();

  Scheme? _scheme;
  List<SetModel> _sets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final scheme = await _schemesDao.getSchemeById(widget.schemeId);
      final sets = await _setsDao.getSetsForScheme(widget.schemeId);
      if (mounted) {
        setState(() {
          _scheme = scheme;
          _sets = sets;
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

  Future<void> _addSet() async {
    final nextNum = await _setsDao.getNextSetNumber(widget.schemeId);
    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SetForm(schemeId: widget.schemeId, nextSetNumber: nextNum),
        ),
      ),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteSet(SetModel set) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Set'),
        content: Text('Delete "${set.setLabel}" and all its machinery and entries?'),
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
      await _setsDao.deleteSet(set.setId!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(_scheme?.schemeName ?? 'Scheme Detail'),
        actions: [
          if (_scheme != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'export_pdf') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExportScreen(schemeId: widget.schemeId),
                    ),
                  );
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'export_pdf', child: Text('Export')),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _sets.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.settings_outlined, size: 64, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text('No sets yet', style: Theme.of(context).textTheme.headlineSmall),
                              const SizedBox(height: 8),
                              Text('Add a set to start recording entries',
                                  style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _addSet,
                                icon: const Icon(Icons.add),
                                label: const Text('Add Set'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Scheme summary header
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: isCompact
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.water_drop,
                                                color: AppColors.primary, size: 28),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(_scheme!.schemeName,
                                                style: Theme.of(context).textTheme.titleLarge,
                                                overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Total: ${CurrencyUtils.formatAmount(_scheme!.totalAmount)}',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.water_drop,
                                            color: AppColors.primary, size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(_scheme!.schemeName,
                                                style: Theme.of(context).textTheme.titleLarge),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Total: ${CurrencyUtils.formatAmount(_scheme!.totalAmount)}',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Sets list
                        Text('Sets (${_sets.length})',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),

                        ..._sets.map((set) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SetDetailScreen(setId: set.setId!),
                                    ),
                                  );
                                  _loadData();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: isCompact
                                      ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor: AppColors.accent.withOpacity(0.15),
                                                  child: Text(
                                                    '${set.setNumber}',
                                                    style: const TextStyle(
                                                      color: AppColors.accent,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(set.setLabel,
                                                      style: Theme.of(context).textTheme.titleMedium,
                                                      overflow: TextOverflow.ellipsis),
                                                ),
                                                GestureDetector(
                                                  onTap: () => _deleteSet(set),
                                                  child: const Icon(Icons.delete_outline,
                                                      size: 20, color: AppColors.error),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 6,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.precision_manufacturing,
                                                        size: 14, color: AppColors.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Text('${set.machineryCount} machinery',
                                                        style: Theme.of(context).textTheme.bodySmall),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.receipt,
                                                        size: 14, color: AppColors.textSecondary),
                                                    const SizedBox(width: 4),
                                                    Text('${set.entryCount} entries',
                                                        style: Theme.of(context).textTheme.bodySmall),
                                                  ],
                                                ),
                                                Text(
                                                  CurrencyUtils.formatAmount(set.totalAmount),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        )
                                      : Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: AppColors.accent.withOpacity(0.15),
                                              child: Text(
                                                '${set.setNumber}',
                                                style: const TextStyle(
                                                  color: AppColors.accent,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(set.setLabel,
                                                      style: Theme.of(context).textTheme.titleMedium),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      Icon(Icons.precision_manufacturing,
                                                          size: 14, color: AppColors.textSecondary),
                                                      const SizedBox(width: 4),
                                                      Text('${set.machineryCount} machinery',
                                                          style: Theme.of(context).textTheme.bodySmall),
                                                      const SizedBox(width: 12),
                                                      Icon(Icons.receipt,
                                                          size: 14, color: AppColors.textSecondary),
                                                      const SizedBox(width: 4),
                                                      Text('${set.entryCount} entries',
                                                          style: Theme.of(context).textTheme.bodySmall),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  CurrencyUtils.formatAmount(set.totalAmount),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () => _deleteSet(set),
                                                  child: const Icon(Icons.delete_outline,
                                                      size: 20, color: AppColors.error),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            )),

                        const SizedBox(height: 80),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSet,
        child: const Icon(Icons.add),
      ),
    );
  }
}
