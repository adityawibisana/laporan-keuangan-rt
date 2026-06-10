import 'dart:ui' show Locale;

import 'package:flutter_bloc/flutter_bloc.dart';

/// Holds the app's current locale. Defaults to Bahasa Indonesia.
///
/// Kept intentionally simple (in-memory) for v1; persistence can be added later
/// alongside the +/- input screens.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit() : super(defaultLocale);

  static const defaultLocale = Locale('id');
  static const supported = [Locale('id'), Locale('en')];

  void setLocale(Locale locale) => emit(locale);
}
