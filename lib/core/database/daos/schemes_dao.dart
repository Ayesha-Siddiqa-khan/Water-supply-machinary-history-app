import '../app_database.dart';
import '../../models/scheme.dart';

class SchemesDao {
  final AppDatabase _db = AppDatabase.instance;

  String _now() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Scheme>> getAllSchemes() async {
    return getSchemesByCategory('scheme');
  }

  Future<List<Scheme>> getSchemesByCategory(String category) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT s.*,
        (SELECT COUNT(*) FROM sets WHERE sets.scheme_id = s.scheme_id) as set_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         JOIN sets st ON st.set_id = m.set_id
         WHERE st.scheme_id = s.scheme_id) as total_amount
      FROM schemes s
      WHERE LOWER(s.category) = LOWER(?)
      ORDER BY s.scheme_name ASC
    ''', [category]);
    return result.map((r) => Scheme.fromMap(r)).toList();
  }

  Future<Scheme?> getSchemeById(int id) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT s.*,
        (SELECT COUNT(*) FROM sets WHERE sets.scheme_id = s.scheme_id) as set_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         JOIN sets st ON st.set_id = m.set_id
         WHERE st.scheme_id = s.scheme_id) as total_amount
      FROM schemes s
      WHERE s.scheme_id = ?
    ''', [id]);
    if (result.isEmpty) return null;
    return Scheme.fromMap(result.first);
  }

  Future<Scheme?> getSchemeByName(String name) async {
    return getSchemeByNameAndCategory(name, 'scheme');
  }

  Future<Scheme?> getSchemeByNameAndCategory(String name, String category) async {
    final db = await _db.database;
    final result = await db.query(
      'schemes',
      where: 'scheme_name = ? AND LOWER(category) = LOWER(?)',
      whereArgs: [name, category],
    );
    if (result.isEmpty) return null;
    return Scheme.fromMap(result.first);
  }

  Future<int> insertScheme(Scheme scheme) async {
    final db = await _db.database;
    final now = _now();
    return await db.insert('schemes', {
      'scheme_name': scheme.schemeName,
      'category': scheme.category,
      'description': scheme.description,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateScheme(Scheme scheme) async {
    final db = await _db.database;
    await db.update(
      'schemes',
      {
        'scheme_name': scheme.schemeName,
        'category': scheme.category,
        'description': scheme.description,
        'updated_at': _now(),
      },
      where: 'scheme_id = ?',
      whereArgs: [scheme.schemeId],
    );
  }

  Future<void> deleteScheme(int id) async {
    final db = await _db.database;
    await db.delete('schemes', where: 'scheme_id = ?', whereArgs: [id]);
  }

  Future<int> getSchemeCount() async {
    return getSchemeCountByCategory('scheme');
  }

  Future<int> getSchemeCountByCategory(String category) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM schemes WHERE LOWER(category) = LOWER(?)',
      [category],
    );
    return result.first['cnt'] as int;
  }
}
