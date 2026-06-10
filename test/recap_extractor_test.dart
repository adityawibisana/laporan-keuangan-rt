// Verifies the Dart XLSX reader + extractor against the real workbook, matching
// the known-good values produced by the Python extraction.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:laporan_keuangan_rt/data/recap_extractor.dart';
import 'package:laporan_keuangan_rt/data/xlsx_reader.dart';
import 'package:laporan_keuangan_rt/models/recap.dart';

void main() {
  test('extracts correct computed values from the source workbook', () {
    final file = File('source_data.xlsx');
    if (!file.existsSync()) {
      // The workbook is a dev convenience; skip if a forker removed it.
      markTestSkipped('source_data.xlsx not present');
      return;
    }

    final wb = XlsxWorkbook.decode(file.readAsBytesSync());
    final months = RecapExtractor.extract(wb);

    expect(months.length, 12);

    final jan = months.firstWhere((m) => m.key == 'Jan');
    expect(jan.month, 1);
    expect(jan.year, 2026);
    expect(jan.totalPenerimaan, 16111000);
    expect(jan.totalPengeluaran, 2175000);
    expect(jan.saldoAkhir, 13936000);
    expect(
      jan.penerimaan.firstWhere((e) => e.keterangan == 'Saldo Sebelumnya').amount,
      13366000,
    );
    expect(
      jan.rincian.firstWhere((e) => e.pos == 'Kematian').amount,
      1407000,
    );

    final feb = months.firstWhere((m) => m.key == 'Feb');
    expect(feb.totalPenerimaan, 17606000);
    expect(feb.saldoAkhir, 13931000);

    // Closing balance should carry into the next month's "Saldo Sebelumnya".
    LineItem? saldoSebelumnya(MonthRecap m) {
      for (final e in m.penerimaan) {
        if (e.keterangan == 'Saldo Sebelumnya') return e;
      }
      return null;
    }

    expect(saldoSebelumnya(feb)?.amount, jan.saldoAkhir);
  });
}
