import '../app_database.dart';
import '../../models/set_model.dart';

class SetsDao {
  final AppDatabase _db = AppDatabase.instance;

  Future<List<SetModel>> getSetsForScheme(int schemeId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT st.*,
        (SELECT COUNT(*) FROM machinery WHERE machinery.set_id = st.set_id) as machinery_count,
        (SELECT COUNT(*) FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         WHERE m.set_id = st.set_id) as entry_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         WHERE m.set_id = st.set_id) as total_amount
      FROM sets st
      WHERE st.scheme_id = ?
      ORDER BY st.set_number ASC
    ''', [schemeId]);
    return result.map((r) => SetModel.fromMap(r)).toList();
  }

  Future<SetModel?> getSetById(int id) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT st.*,
        (SELECT COUNT(*) FROM machinery WHERE machinery.set_id = st.set_id) as machinery_count,
        (SELECT COUNT(*) FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         WHERE m.set_id = st.set_id) as entry_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         WHERE m.set_id = st.set_id) as total_amount
      FROM sets st
      WHERE st.set_id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    return SetModel.fromMap(result.first);
  }

  Future<int> insertSet(SetModel set) async {
    final db = await _db.database;
    return await db.insert('sets', set.toMap());
  }

  Future<void> updateSet(SetModel set) async {
    final db = await _db.database;
    await db.update(
      'sets',
      set.toMap(),
      where: 'set_id = ?',
      whereArgs: [set.setId],
    );
  }

  Future<void> deleteSet(int id) async {
    final db = await _db.database;
    await db.delete('sets', where: 'set_id = ?', whereArgs: [id]);
  }

  Future<int> getSetCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM sets');
    return result.first['cnt'] as int;
  }

  Future<int> getNextSetNumber(int schemeId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(set_number), 0) + 1 as next_num FROM sets WHERE scheme_id = ?',
      [schemeId],
    );
    return result.first['next_num'] as int;
  }
}
