import 'package:flutter/material.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/database/daos/billing_entries_dao.dart';
import '../../core/database/daos/machinery_dao.dart';
import '../../core/models/billing_entry.dart';
import '../../core/models/machinery.dart';
import '../../core/models/scheme.dart';
import '../../core/services/export_service.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/utils/currency_utils.dart';
import 'widgets/summary_card.dart';
import 'widgets/recent_entries_list.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSchemes;
  final VoidCallback? onNavigateToImport;
  final VoidCallback? onNavigateToExport;
  final Function(int)? onNavigateToScheme;

  const DashboardScreen({
    super.key,
    this.onNavigateToSchemes,
    this.onNavigateToImport,
    this.onNavigateToExport,
    this.onNavigateToScheme,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();
  final _entriesDao = BillingEntriesDao();
  final _machineryDao = MachineryDao();
  final _exportService = ExportService();

  int _schemeCount = 0;
  int _setCount = 0;
  int _entriesThisMonth = 0;
  double _amountThisMonth = 0.0;
  List<Scheme> _schemes = [];
  List<BillingEntry> _recentEntries = [];
  List<BillingEntry> _searchResults = [];
  final Map<String, int> _totalByType = {};
  final Map<String, int> _functionalByType = {};
  final Map<String, Map<String, int>> _specCountsByType = {};
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isDownloadingReport = false;
  bool _isDownloadingAllReport = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final schemeCount = await _schemesDao.getSchemeCount();
      final setCount = await _setsDao.getSetCount();
      final entriesThisMonth = await _entriesDao.getEntryCountThisMonth();
      final amountThisMonth = await _entriesDao.getTotalAmountThisMonth();
      final schemes = await _schemesDao.getAllSchemes();
      final recentEntries = await _entriesDao.getRecentEntries(limit: 10);
      final machineryList = await _machineryDao.getAllMachineryWithStats();

      final totalByType = <String, int>{};
      final functionalByType = <String, int>{};
      final specCountsByType = <String, Map<String, int>>{};

      for (final machinery in machineryList) {
        final type = _normalizeType(machinery.machineryType);
        totalByType[type] = (totalByType[type] ?? 0) + 1;
        functionalByType[type] = totalByType[type]!;

        final specLabel = _extractSpecLabel(machinery);
        final typeMap = specCountsByType.putIfAbsent(type, () => <String, int>{});
        typeMap[specLabel] = (typeMap[specLabel] ?? 0) + 1;
      }

      if (mounted) {
        setState(() {
          _schemeCount = schemeCount;
          _setCount = setCount;
          _entriesThisMonth = entriesThisMonth;
          _amountThisMonth = amountThisMonth;
          _schemes = schemes;
          _recentEntries = recentEntries;
          _totalByType
            ..clear()
            ..addAll(totalByType);
          _functionalByType
            ..clear()
            ..addAll(functionalByType);
          _specCountsByType
            ..clear()
            ..addAll(specCountsByType);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.dashboardLoadError}: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
      final kva = specs['kVA Rating'] ?? specs['KVA Rating'] ?? specs['kVA'] ?? specs['KV'];
      if (kva?.trim().isNotEmpty == true) {
        return kva!.trim().replaceAll(RegExp(r'kva', caseSensitive: false), 'Kv');
      }
      return 'Unknown Kv';
    }
    if (type == 'Turbine') {
      return 'Turbine';
    }

    return machinery.displayLabel.trim().isNotEmpty ? machinery.displayLabel.trim() : 'Unspecified';
  }

  List<String> _orderedTypeList() {
    const preferred = ['Motor', 'Pump', 'Transformer', 'Turbine'];
    final existing = _totalByType.keys.toSet();
    final ordered = <String>[];
    for (final type in preferred) {
      if (existing.contains(type)) ordered.add(type);
    }
    final others = existing.where((t) => !preferred.contains(t)).toList()..sort();
    ordered.addAll(others);
    return ordered;
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'Motor':
        return AppColors.primary;
      case 'Pump':
        return AppColors.success;
      case 'Transformer':
        return AppColors.accent;
      case 'Turbine':
        return AppColors.primaryLight;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Motor':
        return Icons.electric_bolt;
      case 'Pump':
        return Icons.water;
      case 'Transformer':
        return Icons.power;
      case 'Turbine':
        return Icons.tornado;
      default:
        return Icons.precision_manufacturing;
    }
  }

  Future<void> _downloadMachineryReport() async {
    if (_isDownloadingReport) return;
    setState(() => _isDownloadingReport = true);

    try {
      final bytes = await _exportService.exportMachineryReportToPdf();
      final now = DateTime.now();
      final filename =
          'Machinery_Report_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}.pdf';
      final path = await _exportService.savePdf(bytes, filename);
      if (!mounted) return;
      _showExportSuccessDialog(
        path: path,
        title: AppLocalizations.of(context)!.dashboardMachineryPdfReady,
        shareText: AppLocalizations.of(context)!.dashboardMachineryShareText,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.dashboardGenerateReportError}: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingReport = false);
    }
  }

  Future<void> _downloadAllMachineryReport() async {
    if (_isDownloadingAllReport) return;
    setState(() => _isDownloadingAllReport = true);

    try {
      final bytes = await _exportService.exportAllMachineryToPdf();
      final now = DateTime.now();
      final filename =
          'All_Machinery_Report_${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
      final path = await _exportService.savePdf(bytes, filename);
      if (!mounted) return;
      _showExportSuccessDialog(
        path: path,
        title: AppLocalizations.of(context)!.dashboardAllMachineryPdfReady,
        shareText: AppLocalizations.of(context)!.dashboardAllMachineryShareText,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.dashboardGenerateFullReportError}: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingAllReport = false);
    }
  }

  Future<String> _saveAsAndMoveExport(String generatedPath) async {
    final defaultName = p.basename(generatedPath);

    String? pickedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF File',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    pickedPath ??= await _pickPathFromDirectory(defaultName);

    if (pickedPath == null || pickedPath.trim().isEmpty) {
      return generatedPath;
    }

    final sourceFile = File(generatedPath);
    final destinationFile = File(pickedPath);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await sourceFile.copy(destinationFile.path);
    return destinationFile.path;
  }

  Future<String?> _pickPathFromDirectory(String defaultName) async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder to Save PDF',
    );
    if (directory == null || directory.trim().isEmpty) return null;
    return p.join(directory, defaultName);
  }

  void _showExportSuccessDialog({
    required String path,
    required String title,
    required String shareText,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 42),
            const SizedBox(height: 10),
            Text(AppLocalizations.of(ctx)!.dashboardFilePreparedAt(path), style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.commonClose),
          ),
          TextButton.icon(
            onPressed: () async {
              final savedPath = await _saveAsAndMoveExport(path);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              _showExportSuccessDialog(
                path: savedPath,
                title: title,
                shareText: shareText,
              );
            },
            icon: const Icon(Icons.save_alt),
            label: Text(AppLocalizations.of(ctx)!.dashboardChooseSavePath),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(path)], text: shareText);
            },
            icon: const Icon(Icons.chat),
            label: Text(AppLocalizations.of(ctx)!.commonWhatsappShare),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(path)], text: shareText);
            },
            icon: const Icon(Icons.share),
            label: Text(AppLocalizations.of(ctx)!.commonShare),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _entriesDao.searchEntries(query);
      if (mounted) {
        setState(() => _searchResults = results);
      }
    } catch (e) {
      // Ignore search errors
    }
  }

  Widget _buildModernDashboard(double width) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = width >= 1100;
    final now = DateTime.now();
    final dateLabel =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1628), Color(0xFF141E35)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.navDashboard,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                    SizedBox(height: 4),
                    Text(l10n.dashboardOverview,
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4)),
                  ),
                    child: Text('${l10n.dashboardActive} · $dateLabel',
                      style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w600, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _DashboardKpiCard(
                  title: l10n.dashboardTotalSchemes,
                  value: _schemeCount.toString(),
                  color: const Color(0xFF60A5FA),
                  icon: Icons.water_drop,
                ),
                _DashboardKpiCard(
                  title: l10n.dashboardTotalSets,
                  value: _setCount.toString(),
                  color: const Color(0xFFA78BFA),
                  icon: Icons.settings,
                ),
                _DashboardKpiCard(
                  title: l10n.dashboardEntriesPerMonth,
                  value: _entriesThisMonth.toString(),
                  color: const Color(0xFF34D399),
                  icon: Icons.receipt_long,
                ),
                _DashboardKpiCard(
                  title: l10n.dashboardAmountPerMonth,
                  value: CurrencyUtils.formatAmountShort(_amountThisMonth),
                  color: const Color(0xFFFBBF24),
                  icon: Icons.payments_outlined,
                ),
              ],
            ),

            const SizedBox(height: 14),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildMonthlyPanel()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildMachineryPanel()),
                    ],
                  )
                : Column(
                    children: [
                      _buildMonthlyPanel(),
                      const SizedBox(height: 10),
                      _buildMachineryPanel(),
                    ],
                  ),

            const SizedBox(height: 12),
            isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildRecentEntriesPanel()),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: _buildSchemesPanel()),
                    ],
                  )
                : Column(
                    children: [
                      _buildRecentEntriesPanel(),
                      const SizedBox(height: 10),
                      _buildSchemesPanel(),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelShell({required String title, required Widget child, Widget? trailing}) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCompact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                if (trailing != null) ...[
                  const SizedBox(height: 8),
                  trailing,
                ],
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                if (trailing != null) trailing,
              ],
            ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildMonthlyPanel() {
    final bars = [1.8, 2.1, 1.9, 2.4, 2.2, 2.8];
    final max = bars.reduce((a, b) => a > b ? a : b);
    return _buildPanelShell(
      title: AppLocalizations.of(context)!.dashboardMonthlyExpenditure,
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(bars.length, (i) {
                final h = (bars[i] / max) * 64;
                final isLast = i == bars.length - 1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: h,
                          decoration: BoxDecoration(
                            color: isLast ? const Color(0xFF60A5FA) : Colors.white.withOpacity(0.12),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aug', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('Sep', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('Oct', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('Nov', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('Dec', style: TextStyle(color: Colors.white54, fontSize: 10)),
              Text('Jan', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMachineryPanel() {
    return _buildPanelShell(
      title: AppLocalizations.of(context)!.dashboardMachineryStatus,
      trailing: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: _isDownloadingReport ? null : _downloadMachineryReport,
            icon: const Icon(Icons.picture_as_pdf, size: 14),
            label: Text(_isDownloadingReport ? AppLocalizations.of(context)!.dashboardGenerating : 'PDF', style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isDownloadingAllReport ? null : _downloadAllMachineryReport,
            icon: const Icon(Icons.inventory_2_outlined, size: 14),
            label: Text(_isDownloadingAllReport ? AppLocalizations.of(context)!.dashboardGenerating : AppLocalizations.of(context)!.dashboardExportAllMachinery, style: const TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
      child: Column(
        children: _orderedTypeList().map((type) {
          final total = _totalByType[type] ?? 0;
          final functional = _functionalByType[type] ?? 0;
          final ratio = total > 0 ? functional / total : 0.0;
          final specs = _specCountsByType[type] ?? const <String, int>{};
          final sortedSpecs = specs.keys.toList()..sort();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _typeColor(type).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _typeColor(type).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_typeIcon(type), color: _typeColor(type), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(type,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                    Text('$functional/$total ${AppLocalizations.of(context)!.dashboardFunctional}',
                        style: TextStyle(color: _typeColor(type), fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: Colors.white.withOpacity(0.12),
                  color: _typeColor(type),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: sortedSpecs
                      .take(4)
                      .map((spec) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$spec × ${specs[spec]}',
                                style: TextStyle(color: _typeColor(type), fontSize: 10)),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentEntriesPanel() {
    return _buildPanelShell(
      title: AppLocalizations.of(context)!.dashboardRecentBillingEntries,
      child: Column(
        children: _recentEntries.take(5).map((entry) {
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.schemeName ?? '-',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${entry.setLabel ?? '-'} · ${entry.entryDate}',
                          style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text('#${entry.voucherNo ?? '-'}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
                Expanded(
                  child: Text(CurrencyUtils.formatAmount(entry.amount),
                      style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchemesPanel() {
    final shown = _schemes.take(6).toList();
    final maxAmount = shown.isEmpty
        ? 1.0
        : shown.map((s) => s.totalAmount).reduce((a, b) => a > b ? a : b);

    return _buildPanelShell(
      title: AppLocalizations.of(context)!.navSchemes,
      child: Column(
        children: shown.map((scheme) {
          final widthFactor = maxAmount <= 0 ? 0.0 : (scheme.totalAmount / maxAmount).clamp(0.0, 1.0);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(scheme.schemeName,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(CurrencyUtils.formatAmountShort(scheme.totalAmount),
                        style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: widthFactor,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    color: const Color(0xFF60A5FA),
                  ),
                ),
                const SizedBox(height: 4),
                Text('${scheme.setCount} ${AppLocalizations.of(context)!.dashboardSetsLowercase}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width < 600 ? 2 : width < 1200 ? 3 : 4;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // Search bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.dashboardSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _performSearch('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _performSearch,
                    ),
                  ),
                ),

                // Show search results if searching
                if (_isSearching) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        AppLocalizations.of(context)!.dashboardSearchResults(_searchResults.length),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: RecentEntriesList(entries: _searchResults),
                  ),
                ] else ...[
                  SliverToBoxAdapter(child: _buildModernDashboard(width)),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ],
            ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _DashboardKpiCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    return Container(
      constraints: BoxConstraints(minWidth: isCompact ? 140 : 200),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.22),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
