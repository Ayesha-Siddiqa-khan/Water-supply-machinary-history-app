import 'package:flutter/material.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/models/scheme.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_utils.dart';
import 'scheme_detail_screen.dart';
import 'scheme_form.dart';

class SchemesListScreen extends StatefulWidget {
  final String title;
  final String schemeCategory;
  final String emptyStateTitle;
  final String emptyStateSubtitle;
  final String addButtonLabel;

  const SchemesListScreen({
    super.key,
    this.title = 'Schemes',
    this.schemeCategory = 'scheme',
    this.emptyStateTitle = 'No schemes yet',
    this.emptyStateSubtitle = 'Add a scheme or import from Excel',
    this.addButtonLabel = 'Add Scheme',
  });

  @override
  State<SchemesListScreen> createState() => _SchemesListScreenState();
}

class _SchemesListScreenState extends State<SchemesListScreen> {
  final _schemesDao = SchemesDao();
  List<Scheme> _schemes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchemes();
  }

  Future<void> _loadSchemes() async {
    setState(() => _isLoading = true);
    try {
      final schemes = await _schemesDao.getSchemesByCategory(widget.schemeCategory);
      if (mounted) {
        setState(() {
          _schemes = schemes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.commonErrorPrefix}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _addScheme() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SchemeForm(schemeCategory: widget.schemeCategory),
        ),
      ),
    );
    if (result == true) _loadSchemes();
  }

  Future<void> _editScheme(Scheme scheme) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SchemeForm(scheme: scheme),
        ),
      ),
    );
    if (result == true) _loadSchemes();
  }

  Future<void> _deleteScheme(Scheme scheme) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.schemeDeleteTitle),
        content: Text(
          l10n.schemeDeleteMessage(scheme.schemeName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _schemesDao.deleteScheme(scheme.schemeId!);
      _loadSchemes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.schemeDeletedSuccess)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchemes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schemes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.water_drop_outlined, size: 80, color: AppColors.textHint),
                      const SizedBox(height: 16),
                      Text(
                        widget.emptyStateTitle,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.emptyStateSubtitle,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addScheme,
                        icon: const Icon(Icons.add),
                        label: Text(widget.addButtonLabel),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSchemes,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _schemes.length,
                    itemBuilder: (context, index) {
                      final scheme = _schemes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SchemeDetailScreen(schemeId: scheme.schemeId!),
                              ),
                            );
                            _loadSchemes();
                          },
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
                                            child:
                                                const Icon(Icons.water_drop, color: AppColors.primary),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              scheme.schemeName,
                                              style: Theme.of(context).textTheme.titleLarge,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') _editScheme(scheme);
                                              if (value == 'delete') _deleteScheme(scheme);
                                            },
                                            itemBuilder: (ctx) => [
                                              PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(ctx)!.commonEdit)),
                                              PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(ctx)!.commonDelete)),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          _InfoChip(
                                            icon: Icons.settings,
                                            label: AppLocalizations.of(context)!.schemeSetsCount(scheme.setCount),
                                          ),
                                          _InfoChip(
                                            icon: Icons.payments_outlined,
                                            label: CurrencyUtils.formatAmountShort(scheme.totalAmount),
                                          ),
                                        ],
                                      ),
                                      if (scheme.description != null &&
                                          scheme.description!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            scheme.description!,
                                            style: Theme.of(context).textTheme.bodySmall,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                                        child:
                                            const Icon(Icons.water_drop, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              scheme.schemeName,
                                              style: Theme.of(context).textTheme.titleLarge,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _InfoChip(
                                                  icon: Icons.settings,
                                                  label: AppLocalizations.of(context)!.schemeSetsCount(scheme.setCount),
                                                ),
                                                const SizedBox(width: 12),
                                                _InfoChip(
                                                  icon: Icons.payments_outlined,
                                                  label: CurrencyUtils.formatAmountShort(scheme.totalAmount),
                                                ),
                                              ],
                                            ),
                                            if (scheme.description != null &&
                                                scheme.description!.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  scheme.description!,
                                                  style: Theme.of(context).textTheme.bodySmall,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        onSelected: (value) {
                                          if (value == 'edit') _editScheme(scheme);
                                          if (value == 'delete') _deleteScheme(scheme);
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(ctx)!.commonEdit)),
                                          PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(ctx)!.commonDelete)),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _schemes.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addScheme,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
