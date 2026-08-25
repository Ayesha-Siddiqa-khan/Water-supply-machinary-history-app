import 'package:sqflite/sqflite.dart';
import '../app_database.dart';

class SettingsDao {
  final AppDatabase _db = AppDatabase.instance;

  Future<String?> getSetting(String key) async {
    final db = await _db.database;
    final result = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await _db.database;
    final result = await db.query('app_settings');
    return Map.fromEntries(
      result.map((r) => MapEntry(r['key'] as String, r['value'] as String? ?? '')),
    );
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _db.database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> setSettings(Map<String, String> settings) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final entry in settings.entries) {
      batch.insert(
        'app_settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }
}
