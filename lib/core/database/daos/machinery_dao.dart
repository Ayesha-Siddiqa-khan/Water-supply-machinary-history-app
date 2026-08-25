import '../app_database.dart';
import '../../models/machinery.dart';

class MachineryDao {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<Machinery>> getMachineryForSet(int setId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT m.*,
        (SELECT COUNT(*) FROM billing_entries WHERE billing_entries.machinery_id = m.machinery_id) as entry_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         WHERE be.machinery_id = m.machinery_id) as total_amount
      FROM machinery m
      WHERE m.set_id = ?
      ORDER BY m.sort_order ASC, m.machinery_id ASC
    ''', [setId]);
    return result.map((r) => Machinery.fromMap(r)).toList();
  }

  Future<Machinery?> getMachineryById(int id) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT m.*,
        (SELECT COUNT(*) FROM billing_entries WHERE billing_entries.machinery_id = m.machinery_id) as entry_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         WHERE be.machinery_id = m.machinery_id) as total_amount
      FROM machinery m
      WHERE m.machinery_id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    return Machinery.fromMap(result.first);
  }

  Future<int> insertMachinery(Machinery machinery) async {
    final db = await _db.database;
    return await db.insert('machinery', machinery.toMap());
  }

  Future<void> updateMachinery(Machinery machinery) async {
    final db = await _db.database;
    await db.update(
      'machinery',
      machinery.toMap(),
      where: 'machinery_id = ?',
      whereArgs: [machinery.machineryId],
    );
  }

  Future<void> deleteMachinery(int id) async {
    final db = await _db.database;
    await db.delete('machinery', where: 'machinery_id = ?', whereArgs: [id]);
  }

  Future<int> getCountByType(String typeName) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM machinery WHERE machinery_type = ?',
      [typeName],
    );
    return result.first['cnt'] as int;
  }

  Future<int> getNextSortOrder(int setId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(sort_order), 0) + 1 as next_order FROM machinery WHERE set_id = ?',
      [setId],
    );
    return result.first['next_order'] as int;
  }

  Future<List<Machinery>> getAllMachineryWithStats() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT m.*,
        (SELECT COUNT(*) FROM billing_entries WHERE billing_entries.machinery_id = m.machinery_id) as entry_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         WHERE be.machinery_id = m.machinery_id) as total_amount
      FROM machinery m
      ORDER BY m.machinery_type ASC, m.display_label ASC
    ''');
    return result.map((r) => Machinery.fromMap(r)).toList();
  }
}
