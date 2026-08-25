import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/backup_service.dart';
import '../../shared/theme/app_colors.dart';

class BackupScreen extends StatefulWidget {
  final VoidCallback? onDataRestored;
  const BackupScreen({super.key, this.onDataRestored});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();
  List<BackupInfo> _backups = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  static const _backupActionDone = 'done';
  static const _backupActionShare = 'share';
  static const _backupActionSaveDownloads = 'save_downloads';
  static const _backupActionSelectPath = 'select_path';

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    try {
      final backups = await _backupService.listBackups();
      if (mounted) setState(() { _backups = backups; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    try {
      final filePath = await _backupService.createBackup();
      if (mounted) {
        _loadBackups();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );

        final action = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup Created'),
            content: Text('Saved to:\n$filePath'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, _backupActionDone),
                child: const Text('Done'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, _backupActionSaveDownloads),
                icon: const Icon(Icons.download),
                label: const Text('Save to Downloads'),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pop(ctx, _backupActionSelectPath),
                icon: const Icon(Icons.folder_open),
                label: const Text('Select Path'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, _backupActionShare),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        );

        if (action == _backupActionShare) {
          await Share.shareXFiles([XFile(filePath)]);
        }

        final suggestedName = filePath.split(Platform.pathSeparator).last;
        final isMobile = Platform.isAndroid || Platform.isIOS;

        if (action == _backupActionSaveDownloads) {
          if (isMobile) {
            // Android/iOS: SAF requires writing bytes directly via FilePicker
            final fileBytes = await File(filePath).readAsBytes();
            final savedPath = await FilePicker.platform.saveFile(
              dialogTitle: 'Save backup to Downloads',
              fileName: suggestedName,
              bytes: fileBytes,
            );
            if (!mounted) return;
            if (savedPath != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup saved successfully')),
              );
            }
          } else {
            final downloadsPath = await _backupService.saveBackupToDownloads(filePath);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup saved to Downloads:\n$downloadsPath')),
            );
          }
        }

        if (action == _backupActionSelectPath) {
          if (isMobile) {
            // Android/iOS: must pass bytes — FilePicker writes the file via SAF
            final fileBytes = await File(filePath).readAsBytes();
            final savedPath = await FilePicker.platform.saveFile(
              dialogTitle: 'Choose where to save backup',
              fileName: suggestedName,
              bytes: fileBytes,
            );
            if (!mounted) return;
            if (savedPath != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup saved successfully')),
              );
            }
          } else {
            final destinationPath = await FilePicker.platform.saveFile(
              dialogTitle: 'Choose where to save backup',
              fileName: suggestedName,
              type: FileType.custom,
              allowedExtensions: const ['cww'],
            );
            if (destinationPath != null && destinationPath.trim().isNotEmpty) {
              final savedPath = await _backupService.saveBackupToPath(filePath, destinationPath);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Backup saved to:\n$savedPath')),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreBackup({String? filePath}) async {
    String? path = filePath;
    Uint8List? pickedBytes;

    if (path == null) {
      final result = await FilePicker.platform.pickFiles(
        // Use FileType.any so Google Drive and all file managers can show .cww files
        type: FileType.any,
        allowMultiple: false,
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      pickedBytes = file.bytes;

      // If bytes not loaded (withData failed), try reading from path
      if ((pickedBytes == null || pickedBytes.isEmpty) && file.path != null) {
        final localFile = File(file.path!);
        if (await localFile.exists()) {
          pickedBytes = await localFile.readAsBytes();
        }
      }

      if (pickedBytes == null || pickedBytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the file. Try saving it locally first, then pick it again.'),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will REPLACE all current data with the backup data. This action cannot be undone.\n\nContinue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      if (pickedBytes != null && pickedBytes.isNotEmpty) {
        await _backupService.restoreBackupBytes(pickedBytes);
      } else if (path != null) {
        await _backupService.restoreBackup(path);
      } else {
        throw Exception('Unable to access selected backup file.');
      }
      if (mounted) {
        widget.onDataRestored?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!')),
        );
        // Navigate to root
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will permanently delete ALL data including schemes, sets, machinery, and billing entries.\n\n'
          'This action CANNOT be undone. Consider creating a backup first.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _backupService.deleteAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Create backup
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.backup, color: Colors.white),
                    ),
                    title: const Text('Create Backup'),
                    subtitle: const Text('Save a copy of all your data'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _createBackup,
                  ),
                ),
                const SizedBox(height: 8),

                // Restore from file
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accent.withValues(alpha: 0.8),
                      child: const Icon(Icons.restore, color: Colors.white),
                    ),
                    title: const Text('Restore from File'),
                    subtitle: const Text('Import a .cww backup file'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _restoreBackup(),
                  ),
                ),
                const SizedBox(height: 24),

                // Previous backups
                Text('Previous Backups', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_backups.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No backups yet. Create your first backup above.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ..._backups.map((backup) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.archive, color: AppColors.primary),
                        title: Text(backup.filename, style: const TextStyle(fontSize: 13)),
                        subtitle: Text('${backup.sizeFormatted} · ${_formatDate(backup.date)}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'restore') _restoreBackup(filePath: backup.path);
                            if (v == 'share') {
                              Share.shareXFiles([XFile(backup.path)]);
                            }
                            if (v == 'delete') {
                              File(backup.path).deleteSync();
                              _loadBackups();
                            }
                          },
                          itemBuilder: (ctx) => const [
                            PopupMenuItem(value: 'restore', child: Text('Restore')),
                            PopupMenuItem(value: 'share', child: Text('Share')),
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // Danger zone
                Text('Danger Zone',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.error)),
                const SizedBox(height: 8),
                Card(
                  color: AppColors.error.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: const Icon(Icons.delete_forever, color: AppColors.error),
                    title: const Text('Delete All Data',
                        style: TextStyle(color: AppColors.error)),
                    subtitle: const Text('Permanently remove all records'),
                    onTap: _deleteAllData,
                  ),
                ),
              ],
            ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
