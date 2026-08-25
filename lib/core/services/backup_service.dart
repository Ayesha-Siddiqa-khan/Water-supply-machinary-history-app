import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../database/app_database.dart';

class BackupService {
  final AppDatabase _db = AppDatabase.instance;

  static const List<String> _verifiedTables = [
    'schemes',
    'sets',
    'machinery',
    'billing_entries',
    'miscellaneous_items',
    'miscellaneous_entries',
  ];

  String _nowFormatted() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
  }

  Future<Directory> _getBackupDirectory() async {
    final downloadsDir = await getDownloadsDirectory();
    final baseDir = downloadsDir ?? await getApplicationDocumentsDirectory();
    final backupDir = Directory('${baseDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  Future<Directory> _getPublicDownloadsDirectory() async {
    if (Platform.isAndroid) {
      final androidDownloads = Directory('/storage/emulated/0/Download');
      if (await androidDownloads.exists()) {
        return androidDownloads;
      }
      try {
        await androidDownloads.create(recursive: true);
        return androidDownloads;
      } catch (_) {}
    }

    final downloadsDir = await getDownloadsDirectory();
    if (downloadsDir != null) {
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir;
    }

    return await getApplicationDocumentsDirectory();
  }

  Future<Map<String, int>> _collectTableCounts(Database db) async {
    final counts = <String, int>{};
    for (final table in _verifiedTables) {
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $table');
      counts[table] = (result.first['cnt'] as int?) ?? 0;
    }
    return counts;
  }

  Future<void> _validateRestoredCounts(Map<String, dynamic> metadata) async {
    final raw = metadata['table_counts'];
    if (raw is! Map) return;

    final expected = <String, int>{};
    for (final entry in raw.entries) {
      expected[entry.key.toString()] = int.tryParse(entry.value.toString()) ?? 0;
    }

    final db = await _db.database;
    final actual = await _collectTableCounts(db);

    final mismatches = <String>[];
    for (final table in _verifiedTables) {
      final e = expected[table];
      if (e == null) continue;
      final a = actual[table] ?? 0;
      if (e != a) {
        mismatches.add('$table expected=$e actual=$a');
      }
    }

    if (mismatches.isNotEmpty) {
      throw Exception(
        'Backup verification failed after restore: ${mismatches.join(', ')}',
      );
    }
  }

  /// Create a backup file (.cww = zip of DB + metadata)
  Future<String> createBackup() async {
    // Ensure WAL changes are merged into the main DB file before backup.
    final liveDb = await _db.database;
    await liveDb.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    final tableCounts = await _collectTableCounts(liveDb);
    await _db.closeDatabase();

    final dbPath = await _db.databasePath;
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) {
      throw Exception('Database file not found');
    }

    // Create metadata
    final metadata = {
      'app_version': '1.0.0',
      'schema_version': 1,
      'created_at': _nowFormatted(),
      'platform': Platform.operatingSystem,
      'table_counts': tableCounts,
    };

    // Create archive
    final archive = Archive();

    // Add database file
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('city_water_works.db', dbBytes.length, dbBytes));

    // Add metadata JSON
    final metadataBytes = utf8.encode(jsonEncode(metadata));
    archive.addFile(ArchiveFile('metadata.json', metadataBytes.length, metadataBytes));

    // Encode as zip
    final zipBytes = ZipEncoder().encode(archive);

    // Save backup file
    final backupDir = await _getBackupDirectory();
    final filename = 'WaterSupplyMachineryHistory_Backup_${_nowFormatted()}.cww';
    final backupFile = File('${backupDir.path}/$filename');
    await backupFile.writeAsBytes(zipBytes!);

    // Re-open DB for normal app usage after backup is created.
    await _db.database;

    return backupFile.path;
  }

  Future<String> saveBackupToDownloads(String backupPath) async {
    final source = File(backupPath);
    if (!await source.exists()) {
      throw Exception('Backup file not found');
    }

    final downloadsDir = await _getPublicDownloadsDirectory();
    final target = File(p.join(downloadsDir.path, p.basename(backupPath)));
    await source.copy(target.path);
    return target.path;
  }

  Future<String> saveBackupToPath(String backupPath, String destinationPath) async {
    final source = File(backupPath);
    if (!await source.exists()) {
      throw Exception('Backup file not found');
    }

    final target = File(destinationPath);
    if (!await target.parent.exists()) {
      await target.parent.create(recursive: true);
    }
    if (await target.exists()) {
      await target.delete();
    }

    await source.copy(target.path);
    return target.path;
  }

  /// Restore from a backup file
  Future<void> restoreBackup(String backupPath) async {
    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    final bytes = await backupFile.readAsBytes();
    await _restoreBackupFromBytes(bytes);
  }

  Future<void> restoreBackupBytes(Uint8List bytes) async {
    await _restoreBackupFromBytes(bytes);
  }

  Future<void> _restoreBackupFromBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    // Verify metadata
    ArchiveFile? metadataFile;
    ArchiveFile? dbBackupFile;

    for (final file in archive) {
      if (file.name == 'metadata.json') metadataFile = file;
      if (file.name == 'city_water_works.db') dbBackupFile = file;
    }

    if (dbBackupFile == null) {
      throw Exception('Invalid backup file: database not found');
    }

    Map<String, dynamic>? metadata;
    if (metadataFile != null) {
      metadata = Map<String, dynamic>.from(
        jsonDecode(utf8.decode((metadataFile.content as List<int>))),
      );
      final schemaVersion = metadata['schema_version'] ?? 1;
      // Validate schema version
      if (schemaVersion > 1) {
        throw Exception('Backup from newer app version (schema v$schemaVersion). Please update the app.');
      }
    }

    // Close current database
    await _db.closeDatabase();

    // Replace database
    final dbPath = await _db.databasePath;
    final targetFile = File(dbPath);

    // Delete existing
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      await walFile.delete();
    }
    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      await shmFile.delete();
    }

    // Write restored DB
    final dbContent = dbBackupFile.content;
    await targetFile.writeAsBytes(
      dbContent is Uint8List ? dbContent : Uint8List.fromList(dbContent as List<int>),
    );

    // Re-initialize database
    await _db.database;

    if (metadata != null) {
      await _validateRestoredCounts(metadata);
    }
  }

  /// List available local backups
  Future<List<BackupInfo>> listBackups() async {
    final backupDir = await _getBackupDirectory();

    final files = await backupDir
        .list()
        .where((f) => f.path.endsWith('.cww'))
        .toList();

    final backups = <BackupInfo>[];
    for (final f in files) {
      final file = File(f.path);
      final stat = await file.stat();
      backups.add(BackupInfo(
        path: f.path,
        filename: f.path.split(Platform.pathSeparator).last,
        size: stat.size,
        date: stat.modified,
      ));
    }

    backups.sort((a, b) => b.date.compareTo(a.date));
    return backups.take(10).toList();
  }

  /// Delete all data (factory reset)
  Future<void> deleteAllData() async {
    final db = await _db.database;
    await db.delete('miscellaneous_entries');
    await db.delete('miscellaneous_items');
    await db.delete('billing_entries');
    await db.delete('machinery');
    await db.delete('sets');
    await db.delete('schemes');
  }
}

class BackupInfo {
  final String path;
  final String filename;
  final int size;
  final DateTime date;

  BackupInfo({
    required this.path,
    required this.filename,
    required this.size,
    required this.date,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
