import '../app_database.dart';
import '../../models/billing_entry.dart';

class BillingEntriesDao {
  final AppDatabase _db = AppDatabase.instance;

  String _now() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Future<List<BillingEntry>> getEntriesForMachinery(int machineryId) async {
    final db = await _db.database;
    final result = await db.query(
      'billing_entries',
      where: 'machinery_id = ?',
      whereArgs: [machineryId],
      orderBy: 'serial_no ASC',
    );
    return result.map((r) => BillingEntry.fromMap(r)).toList();
  }

  Future<List<BillingEntry>> getRecentEntries({int limit = 10}) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT be.*, s.scheme_name, st.set_label, m.display_label
      FROM billing_entries be
      JOIN machinery m ON m.machinery_id = be.machinery_id
      JOIN sets st ON st.set_id = m.set_id
      JOIN schemes s ON s.scheme_id = st.scheme_id
      ORDER BY be.entry_id DESC
      LIMIT ?
    ''', [limit]);
    return result.map((r) => BillingEntry.fromMap(r)).toList();
  }

  Future<int> insertEntry(BillingEntry entry) async {
    final db = await _db.database;
    final now = _now();
    return await db.insert('billing_entries', {
      'machinery_id': entry.machineryId,
      'serial_no': entry.serialNo,
      'entry_date': entry.entryDate,
      'voucher_no': entry.voucherNo,
      'amount': entry.amount,
      'reg_page_no': entry.regPageNo,
      'is_disabled': entry.isDisabled ? 1 : 0,
      'submitted_to_store_date': entry.submittedToStoreDate,
      'transfer_date': entry.transferDate,
      'transferred_to_scheme': entry.transferredToScheme,
      'remarks': entry.remarks,
      'notes': entry.notes,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateEntry(BillingEntry entry) async {
    final db = await _db.database;
    await db.update(
      'billing_entries',
      {
        'serial_no': entry.serialNo,
        'entry_date': entry.entryDate,
        'voucher_no': entry.voucherNo,
        'amount': entry.amount,
        'reg_page_no': entry.regPageNo,
        'is_disabled': entry.isDisabled ? 1 : 0,
        'submitted_to_store_date': entry.submittedToStoreDate,
        'transfer_date': entry.transferDate,
        'transferred_to_scheme': entry.transferredToScheme,
        'remarks': entry.remarks,
        'notes': entry.notes,
        'updated_at': _now(),
      },
      where: 'entry_id = ?',
      whereArgs: [entry.entryId],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await _db.database;
    await db.delete('billing_entries', where: 'entry_id = ?', whereArgs: [id]);
  }

  Future<int> getNextSerialNo(int machineryId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(MAX(serial_no), 0) + 1 as next_sn FROM billing_entries WHERE machinery_id = ?',
      [machineryId],
    );
    return result.first['next_sn'] as int;
  }

  Future<int> getEntryCountThisMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString();
    // DD-MM-YYYY format: match entries where month and year match
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM billing_entries WHERE substr(entry_date, 4, 2) = ? AND substr(entry_date, 7, 4) = ?",
      [monthStr, yearStr],
    );
    return result.first['cnt'] as int;
  }

  Future<double> getTotalAmountThisMonth() async {
    final db = await _db.database;
    final now = DateTime.now();
    final monthStr = now.month.toString().padLeft(2, '0');
    final yearStr = now.year.toString();
    final result = await db.rawQuery(
      "SELECT COALESCE(SUM(amount), 0) as total FROM billing_entries WHERE substr(entry_date, 4, 2) = ? AND substr(entry_date, 7, 4) = ?",
      [monthStr, yearStr],
    );
    return (result.first['total'] as num).toDouble();
  }

  Future<int> getTotalEntryCount() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM billing_entries');
    return result.first['cnt'] as int;
  }

  Future<List<BillingEntry>> searchEntries(String query) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT be.*, s.scheme_name, st.set_label, m.display_label
      FROM billing_entries be
      JOIN machinery m ON m.machinery_id = be.machinery_id
      JOIN sets st ON st.set_id = m.set_id
      JOIN schemes s ON s.scheme_id = st.scheme_id
      WHERE be.voucher_no LIKE ? OR be.amount LIKE ? OR be.entry_date LIKE ?
        OR s.scheme_name LIKE ? OR st.set_label LIKE ? OR m.display_label LIKE ?
        OR be.reg_page_no LIKE ? OR be.transferred_to_scheme LIKE ? OR be.remarks LIKE ?
      ORDER BY be.entry_id DESC
      LIMIT 50
    ''', [
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
      '%$query%',
    ]);
    return result.map((r) => BillingEntry.fromMap(r)).toList();
  }

  /// Check for duplicate entries
  Future<bool> checkDuplicate(int machineryId, String date, int? voucherNo, double amount) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM billing_entries WHERE machinery_id = ? AND entry_date = ? AND voucher_no = ? AND amount = ?',
      [machineryId, date, voucherNo, amount],
    );
    return (result.first['cnt'] as int) > 0;
  }

  /// Get last voucher number for machinery
  Future<int?> getLastVoucherNo(int machineryId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT voucher_no FROM billing_entries WHERE machinery_id = ? AND voucher_no IS NOT NULL ORDER BY entry_id DESC LIMIT 1',
      [machineryId],
    );
    if (result.isEmpty) return null;
    return result.first['voucher_no'] as int?;
  }

  /// Get average amount for machinery
  Future<double?> getAverageAmount(int machineryId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT AVG(amount) as avg_amount FROM billing_entries WHERE machinery_id = ?',
      [machineryId],
    );
    return (result.first['avg_amount'] as num?)?.toDouble();
  }

  /// Get all entries for a set (for export)
  Future<List<BillingEntry>> getEntriesForSet(int setId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT be.*, m.display_label
      FROM billing_entries be
      JOIN machinery m ON m.machinery_id = be.machinery_id
      WHERE m.set_id = ?
      ORDER BY m.sort_order ASC, be.serial_no ASC
    ''', [setId]);
    return result.map((r) => BillingEntry.fromMap(r)).toList();
  }

  /// Get all entries for a scheme (for export)
  Future<List<BillingEntry>> getEntriesForScheme(int schemeId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT be.*, s.scheme_name, st.set_label, m.display_label
      FROM billing_entries be
      JOIN machinery m ON m.machinery_id = be.machinery_id
      JOIN sets st ON st.set_id = m.set_id
      JOIN schemes s ON s.scheme_id = st.scheme_id
      WHERE s.scheme_id = ?
      ORDER BY st.set_number ASC, m.sort_order ASC, be.serial_no ASC
    ''', [schemeId]);
    return result.map((r) => BillingEntry.fromMap(r)).toList();
  }
}
