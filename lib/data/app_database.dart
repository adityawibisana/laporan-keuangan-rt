import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/recap.dart';

/// Offline SQLite store for the monthly recaps.
///
/// Starts empty; the app fills it by fetching the source spreadsheet (see
/// [RecapRepository.refreshFromSource]). It then serves as the offline cache /
/// fallback if a later fetch fails.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'laporan_keuangan.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE months (
        key               TEXT PRIMARY KEY,
        month             INTEGER NOT NULL,
        year              INTEGER NOT NULL,
        title             TEXT NOT NULL,
        total_penerimaan  INTEGER NOT NULL,
        total_pengeluaran INTEGER NOT NULL,
        saldo_akhir       INTEGER NOT NULL,
        sort_order        INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE line_items (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        type      TEXT NOT NULL,            -- 'in' (Penerimaan) | 'out' (Pengeluaran)
        keterangan TEXT NOT NULL,
        amount    INTEGER NOT NULL,
        position  INTEGER NOT NULL,
        FOREIGN KEY (month_key) REFERENCES months(key)
      )
    ''');
    await db.execute('''
      CREATE TABLE rincian (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        month_key TEXT NOT NULL,
        pos       TEXT NOT NULL,
        amount    INTEGER NOT NULL,
        position  INTEGER NOT NULL,
        FOREIGN KEY (month_key) REFERENCES months(key)
      )
    ''');
  }

  /// Returns every month recap, ordered Jan → Des.
  Future<List<MonthRecap>> getAllMonths() async {
    final db = await database;
    final monthRows =
        await db.query('months', orderBy: 'sort_order ASC');

    final result = <MonthRecap>[];
    for (final row in monthRows) {
      final key = row['key'] as String;

      final lines = await db.query('line_items',
          where: 'month_key = ?', whereArgs: [key], orderBy: 'position ASC');
      final rincianRows = await db.query('rincian',
          where: 'month_key = ?', whereArgs: [key], orderBy: 'position ASC');

      result.add(MonthRecap(
        key: key,
        month: row['month'] as int,
        year: row['year'] as int,
        title: row['title'] as String,
        penerimaan: lines
            .where((e) => e['type'] == 'in')
            .map((e) => LineItem(
                keterangan: e['keterangan'] as String,
                amount: e['amount'] as int))
            .toList(),
        totalPenerimaan: row['total_penerimaan'] as int,
        pengeluaran: lines
            .where((e) => e['type'] == 'out')
            .map((e) => LineItem(
                keterangan: e['keterangan'] as String,
                amount: e['amount'] as int))
            .toList(),
        totalPengeluaran: row['total_pengeluaran'] as int,
        saldoAkhir: row['saldo_akhir'] as int,
        rincian: rincianRows
            .map((e) => RincianItem(
                pos: e['pos'] as String, amount: e['amount'] as int))
            .toList(),
      ));
    }
    return result;
  }

  /// Number of months currently stored.
  Future<int> monthCount() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM months');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Wipes all stored data and replaces it with [months] (used after a refresh
  /// from the source spreadsheet).
  Future<void> replaceAll(List<MonthRecap> months) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('line_items');
      await txn.delete('rincian');
      await txn.delete('months');

      for (var i = 0; i < months.length; i++) {
        final m = months[i];
        await txn.insert('months', {
          'key': m.key,
          'month': m.month,
          'year': m.year,
          'title': m.title,
          'total_penerimaan': m.totalPenerimaan,
          'total_pengeluaran': m.totalPengeluaran,
          'saldo_akhir': m.saldoAkhir,
          'sort_order': i,
        });

        for (var j = 0; j < m.penerimaan.length; j++) {
          await txn.insert('line_items', {
            'month_key': m.key,
            'type': 'in',
            'keterangan': m.penerimaan[j].keterangan,
            'amount': m.penerimaan[j].amount,
            'position': j,
          });
        }
        for (var j = 0; j < m.pengeluaran.length; j++) {
          await txn.insert('line_items', {
            'month_key': m.key,
            'type': 'out',
            'keterangan': m.pengeluaran[j].keterangan,
            'amount': m.pengeluaran[j].amount,
            'position': j,
          });
        }
        for (var j = 0; j < m.rincian.length; j++) {
          await txn.insert('rincian', {
            'month_key': m.key,
            'pos': m.rincian[j].pos,
            'amount': m.rincian[j].amount,
            'position': j,
          });
        }
      }
    });
  }
}
