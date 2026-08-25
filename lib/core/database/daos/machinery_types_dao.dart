import '../app_database.dart';
import '../../models/machinery_type.dart';

class MachineryTypesDao {
  final AppDatabase _db = AppDatabase.instance;

  String _now() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<MachineryType>> getAllTypes() async {
    final db = await _db.database;
    final result = await db.query('machinery_types', orderBy: 'type_name ASC');
    return result.map((r) => MachineryType.fromMap(r)).toList();
  }

  Future<MachineryType?> getTypeByName(String name) async {
    final db = await _db.database;
    final result = await db.query(
      'machinery_types',
      where: 'type_name = ?',
      whereArgs: [name],
    );
    if (result.isEmpty) return null;
    return MachineryType.fromMap(result.first);
  }

  Future<int> insertType(MachineryType type) async {
    final db = await _db.database;
    return await db.insert('machinery_types', {
      'type_name': type.typeName,
      'attributes': type.toMap()['attributes'],
      'created_at': _now(),
    });
  }

  Future<void> updateType(MachineryType type) async {
    final db = await _db.database;
    await db.update(
      'machinery_types',
      {
        'type_name': type.typeName,
        'attributes': type.toMap()['attributes'],
      },
      where: 'type_id = ?',
      whereArgs: [type.typeId],
    );
  }

  Future<void> deleteType(int id) async {
    final db = await _db.database;
    await db.delete('machinery_types', where: 'type_id = ?', whereArgs: [id]);
  }
}
