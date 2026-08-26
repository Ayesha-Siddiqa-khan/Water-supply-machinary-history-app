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

  Future<List<Scheme>> getSchemesByCategory(
    String category, {
    int? parentSchemeId,
    int? parentSetId,
  }) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT s.*, p.scheme_name AS parent_scheme_name,
        pst.set_label AS parent_set_label,
        (SELECT COUNT(*) FROM sets WHERE sets.scheme_id = s.scheme_id) as set_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         JOIN sets st ON st.set_id = m.set_id
         WHERE st.scheme_id = s.scheme_id) as total_amount
      FROM schemes s
      LEFT JOIN schemes p ON p.scheme_id = s.parent_scheme_id
      LEFT JOIN sets pst ON pst.set_id = s.parent_set_id
      WHERE LOWER(s.category) = LOWER(?)
        ${parentSchemeId == null ? '' : 'AND s.parent_scheme_id = ?'}
        ${parentSetId == null ? '' : 'AND s.parent_set_id = ?'}
      ORDER BY s.scheme_name ASC
    ''',
      [
        category,
        if (parentSchemeId != null) parentSchemeId,
        if (parentSetId != null) parentSetId,
      ],
    );
    return result.map((r) => Scheme.fromMap(r)).toList();
  }

  Future<Scheme?> getSchemeById(int id) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      '''
      SELECT s.*, p.scheme_name AS parent_scheme_name,
        pst.set_label AS parent_set_label,
        (SELECT COUNT(*) FROM sets WHERE sets.scheme_id = s.scheme_id) as set_count,
        (SELECT COALESCE(SUM(be.amount), 0)
         FROM billing_entries be
         JOIN machinery m ON m.machinery_id = be.machinery_id
         JOIN sets st ON st.set_id = m.set_id
         WHERE st.scheme_id = s.scheme_id) as total_amount
      FROM schemes s
      LEFT JOIN schemes p ON p.scheme_id = s.parent_scheme_id
      LEFT JOIN sets pst ON pst.set_id = s.parent_set_id
      WHERE s.scheme_id = ?
    ''',
      [id],
    );
    if (result.isEmpty) return null;
    return Scheme.fromMap(result.first);
  }

  Future<Scheme?> getSchemeByName(String name) async {
    return getSchemeByNameAndCategory(name, 'scheme');
  }

  Future<Scheme?> getSchemeByNameAndCategory(
    String name,
    String category,
  ) async {
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
      'parent_scheme_id': scheme.parentSchemeId,
      'parent_set_id': scheme.parentSetId,
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
        'parent_scheme_id': scheme.parentSchemeId,
        'parent_set_id': scheme.parentSetId,
        'description': scheme.description,
        'updated_at': _now(),
      },
      where: 'scheme_id = ?',
      whereArgs: [scheme.schemeId],
    );
  }

  Future<void> deleteScheme(int id) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'miscellaneous_items',
        where: 'scheme_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'schemes',
        where: 'parent_scheme_id = ?',
        whereArgs: [id],
      );
      await txn.delete('schemes', where: 'scheme_id = ?', whereArgs: [id]);
    });
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
