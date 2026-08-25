import 'package:intl/intl.dart';

class CurrencyUtils {
  static String currencySymbol = 'PKR';

  static String formatAmount(double amount, {bool useThousandsSeparator = true}) {
    if (useThousandsSeparator) {
      final f = NumberFormat('#,##0', 'en_US');
      return '$currencySymbol ${f.format(amount)}';
    }
    return '$currencySymbol ${amount.toStringAsFixed(0)}';
  }

  static String formatAmountShort(double amount) {
    if (amount >= 1000000) {
      return '$currencySymbol ${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '$currencySymbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$currencySymbol ${amount.toStringAsFixed(0)}';
  }

  static double? parseAmount(String text) {
    final cleaned = text
        .replaceAll(currencySymbol, '')
        .replaceAll('PKR', '')
        .replaceAll('PKR.', '')
        .replaceAll('Rs.', '')
        .replaceAll('Rs', '')
        .replaceAll(',', '')
        .trim();
    return double.tryParse(cleaned);
  }
}
