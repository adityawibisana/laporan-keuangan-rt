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

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get signInToEdit => 'Sign in to edit';

  @override
  String get signInFailed => 'Sign-in failed';

  @override
  String get editData => 'Edit data';

  @override
  String get editTitle => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get saveFailed => 'Save failed';

  @override
  String get noChanges => 'No changes to save';

  @override
  String get month => 'Month';

  @override
  String get lockedNotice =>
      'Grey cells are computed automatically and can\'t be edited.';
}
