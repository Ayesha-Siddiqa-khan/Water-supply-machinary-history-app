import '../app_database.dart';

class MiscellaneousDao {
  final AppDatabase _db = AppDatabase.instance;

  String _nowFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> getAllRecords({
    int? schemeId,
    int? setId,
    String? category,
  }) async {
    final db = await _db.database;
    final items = await db.rawQuery(
      '''
      SELECT mi.*, s.scheme_name, st.set_label
      FROM miscellaneous_items mi
      LEFT JOIN schemes s ON s.scheme_id = mi.scheme_id
      LEFT JOIN sets st ON st.set_id = mi.set_id
      WHERE 1 = 1
      ${schemeId == null ? '' : 'AND mi.scheme_id = ?'}
      ${setId == null ? '' : 'AND mi.set_id = ?'}
      ${category == null ? '' : "AND LOWER(mi.category) = LOWER(?)"}
      ORDER BY mi.item_id ASC
    ''',
      [
        if (schemeId != null) schemeId,
        if (setId != null) setId,
        if (category != null) category,
      ],
    );
    final entries = await db.query(
      'miscellaneous_entries',
      orderBy: 'item_id ASC, serial_no ASC',
    );

    final entriesByItem = <int, List<Map<String, dynamic>>>{};
    for (final row in entries) {
      final itemId = row['item_id'] as int;
      entriesByItem.putIfAbsent(itemId, () => []).add({
        'id': (row['entry_id'] as int).toString(),
        'category': '',
        'entryDate': (row['entry_date'] ?? '').toString(),
        'workOrderNo': row['work_order_no']?.toString(),
        'voucherNo': row['voucher_no']?.toString(),
        'amount': row['amount'] as num? ?? 0,
        'regPageNo': row['reg_page_no']?.toString(),
        'notes': row['notes']?.toString(),
      });
    }

    return items.map((item) {
      final itemId = item['item_id'] as int;
      final cat = (item['category'] ?? 'Miscellaneous').toString();
      final itemEntries = entriesByItem[itemId] ?? [];
      for (final e in itemEntries) {
        e['category'] = cat;
      }
      return {
        'id': itemId.toString(),
        'schemeId': item['scheme_id'],
        'schemeName': item['scheme_name']?.toString(),
        'setId': item['set_id'],
        'setLabel': item['set_label']?.toString(),
        'title': (item['title'] ?? '').toString(),
        'category': cat,
        'description': item['description']?.toString(),
        'date': (item['date'] ?? item['created_at'] ?? '').toString(),
        'amount': item['amount'] as num? ?? 0,
        'workOrderNo': item['work_order_no']?.toString(),
        'voucherNo': item['voucher_no']?.toString(),
        'regPageNo': item['reg_page_no']?.toString(),
        'notes': item['notes']?.toString(),
        'categoryData': item['category_data']?.toString(),
        'locationType': (item['location_type'] ?? 'scheme').toString(),
        'locationName': item['location_name']?.toString(),
        'locationAddress': item['location_address']?.toString(),
        'locationDescription': item['location_description']?.toString(),
        'entries': itemEntries,
      };
    }).toList();
  }

