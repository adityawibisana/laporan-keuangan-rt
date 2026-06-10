/// Data models for a single month's financial recap (Laporan Keuangan).
///
/// These mirror the "recap" tabs of the source spreadsheet (Jan, Feb, ...):
/// a list of income lines (Penerimaan), a list of expense lines
/// (Pengeluaran), the closing balance (Saldo akhir), and a per-category
/// breakdown (Rincian Pos).
library;

class LineItem {
  final String keterangan;
  final int amount;

  const LineItem({required this.keterangan, required this.amount});

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        keterangan: json['ket'] as String,
        amount: (json['amount'] as num).toInt(),
      );
}

class RincianItem {
  final String pos;
  final int amount;

  const RincianItem({required this.pos, required this.amount});

  factory RincianItem.fromJson(Map<String, dynamic> json) => RincianItem(
        pos: json['pos'] as String,
        amount: (json['amount'] as num).toInt(),
      );
}

class MonthRecap {
  /// Short key matching the spreadsheet tab, e.g. "Jan", "Feb", "Mar".
  final String key;

  /// Month number 1..12, used to render a locale-aware month name.
  final int month;

  /// Calendar year, e.g. 2026.
  final int year;

  /// Indonesian display title from the source sheet, e.g. "Januari 2026".
  /// Used as a fallback; the UI prefers a locale-aware [month]/[year] title.
  final String title;

  final List<LineItem> penerimaan;
  final int totalPenerimaan;
  final List<LineItem> pengeluaran;
  final int totalPengeluaran;
  final int saldoAkhir;
  final List<RincianItem> rincian;

  const MonthRecap({
    required this.key,
    required this.month,
    required this.year,
    required this.title,
    required this.penerimaan,
    required this.totalPenerimaan,
    required this.pengeluaran,
    required this.totalPengeluaran,
    required this.saldoAkhir,
    required this.rincian,
  });

  factory MonthRecap.fromJson(Map<String, dynamic> json) => MonthRecap(
        key: json['key'] as String,
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num).toInt(),
        title: json['title'] as String,
        penerimaan: (json['penerimaan'] as List)
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPenerimaan: (json['totalPenerimaan'] as num).toInt(),
        pengeluaran: (json['pengeluaran'] as List)
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPengeluaran: (json['totalPengeluaran'] as num).toInt(),
        saldoAkhir: (json['saldoAkhir'] as num).toInt(),
        rincian: (json['rincian'] as List)
            .map((e) => RincianItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
