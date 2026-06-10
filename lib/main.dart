import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'auth/auth_service_factory.dart';
import 'bloc/auth/auth_cubit.dart';
import 'bloc/locale/locale_cubit.dart';
import 'bloc/recap/recap_bloc.dart';
import 'data/recap_repository.dart';
import 'l10n/app_localizations.dart';
import 'screens/recap_screen.dart';

/// True when running on a desktop OS. We develop/iterate on Windows for speed,
/// but the UI is framed to a phone size so it matches the mobile target.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Logical size of the phone frame shown on desktop (≈ a typical 6.1" phone).
const Size _phoneSize = Size(390, 844);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the data-source config (.env). Missing file is non-fatal: AppConfig
  // falls back to a default URL.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // ignore — fallback config will be used.
  }

  if (_isDesktop) {
    // sqflite has no native desktop implementation; use the FFI backend.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final prefs = await SharedPreferences.getInstance();
  runApp(LaporanKeuanganApp(prefs: prefs));
}

class LaporanKeuanganApp extends StatelessWidget {
  final SharedPreferences prefs;
  const LaporanKeuanganApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RecapRepository>(create: (_) => DbRecapRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => LocaleCubit(prefs)),
          BlocProvider(create: (_) => AuthCubit(createAuthService())),
          BlocProvider(
            create: (context) => RecapBloc(
              context.read<RecapRepository>(),
            )..add(const RecapStarted()),
          ),
        ],
        child: BlocBuilder<LocaleCubit, Locale?>(
          builder: (context, locale) {
            return MaterialApp(
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context).appTitle,
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
                useMaterial3: true,
              ),
              locale: locale,
              supportedLocales: LocaleCubit.supported,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              builder: (context, child) => _PhoneFrame(child: child!),
              home: const RecapScreen(),
            );
          },
        ),
      ),
    );
  }
}

/// On desktop, renders the app inside a centered phone-sized viewport so the
/// layout matches the mobile target while we iterate quickly on Windows. On a
/// real phone it's a no-op (returns the child unchanged).
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return child;

    final outer = MediaQuery.of(context);
    return ColoredBox(
      color: const Color(0xFF202124),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: _phoneSize.width,
            height: _phoneSize.height,
            // Make everything inside believe it is a phone-sized screen.
            child: MediaQuery(
              data: outer.copyWith(
                size: _phoneSize,
                padding: EdgeInsets.zero,
                viewPadding: EdgeInsets.zero,
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
