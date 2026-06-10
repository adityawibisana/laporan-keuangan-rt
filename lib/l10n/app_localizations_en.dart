// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Financial Report';

  @override
  String get neighborhood => 'RT03 / RW21 Bukit Permai';

  @override
  String get closingBalance => 'Closing Balance';

  @override
  String get income => 'Income';

  @override
  String get expenses => 'Expenses';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalExpenses => 'Total Expenses';

  @override
  String get categoryBreakdown => 'Category Breakdown';

  @override
  String get total => 'Total';

  @override
  String get noData => 'No data';

  @override
  String get loadFailed => 'Failed to load data';

  @override
  String get language => 'Language';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get languageEnglish => 'English';

  @override
  String get refresh => 'Refresh';

  @override
  String get updating => 'Updating…';

  @override
  String get offlineNotice => 'Offline — showing saved data';

  @override
  String get updateFailed => 'Couldn\'t update from the source';

  @override
  String get updatedFromSource => 'Updated from the source';

  @override
  String get retry => 'Retry';
}
