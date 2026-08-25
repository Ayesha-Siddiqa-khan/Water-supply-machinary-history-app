import '../database/daos/billing_entries_dao.dart';

/// Context7 — Local intelligence engine for smart form suggestions.
/// Operates entirely locally using SQLite data. No external API calls.
class Context7Service {
  final BillingEntriesDao _entriesDao = BillingEntriesDao();

  /// Suggests the next sequential voucher number based on the last entry's voucher
  Future<int?> suggestNextVoucherNo(int machineryId) async {
    final lastVoucher = await _entriesDao.getLastVoucherNo(machineryId);
    if (lastVoucher == null) return null;
    return lastVoucher + 1;
  }

  /// Shows average amount for this machinery type as hint text
  Future<double?> averageAmount(int machineryId) async {
    return await _entriesDao.getAverageAmount(machineryId);
  }

  /// Warns if same Date + Voucher No. + Amount already exists in this machinery
  Future<bool> checkDuplicate(
    int machineryId,
    String date,
    int? voucherNo,
    double amount,
  ) async {
    return await _entriesDao.checkDuplicate(machineryId, date, voucherNo, amount);
  }

  /// Returns the last used date in DD-MM-YYYY format
  Future<String> lastUsedDate() async {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  /// Get next serial number for a machinery's billing entries
  Future<int> nextSerialNo(int machineryId) async {
    return await _entriesDao.getNextSerialNo(machineryId);
  }
}
