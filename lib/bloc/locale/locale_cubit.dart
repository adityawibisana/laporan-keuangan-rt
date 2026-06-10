import 'dart:ui' show Locale;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's current locale and persists the choice across launches.
///
/// Defaults to Bahasa Indonesia when nothing has been saved yet. Pass a
/// [SharedPreferences] for persistence; omit it (e.g. in tests) for an
/// in-memory cubit.
class LocaleCubit extends Cubit<Locale?> {
  final SharedPreferences? _prefs;

  LocaleCubit([this._prefs]) : super(_initial(_prefs));

  static const _key = 'locale';
  static const defaultLocale = Locale('id');
  static const supported = [Locale('id'), Locale('en')];

  static Locale _initial(SharedPreferences? prefs) {
    final code = prefs?.getString(_key);
    return code != null ? Locale(code) : defaultLocale;
  }

  void setLocale(Locale locale) {
    _prefs?.setString(_key, locale.languageCode);
    emit(locale);
  }
}
