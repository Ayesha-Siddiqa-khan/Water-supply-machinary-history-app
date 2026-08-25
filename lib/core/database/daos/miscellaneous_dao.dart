import '../app_database.dart';

class MiscellaneousDao {
  final AppDatabase _db = AppDatabase.instance;

  String _nowFormatted() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<Map<String, dynamic>>> getAllRecords() async {
    final db = await _db.database;
    final items = await db.query('miscellaneous_items', orderBy: 'item_id ASC');
    final entries = await db.query('miscellaneous_entries', orderBy: 'item_id ASC, serial_no ASC');

    final entriesByItem = <int, List<Map<String, dynamic>>>{};
    for (final row in entries) {
      final itemId = row['item_id'] as int;
      entriesByItem.putIfAbsent(itemId, () => []).add({
        'id': (row['entry_id'] as int).toString(),
        'category': '',
        'entryDate': (row['entry_date'] ?? '').toString(),
        'voucherNo': row['voucher_no']?.toString(),
        'amount': row['amount'] as num? ?? 0,
        'regPageNo': row['reg_page_no']?.toString(),
        'notes': row['notes']?.toString(),
      });
    }

    return items.map((item) {
      final itemId = item['item_id'] as int;
      final category = (item['category'] ?? 'Miscellaneous').toString();
      final itemEntries = entriesByItem[itemId] ?? [];
      for (final e in itemEntries) {
        e['category'] = category;
      }
      return {
        'id': itemId.toString(),
        'title': (item['title'] ?? '').toString(),
        'category': category,
        'entries': itemEntries,
      };
    }).toList();
  }

  Future<void> replaceAllRecords(List<Map<String, dynamic>> records) async {
    final db = await _db.database;
    final now = _nowFormatted();

    await db.transaction((txn) async {
      await txn.delete('miscellaneous_entries');
      await txn.delete('miscellaneous_items');

      for (final record in records) {
        final itemId = await txn.insert('miscellaneous_items', {
          'title': (record['title'] ?? '').toString(),
          'category': (record['category'] ?? 'Miscellaneous').toString(),
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
}
