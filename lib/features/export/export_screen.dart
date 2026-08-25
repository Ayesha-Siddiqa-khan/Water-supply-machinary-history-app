import 'package:flutter/material.dart';
import 'package:city_water_works_app/l10n/app_localizations.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/daos/schemes_dao.dart';
import '../../core/database/daos/sets_dao.dart';
import '../../core/database/daos/machinery_dao.dart';
import '../../core/database/daos/miscellaneous_dao.dart';
import '../../core/models/machinery.dart';
import '../../core/models/scheme.dart';
import '../../core/models/set_model.dart';
import '../../core/services/export_service.dart';
import '../../shared/theme/app_colors.dart';

class ExportScreen extends StatefulWidget {
  final int? schemeId;
  final int? setId;

  const ExportScreen({super.key, this.schemeId, this.setId});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _schemesDao = SchemesDao();
  final _setsDao = SetsDao();
  final _machineryDao = MachineryDao();
  final _miscDao = MiscellaneousDao();
  final _exportService = ExportService();

  List<Scheme> _schemes = [];
  List<SetModel> _sets = [];
  List<Machinery> _machineryForSet = [];
  Scheme? _selectedScheme;
  SetModel? _selectedSet;
  Machinery? _selectedMachinery;
  List<Map<String, String>> _miscRecords = [];
  String _miscExportMode = 'single';
  String _uselessExportMode = 'single';
  String? _selectedMiscRecordId;
  String _exportFormat = 'pdf';
  String _exportScope = 'set';
  String _schemeCategory = 'scheme';

  bool _isLoading = true;
  bool _isExporting = false;

  bool get _isUselessCategoryExport =>
      _exportScope != 'miscellaneous' && _schemeCategory == 'useless_item';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      String categoryToLoad = _schemeCategory;
      if (widget.schemeId != null) {
        final schemeById = await _schemesDao.getSchemeById(widget.schemeId!);
        if (schemeById != null) {
          categoryToLoad = schemeById.category;
        }
      }

      final schemes = await _schemesDao.getSchemesByCategory(categoryToLoad);
      setState(() {
        _schemeCategory = categoryToLoad;
        _schemes = schemes;
        _isLoading = false;
      });

      if (widget.schemeId != null) {
        final scheme = schemes.where((s) => s.schemeId == widget.schemeId).firstOrNull;
        if (scheme != null) {
          _selectedScheme = scheme;
          _exportScope = widget.setId != null ? 'set' : 'scheme';
          await _loadSets(scheme.schemeId!);
          if (widget.setId != null) {
            _selectedSet = _sets.where((s) => s.setId == widget.setId).firstOrNull;
            if (_selectedSet != null) {
              await _loadMachinery(_selectedSet!.setId!);
            }
          }
          setState(() {});
        }
      }

      await _loadMiscRecords();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMiscRecords() async {
    final recordsRaw = await _miscDao.getAllRecords();
    final records = recordsRaw
        .map((map) => {
              'id': (map['id'] ?? '').toString(),
              'title': (map['title'] ?? 'Untitled').toString(),
            })
        .where((entry) => (entry['id'] ?? '').isNotEmpty)
        .toList();

    if (!mounted) return;
    setState(() {
      _miscRecords = records;
      if (_selectedMiscRecordId != null && !_miscRecords.any((r) => r['id'] == _selectedMiscRecordId)) {
        _selectedMiscRecordId = null;
      }
    });
  }

