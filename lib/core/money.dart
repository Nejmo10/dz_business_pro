import 'package:intl/intl.dart';

/// Financial decimal-safety strategy
/// ---------------------------------
/// Every monetary amount in the database and in Dart is stored as an INTEGER
/// minor unit ("centimes"): 1 DZD = 100 cents. No floating point arithmetic is
/// ever used for money. `Money` is the only place that converts between
/// user-entered decimal amounts and integer minor units.
class Money {
  static const int centsPerUnit = 100;

  static int fromString(String raw) {
    final s = raw.trim().replaceAll(' ', '').replaceAll(',', '.');
    final num = double.tryParse(s) ?? 0;
    return (num * centsPerUnit).round();
  }

  static String fmt(int minor, {String symbol = ' DZD', String locale = 'fr'}) {
    final nf = NumberFormat.decimalPatternDigits(locale: locale == 'ar' ? 'ar_DZ' : 'fr_DZ', decimalDigits: 2);
    final sign = minor < 0 ? '-' : '';
    return '$sign${nf.format(minor.abs() / centsPerUnit)}$symbol';
  }
}

class Dates {
  /// Canonical stored datetime format: ISO8601 UTC string, second precision.
  static String iso(DateTime dt) =>
      dt.toUtc().toIso8601String().split('.').first;
  static String isoDay(DateTime dt) => iso(dt).substring(0, 10);
  static DateTime parse(String s) => DateTime.parse(s);
  static String dayStart(DateTime d) => iso(DateTime(d.year, d.month, d.day));
  static String dayEnd(DateTime d) =>
      iso(DateTime(d.year, d.month, d.day, 23, 59, 59));
}
