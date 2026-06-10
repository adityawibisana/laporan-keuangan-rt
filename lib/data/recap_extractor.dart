import '../models/recap.dart';
import 'xlsx_reader.dart';

/// Extracts the 12 monthly recaps from a parsed workbook. This mirrors the
/// server-free Python extraction: it walks each recap tab (Jan..Des) and reads
/// the Penerimaan / Pengeluaran / Saldo akhir / Rincian Pos blocks positionally.
class RecapExtractor {
  static const _monthKeys = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static const _monthFull = {
    'Jan': 'Januari', 'Feb': 'Februari', 'Mar': 'Maret', 'Apr': 'April',
    'Mei': 'Mei', 'Jun': 'Juni', 'Jul': 'Juli', 'Agu': 'Agustus',
    'Sep': 'September', 'Okt': 'Oktober', 'Nov': 'November', 'Des': 'Desember',
  };

  static List<MonthRecap> extract(XlsxWorkbook wb) {
    final year = _readYear(wb);
    final months = <MonthRecap>[];

    for (var i = 0; i < _monthKeys.length; i++) {
      final key = _monthKeys[i];
      final rows = wb.sheet(key);
      if (rows == null) continue;

      final income = <LineItem>[];
      final expense = <LineItem>[];
      final rincian = <RincianItem>[];
      var totalPenerimaan = 0;
      var totalPengeluaran = 0;
      var saldoAkhir = 0;
      var inRincian = false;

      for (final row in rows) {
        final c1 = _cell(row, 1);
        final c2 = _cell(row, 2);
        final c4 = _cell(row, 4);
        final c5 = _cell(row, 5);

        if (c1 == 'Rincian Pos') {
          inRincian = true;
          continue;
        }
        if (inRincian) {
          if (c1 == 'Total' || c1 == null) continue;
          if (c2 != null) {
            rincian.add(RincianItem(pos: c1, amount: _amount(c2)));
          }
          continue;
        }

        // Income (left) side.
        if (c1 == 'Total Penerimaan') {
          totalPenerimaan = _amount(c2);
        } else if (c1 != null && c1 != 'Keterangan' && c2 != null) {
          income.add(LineItem(keterangan: c1, amount: _amount(c2)));
        }

        // Expense (right) side.
        if (c4 == 'Total Pengeluaran') {
          totalPengeluaran = _amount(c5);
        } else if (c4 == 'Saldo akhir') {
          saldoAkhir = _amount(c5);
        } else if (c4 != null && c4 != 'Keterangan' && c5 != null) {
          expense.add(LineItem(keterangan: c4, amount: _amount(c5)));
        }
      }

      months.add(MonthRecap(
        key: key,
        month: i + 1,
        year: year,
        title: '${_monthFull[key]} $year',
        penerimaan: income,
        totalPenerimaan: totalPenerimaan,
        pengeluaran: expense,
        totalPengeluaran: totalPengeluaran,
        saldoAkhir: saldoAkhir,
        rincian: rincian,
      ));
    }

    return months;
  }

  static int _readYear(XlsxWorkbook wb) {
    final ref = wb.sheet('Ref');
    if (ref != null) {
      for (final row in ref) {
        if (_cell(row, 0) == 'Tahun') {
          final y = _amount(_cell(row, 1));
          if (y > 0) return y;
        }
      }
    }
    return DateTime.now().year;
  }

  /// Trimmed cell text, or null if out of range / blank.
  static String? _cell(List<String?> row, int i) {
    if (i >= row.length) return null;
    final v = row[i];
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// Parses an amount from either a machine number ("660000") or formatted
  /// Indonesian currency text (" Rp 660.000 ").
  static int _amount(String? raw) {
    if (raw == null) return 0;
    final s = raw.trim();
    if (s.isEmpty) return 0;
    // Formatted text (has letters or spaces): strip everything but digits/sign.
    if (RegExp(r'[A-Za-z ]').hasMatch(s)) {
      final digits = s.replaceAll(RegExp(r'[^0-9-]'), '');
      return int.tryParse(digits) ?? 0;
    }
    // Plain machine number, possibly with a decimal point.
    final d = double.tryParse(s);
    if (d != null) return d.round();
    final digits = s.replaceAll(RegExp(r'[^0-9-]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