  Future<void> _loadSets(int schemeId) async {
    final sets = await _setsDao.getSetsForScheme(schemeId);
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _machineryForSet = [];
      _selectedMachinery = null;
    });
  }

  Future<void> _reloadSchemesForCategory(String category) async {
    final schemes = await _schemesDao.getSchemesByCategory(category);
    if (!mounted) return;
    setState(() {
      _schemeCategory = category;
      _uselessExportMode = 'single';
      _schemes = schemes;
      _selectedScheme = null;
      _selectedSet = null;
      _selectedMachinery = null;
      _sets = [];
      _machineryForSet = [];
    });
  }

  Future<void> _loadMachinery(int setId) async {
    final machinery = await _machineryDao.getMachineryForSet(setId);
    if (!mounted) return;
    setState(() {
      _machineryForSet = machinery;
      _selectedMachinery = null;
    });
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final isUselessCategoryExport = _isUselessCategoryExport;

    if (_exportScope != 'miscellaneous' && _selectedScheme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectScheme)),
      );
      return;
    }
    if (isUselessCategoryExport && _uselessExportMode == 'single' && _selectedSet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectSet)),
      );
      return;
    }
    if (isUselessCategoryExport && _uselessExportMode == 'single' && _selectedMachinery == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectMachineryField)),
      );
      return;
    }
    if (_exportScope == 'set' && _selectedSet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectSet)),
      );
      return;
    }
    if (_exportScope == 'miscellaneous' && _miscExportMode == 'single' && _selectedMiscRecordId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSelectMiscItem)),
      );
      return;
    }
    setState(() => _isExporting = true);

    try {
      String? filePath;
      String? suggestedFileName;

      if (_exportFormat == 'pdf') {
        Uint8List pdfBytes;
        String filename;
        if (_exportScope == 'miscellaneous') {
          pdfBytes = await _exportService.exportMiscellaneousToPdf(
            recordId: _miscExportMode == 'single' ? _selectedMiscRecordId : null,
          );
          filename = _buildSuggestedFileName(extension: 'pdf');
        } else if (isUselessCategoryExport && _uselessExportMode == 'single') {
          pdfBytes = await _exportService.exportSingleMachineryToPdf(
            _selectedSet!.setId!,
            _selectedMachinery!.machineryId!,
          );
          filename = _buildSuggestedFileName(extension: 'pdf');
        } else if (isUselessCategoryExport && _uselessExportMode == 'complete') {
          pdfBytes = await _exportService.exportSchemeToPdf(_selectedScheme!.schemeId!);
          filename = _buildSuggestedFileName(extension: 'pdf');
        } else if (_exportScope == 'set' && _selectedSet != null && _selectedMachinery != null) {
          pdfBytes = await _exportService.exportSingleMachineryToPdf(
            _selectedSet!.setId!,
            _selectedMachinery!.machineryId!,
          );
          filename = _buildSuggestedFileName(extension: 'pdf');
        } else if (_exportScope == 'set' && _selectedSet != null) {
          pdfBytes = await _exportService.exportSetToPdf(_selectedSet!.setId!);
          filename = _buildSuggestedFileName(extension: 'pdf');
        } else {
          pdfBytes = await _exportService.exportSchemeToPdf(_selectedScheme!.schemeId!);
          filename = _buildSuggestedFileName(extension: 'pdf');
        }
        suggestedFileName = filename;
        filePath = await _savePdfWithPathChoice(pdfBytes, filename);
      } else if (_exportFormat == 'excel') {
        suggestedFileName = _buildSuggestedFileName(extension: 'xlsx');
        if (_exportScope == 'miscellaneous') {
          filePath = await _exportService.exportMiscellaneousToExcel(
            recordId: _miscExportMode == 'single' ? _selectedMiscRecordId : null,
          );
        } else if (isUselessCategoryExport && _uselessExportMode == 'single') {
          filePath = await _exportService.exportSingleMachineryToExcel(
            _selectedSet!.setId!,
            _selectedMachinery!.machineryId!,
          );
        } else if (isUselessCategoryExport && _uselessExportMode == 'complete') {
          filePath = await _exportService.exportSchemeToExcel(_selectedScheme!.schemeId!);
        } else if (_exportScope == 'set' && _selectedSet != null) {
          if (_selectedMachinery != null) {
            filePath = await _exportService.exportSingleMachineryToExcel(
              _selectedSet!.setId!,
              _selectedMachinery!.machineryId!,
            );
          } else {
            filePath = await _exportService.exportSetToExcel(_selectedSet!.setId!);
          }
        } else {
          filePath = await _exportService.exportSchemeToExcel(_selectedScheme!.schemeId!);
        }
      } else if (_exportFormat == 'csv') {
        suggestedFileName = _buildSuggestedFileName(extension: 'csv');
        if (_exportScope == 'miscellaneous') {
          filePath = await _exportService.exportMiscellaneousToCsv(
            recordId: _miscExportMode == 'single' ? _selectedMiscRecordId : null,
          );
        } else if (isUselessCategoryExport && _uselessExportMode == 'single') {
          filePath = await _exportService.exportSingleMachineryToCsv(
            _selectedSet!.setId!,
            _selectedMachinery!.machineryId!,
          );
        } else if (isUselessCategoryExport && _uselessExportMode == 'complete') {
          filePath = await _exportService.exportSchemeToCsv(_selectedScheme!.schemeId!);
        } else if (_exportScope == 'set' && _selectedSet != null) {
          if (_selectedMachinery != null) {
            filePath = await _exportService.exportSingleMachineryToCsv(
              _selectedSet!.setId!,
              _selectedMachinery!.machineryId!,
            );
          } else {
            filePath = await _exportService.exportSetToCsv(_selectedSet!.setId!);
          }
        } else {
          filePath = await _exportService.exportSchemeToCsv(_selectedScheme!.schemeId!);
        }
      }

      if (filePath != null && mounted) {
        _showExportSuccess(filePath, suggestedFileName: suggestedFileName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportErrorPrefix}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportAllMachineryPdf() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isExporting = true);

    try {
      final pdfBytes = await _exportService.exportAllMachineryToPdf();
      final now = DateTime.now();
      final filename =
          'WaterSupplySchemeHistory_AllMachinery_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.pdf';
      final filePath = await _savePdfWithPathChoice(pdfBytes, filename);

      if (mounted) {
        _showExportSuccess(filePath, suggestedFileName: filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.exportErrorPrefix}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  String _buildSuggestedFileName({required String extension}) {
    if (_exportScope == 'miscellaneous') {
      if (_miscExportMode == 'single' && _selectedMiscRecordId != null) {
        final item = _miscRecords.where((r) => r['id'] == _selectedMiscRecordId).firstOrNull;
        final title = (item?['title'] ?? 'Miscellaneous').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
        return '${title}_Miscellaneous_Export.$extension';
      }
      return 'Miscellaneous_Export.$extension';
    }

    if (_isUselessCategoryExport && _uselessExportMode == 'complete') {
      final schemeName = (_selectedScheme?.schemeName ?? 'Useless_Items').replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      return '${schemeName}_Useless_Items_Complete.$extension';
    }

    final machineryTypeForName = (_selectedMachinery?.machineryType.trim().isNotEmpty ?? false)
        ? _selectedMachinery!.machineryType.trim()
        : 'Machinery';

    final rawBaseName = _exportScope == 'set' && _selectedSet != null
      ? _selectedMachinery != null
        ? '${_selectedSet!.setLabel}_${machineryTypeForName}_Export'
        : '${_selectedSet!.setLabel}_Export'
      : '${_selectedScheme?.schemeName ?? 'Export'}_Export';

    final safeBaseName = rawBaseName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return '$safeBaseName.$extension';
  }

  Future<String> _saveAsAndMoveExport(String generatedPath, [String? preferredFileName]) async {
    final defaultName = preferredFileName?.trim().isNotEmpty == true
        ? preferredFileName!
        : p.basename(generatedPath);

    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile, FilePicker.saveFile requires bytes directly
      final fileBytes = await File(generatedPath).readAsBytes();
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save Export File',
        fileName: defaultName,
        bytes: fileBytes,
      );
      // Always return the original app-docs path so sharing still works
      return generatedPath;
    }

    final pickedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Export File',
      fileName: defaultName,
    );

    if (pickedPath == null || pickedPath.trim().isEmpty) {
      return generatedPath;
    }

    final sourceFile = File(generatedPath);
    final destinationFile = File(pickedPath);

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await sourceFile.copy(pickedPath);
    return pickedPath;
  }

  Future<String> _savePdfWithPathChoice(Uint8List bytes, String filename) async {
    // Always save to app docs first — gives a real file path for sharing on all platforms
    final shareablePath = await _exportService.savePdf(bytes, filename);

    if (Platform.isAndroid || Platform.isIOS) {
      // Also let user pick a save location; FilePicker writes via SAF on its own
      await FilePicker.platform.saveFile(
        dialogTitle: 'Choose where to save',
        fileName: filename,
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        bytes: bytes,
      );
      return shareablePath; // Return real app-docs path for sharing
    }

    // Desktop: get path from picker, then write bytes manually
    final pickedPath = await _pickExportPath(filename, const ['pdf']);
    if (pickedPath == null || pickedPath.trim().isEmpty) {
      return _exportService.savePdf(bytes, filename);
    }

    final destinationFile = File(pickedPath);
    if (!await destinationFile.parent.exists()) {
      await destinationFile.parent.create(recursive: true);
    }
    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    await destinationFile.writeAsBytes(bytes);
    return destinationFile.path;
  }

  Future<String?> _pickExportPath(String defaultName, List<String> extensions) async {
    String? pickedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Choose where to save export',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: extensions,
    );

    if (pickedPath == null || pickedPath.trim().isEmpty) {
      final directory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder for export file',
      );
      if (directory != null && directory.trim().isNotEmpty) {
        pickedPath = p.join(directory, defaultName);
      }
    }

    return pickedPath;
  }

  void _showExportSuccess(String path, {String? suggestedFileName}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.exportCompleteTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 48),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(ctx)!.exportFileSavedTo(path), style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final savedPath = await _saveAsAndMoveExport(path, suggestedFileName);
              if (!mounted || !ctx.mounted) return;
              Navigator.pop(ctx);
              _showExportSuccess(savedPath, suggestedFileName: suggestedFileName);
            },
            icon: const Icon(Icons.save_alt),
            label: Text(AppLocalizations.of(ctx)!.commonSaveAs),
          ),
          if (!Platform.isAndroid && !Platform.isIOS)
            TextButton.icon(
              onPressed: () async {
                if (Platform.isWindows) {
                  await Process.run('explorer.exe', ['/select,', path]);
                } else {
                  final folder = p.dirname(path);
                  await Process.run('xdg-open', [folder]);
                }
              },
              icon: const Icon(Icons.folder_open),
              label: Text(AppLocalizations.of(ctx)!.exportOpenFolder),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)!.commonClose),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(path)], text: AppLocalizations.of(ctx)!.exportShareText);
            },
            icon: const Icon(Icons.chat),
            label: Text(AppLocalizations.of(ctx)!.commonWhatsappShare),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Share.shareXFiles([XFile(path)]);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isCompact = MediaQuery.of(context).size.width < 600;
    final isUselessCategoryExport = _isUselessCategoryExport;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navExport)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(isCompact ? 12 : 16),
              children: [
                // Scope selection
                Text(l10n.exportScopeTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (isCompact) ...[
                  // Mobile: stack vertically, no icons, compact labels
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'set', label: Text(l10n.exportScopeSingleSet)),
                        ButtonSegment(value: 'scheme', label: Text(l10n.exportScopeEntireSchemes)),
                        ButtonSegment(value: 'miscellaneous', label: Text(l10n.navMiscellaneous)),
                      ],
                      selected: {_exportScope},
                      onSelectionChanged: (v) => setState(() {
                        _exportScope = v.first;
                        _selectedSet = null;
                        _selectedMachinery = null;
                        _machineryForSet = [];
                        if (_exportScope == 'miscellaneous') {
                          _miscExportMode = 'single';
                          _selectedMiscRecordId = null;
                        } else {
                          _uselessExportMode = 'single';
                        }
                      }),
                    ),
                  ),
                  if (_exportScope != 'miscellaneous') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 'scheme', label: Text(l10n.navSchemes)),
                          ButtonSegment(value: 'useless_item', label: Text(l10n.navUselessItems)),
                        ],
                        selected: {_schemeCategory},
                        onSelectionChanged: (v) async {
                          await _reloadSchemesForCategory(v.first);
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // Desktop/tablet: side by side with icons
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'set', label: Text(l10n.exportScopeSingleSet), icon: const Icon(Icons.folder)),
                            ButtonSegment(
                              value: 'scheme',
                              label: Text(l10n.exportScopeEntireSchemes),
                              icon: const Icon(Icons.business),
                            ),
                            ButtonSegment(
                              value: 'miscellaneous',
                              label: Text(l10n.navMiscellaneous),
                              icon: const Icon(Icons.category_outlined),
                            ),
                          ],
                          selected: {_exportScope},
                          onSelectionChanged: (v) => setState(() {
                            _exportScope = v.first;
                            _selectedSet = null;
                            _selectedMachinery = null;
                            _machineryForSet = [];
                            if (_exportScope == 'miscellaneous') {
                              _miscExportMode = 'single';
                              _selectedMiscRecordId = null;
                            } else {
                              _uselessExportMode = 'single';
                            }
                          }),
                        ),
                      ),
                      if (_exportScope != 'miscellaneous') ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: [
                              ButtonSegment(value: 'scheme', label: Text(l10n.navSchemes), icon: const Icon(Icons.business)),
                              ButtonSegment(
                                value: 'useless_item',
                                label: Text(l10n.navUselessItems),
                                icon: const Icon(Icons.delete_sweep_outlined),
                              ),
                            ],
                            selected: {_schemeCategory},
                            onSelectionChanged: (v) async {
                              await _reloadSchemesForCategory(v.first);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 20),

                // Scheme selector
                if (_exportScope != 'miscellaneous') ...[
                  DropdownButtonFormField<Scheme>(
                    initialValue: _selectedScheme,
                    decoration: InputDecoration(
                      labelText: l10n.exportSelectSchemeField,
                      border: OutlineInputBorder(),
                    ),
                    items: _schemes
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.schemeName)))
                        .toList(),
                    onChanged: (s) async {
                      setState(() {
                        _selectedScheme = s;
                        _selectedSet = null;
                        _selectedMachinery = null;
                        _machineryForSet = [];
                        _sets = [];
                      });
                      if (s != null) await _loadSets(s.schemeId!);
                    },
                  ),
                  const SizedBox(height: 16),

                  if (isUselessCategoryExport) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.exportMiscModeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    SegmentedButton<String>(
                      showSelectedIcon: !isCompact,
                      segments: [
                        ButtonSegment(value: 'single', label: Text(l10n.exportMiscSingleItem), icon: const Icon(Icons.filter_1)),
                        ButtonSegment(value: 'complete', label: Text(l10n.exportMiscComplete), icon: const Icon(Icons.list_alt)),
                      ],
                      selected: {_uselessExportMode},
                      onSelectionChanged: (v) => setState(() {
                        _uselessExportMode = v.first;
                        if (_uselessExportMode == 'complete') {
                          _exportScope = 'scheme';
                          _selectedSet = null;
                          _selectedMachinery = null;
                          _machineryForSet = [];
                        } else {
                          _exportScope = 'set';
                        }
                      }),
                    ),
                    const SizedBox(height: 16),
                  ],
                ] else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(l10n.exportMiscModeTitle, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(value: 'single', label: Text(l10n.exportMiscSingleItem), icon: const Icon(Icons.filter_1)),
                          ButtonSegment(value: 'complete', label: Text(l10n.exportMiscComplete), icon: const Icon(Icons.list_alt)),
                        ],
                        selected: {_miscExportMode},
                        onSelectionChanged: (v) => setState(() {
                          _miscExportMode = v.first;
                          if (_miscExportMode == 'complete') {
                            _selectedMiscRecordId = null;
                          }
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (_miscExportMode == 'single')
                        DropdownButtonFormField<String>(
                          initialValue: _selectedMiscRecordId,
                          decoration: InputDecoration(
                            labelText: l10n.exportSelectMiscField,
                            border: OutlineInputBorder(),
                          ),
                          items: _miscRecords
                              .map((r) => DropdownMenuItem(
                                    value: r['id'],
                                    child: Text(r['title'] ?? l10n.commonUntitled),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedMiscRecordId = v),
                        )
                      else
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.info_outline),
                          title: Text(l10n.exportMiscCompleteTitle),
                          subtitle: Text(l10n.exportMiscCompleteSubtitle),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Set selector (only if scope is 'set')
                if (_exportScope == 'set' && (!isUselessCategoryExport || _uselessExportMode == 'single')) ...[
                  DropdownButtonFormField<SetModel>(
                    initialValue: _selectedSet,
                    decoration: InputDecoration(
                      labelText: l10n.exportSelectSetField,
                      border: OutlineInputBorder(),
                    ),
                    items: _sets
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.setLabel)))
                        .toList(),
                    onChanged: (s) async {
                      setState(() {
                        _selectedSet = s;
                        _selectedMachinery = null;
                        _machineryForSet = [];
                      });
                      if (s != null) {
                        await _loadMachinery(s.setId!);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Machinery?>(
                    initialValue: _selectedMachinery,
                    decoration: InputDecoration(
                      labelText: l10n.exportSelectMachineryField,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      if (!isUselessCategoryExport)
                        DropdownMenuItem<Machinery?>(
                          value: null,
                          child: Text(l10n.exportAllMachineryInSet),
                        ),
                      ..._machineryForSet.map(
                        (m) => DropdownMenuItem<Machinery?>(
                          value: m,
                          child: Text(m.displayLabel),
                        ),
                      ),
                    ],
                    onChanged: (m) => setState(() => _selectedMachinery = m),
                  ),
                  const SizedBox(height: 20),
                ],

                // Format selection
                Text(l10n.exportFormatTitle, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildFormatTile('pdf', l10n.exportFormatPdf, Icons.picture_as_pdf, Colors.red),
                _buildFormatTile('excel', l10n.exportFormatExcel, Icons.table_chart, Colors.green),
                _buildFormatTile('csv', l10n.exportFormatCsv, Icons.text_snippet, Colors.blue),
                const SizedBox(height: 24),

                // Export button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isExporting ? null : _export,
                    icon: _isExporting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download),
                    label: Text(_isExporting ? l10n.exportInProgress : l10n.navExport),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: (_isExporting || _exportScope == 'miscellaneous')
                        ? null
                        : _exportAllMachineryPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: Text(l10n.exportAllMachinerySinglePdf),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFormatTile(String value, String label, IconData icon, Color color) {
    return RadioListTile<String>(
      value: value,
      groupValue: _exportFormat,
      onChanged: (v) => setState(() => _exportFormat = v!),
      title: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
