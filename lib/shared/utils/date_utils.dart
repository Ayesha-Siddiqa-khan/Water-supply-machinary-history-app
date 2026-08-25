
class DateUtils2 {
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  static DateTime? parseDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length != 3) return null;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      return DateTime(year, month, day);
    } catch (_) {
      return null;
    }
  }

  static String now() {
    return formatDate(DateTime.now());
  }

  static String nowWithTime() {
    final dt = DateTime.now();
    return '${formatDate(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static bool isValidDate(String dateStr) {
    return parseDate(dateStr) != null;
  }
}
