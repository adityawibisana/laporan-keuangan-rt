import '../models/recap.dart';
import 'app_database.dart';
import 'sheet_fetcher.dart';

/// Source of monthly recaps for the app. Abstracted so the BLoC can be tested
/// with an in-memory fake instead of the real database / network.
abstract class RecapRepository {
  /// Locally cached data (offline). May seed from the bundled asset on first
  /// run if the database is empty.
  Future<List<MonthRecap>> loadCached();

  /// Downloads fresh data from the configured spreadsheet, stores it locally,
  /// and returns it. Throws on network / parse failure.
  Future<List<MonthRecap>> refreshFromSource();
}

class DbRecapRepository implements RecapRepository {
  final AppDatabase _db;
  final SheetFetcher _fetcher;

  DbRecapRepository({AppDatabase? db, SheetFetcher? fetcher})
      : _db = db ?? AppDatabase.instance,
        _fetcher = fetcher ?? SheetFetcher();

  @override
  Future<List<MonthRecap>> loadCached() => _db.getAllMonths();

  @override
  Future<List<MonthRecap>> refreshFromSource() async {
    final months = await _fetcher.fetch();
    await _db.replaceAll(months);
    return months;
  }
}
