import 'package:intl/intl.dart';

final NumberFormat _rupiah = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Formats an integer amount as Indonesian rupiah, e.g. 16111000 -> "Rp 16.111.000".
String formatRupiah(int amount) => _rupiah.format(amount);