  Future<int> getRecordCountByCategory(String category) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM miscellaneous_items WHERE LOWER(category) = LOWER(?)",
      [category],
    );
    return result.first['cnt'] as int;
  }

  Future<List<String>> getAllCategories() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT category FROM miscellaneous_items ORDER BY category ASC',
    );
    return result.map((r) => (r['category'] ?? '').toString()).where((c) => c.isNotEmpty).toList();
  }

  Future<void> replaceAllRecords(List<Map<String, dynamic>> records) async {
    final db = await _db.database;
    final now = _nowFormatted();

    await db.transaction((txn) async {
      await txn.delete('miscellaneous_entries');
      await txn.delete('miscellaneous_items');

      for (final record in records) {
        final itemId = await txn.insert('miscellaneous_items', {
          'scheme_id': record['schemeId'],
          'set_id': record['setId'],
          'title': (record['title'] ?? '').toString(),
          'category': (record['category'] ?? 'Miscellaneous').toString(),
          'description': record['description']?.toString(),
          'date': (record['date'] ?? '').toString(),
          'amount': double.tryParse((record['amount'] ?? 0).toString()) ?? 0,
          'work_order_no': record['workOrderNo']?.toString(),
          'voucher_no': record['voucherNo']?.toString(),
          'reg_page_no': record['regPageNo']?.toString(),
          'notes': record['notes']?.toString(),
          'category_data': record['categoryData']?.toString(),
          'location_type': (record['locationType'] ?? 'scheme').toString(),
          'location_name': record['locationName']?.toString(),
          'location_address': record['locationAddress']?.toString(),
          'location_description': record['locationDescription']?.toString(),
          'created_at': now,
          'updated_at': now,
        });

        final entries = record['entries'];
        if (entries is List) {
          for (int i = 0; i < entries.length; i++) {
            final rawEntry = entries[i];
            if (rawEntry is! Map) continue;
            final entry = Map<String, dynamic>.from(rawEntry);
            await txn.insert('miscellaneous_entries', {
              'item_id': itemId,
              'serial_no': i + 1,
              'entry_date': (entry['entryDate'] ?? '').toString(),
              'work_order_no': entry['workOrderNo']?.toString(),
              'voucher_no': entry['voucherNo']?.toString(),
              'amount': double.tryParse((entry['amount'] ?? 0).toString()) ?? 0,
              'reg_page_no': entry['regPageNo']?.toString(),
              'notes': entry['notes']?.toString(),
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
    });
  }

  Future<void> replaceRecordsByCategory(String category, List<Map<String, dynamic>> records) async {
    final db = await _db.database;
    final now = _nowFormatted();

    await db.transaction((txn) async {
      // Delete entries for items in this category only
      await txn.rawDelete('''
        DELETE FROM miscellaneous_entries WHERE item_id IN (
          SELECT item_id FROM miscellaneous_items WHERE LOWER(category) = LOWER(?)
        )
      ''', [category]);
      // Delete items in this category only
      await txn.rawDelete(
        'DELETE FROM miscellaneous_items WHERE LOWER(category) = LOWER(?)',
        [category],
      );

      for (final record in records) {
        final itemId = await txn.insert('miscellaneous_items', {
          'scheme_id': record['schemeId'],
          'set_id': record['setId'],
          'title': (record['title'] ?? '').toString(),
          'category': (record['category'] ?? 'Miscellaneous').toString(),
          'description': record['description']?.toString(),
          'date': (record['date'] ?? '').toString(),
          'amount': double.tryParse((record['amount'] ?? 0).toString()) ?? 0,
          'work_order_no': record['workOrderNo']?.toString(),
          'voucher_no': record['voucherNo']?.toString(),
          'reg_page_no': record['regPageNo']?.toString(),
          'notes': record['notes']?.toString(),
          'category_data': record['categoryData']?.toString(),
          'location_type': (record['locationType'] ?? 'scheme').toString(),
          'location_name': record['locationName']?.toString(),
          'location_address': record['locationAddress']?.toString(),
          'location_description': record['locationDescription']?.toString(),
          'created_at': now,
          'updated_at': now,
        });

        final entries = record['entries'];
        if (entries is List) {
          for (int i = 0; i < entries.length; i++) {
            final rawEntry = entries[i];
            if (rawEntry is! Map) continue;
            final entry = Map<String, dynamic>.from(rawEntry);
            await txn.insert('miscellaneous_entries', {
              'item_id': itemId,
              'serial_no': i + 1,
              'entry_date': (entry['entryDate'] ?? '').toString(),
              'work_order_no': entry['workOrderNo']?.toString(),
              'voucher_no': entry['voucherNo']?.toString(),
              'amount': double.tryParse((entry['amount'] ?? 0).toString()) ?? 0,
              'reg_page_no': entry['regPageNo']?.toString(),
              'notes': entry['notes']?.toString(),
              'created_at': now,
              'updated_at': now,
            });
          }
        }
      }
    });
  }

  // ─── Category Meta CRUD ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllCategoryMeta() async {
    final db = await _db.database;
    final cats = await db.query('misc_categories', orderBy: 'sort_order ASC');
    final counts = <String, int>{};
    for (final cat in cats) {
      final name = (cat['name'] ?? '').toString();
      counts[name] = await getRecordCountByCategory(name);
    }
    return cats.map((c) {
      final name = (c['name'] ?? '').toString();
      return {
        ...c,
        'record_count': counts[name] ?? 0,
      };
    }).toList();
  }

  Future<Map<String, dynamic>?> getCategoryMetaByName(String name) async {
    final db = await _db.database;
    final results = await db.query(
      'misc_categories',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<int> insertCategory(Map<String, dynamic> cat) async {
    final db = await _db.database;
    final now = _nowFormatted();
    return db.insert('misc_categories', {
      'name': cat['name'],
      'icon_name': cat['icon_name'],
      'color_value': cat['color_value'],
      'description': cat['description'],
      'custom_fields': cat['custom_fields'],
      'sort_order': cat['sort_order'] ?? 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateCategory(int categoryId, Map<String, dynamic> cat) async {
    final db = await _db.database;
    await db.update(
      'misc_categories',
      {
        'name': cat['name'],
        'icon_name': cat['icon_name'],
        'color_value': cat['color_value'],
        'description': cat['description'],
        'custom_fields': cat['custom_fields'],
        'sort_order': cat['sort_order'],
        'updated_at': _nowFormatted(),
      },
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  Future<void> deleteCategory(int categoryId) async {
    final db = await _db.database;
    await db.delete('misc_categories', where: 'category_id = ?', whereArgs: [categoryId]);
  }

  Future<void> renameCategoryInRecords(String oldName, String newName) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE miscellaneous_items SET category = ? WHERE LOWER(category) = LOWER(?)',
      [newName, oldName],
    );
  }

  Future<void> deleteRecordsByCategory(String category) async {
    final db = await _db.database;
    await db.rawDelete(
      'DELETE FROM miscellaneous_entries WHERE item_id IN (SELECT item_id FROM miscellaneous_items WHERE LOWER(category) = LOWER(?))',
      [category],
    );
    await db.rawDelete(
      'DELETE FROM miscellaneous_items WHERE LOWER(category) = LOWER(?)',
      [category],
    );
  }
}
