// Widget test for the recap screen: drives the real RecapBloc with an
// in-memory fake repository (no database) and verifies localized rendering.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laporan_keuangan_rt/bloc/locale/locale_cubit.dart';
import 'package:laporan_keuangan_rt/bloc/recap/recap_bloc.dart';
import 'package:laporan_keuangan_rt/data/recap_repository.dart';
import 'package:laporan_keuangan_rt/l10n/app_localizations.dart';
import 'package:laporan_keuangan_rt/models/recap.dart';
import 'package:laporan_keuangan_rt/screens/recap_screen.dart';

class _FakeRecapRepository implements RecapRepository {
  static const _data = [
    MonthRecap(
          key: 'Jan',
          month: 1,
          year: 2026,
          title: 'Januari 2026',
          penerimaan: [
            LineItem(keterangan: 'Saldo Sebelumnya', amount: 13366000)
          ],
          totalPenerimaan: 16111000,
          pengeluaran: [
            LineItem(keterangan: 'Iuran Tukang Sampah', amount: 750000)
          ],
          totalPengeluaran: 2175000,
          saldoAkhir: 13936000,
          rincian: [RincianItem(pos: 'Kematian', amount: 1407000)],
        ),
      ];

  @override
  Future<List<MonthRecap>> loadCached() async => _data;

  @override
  Future<List<MonthRecap>> refreshFromSource() async => _data;
}

Widget _wrap(Locale locale) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LocaleCubit()),
      BlocProvider(
        create: (_) =>
            RecapBloc(_FakeRecapRepository(), now: () => DateTime(2026, 1, 15))
              ..add(const RecapStarted()),
      ),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: LocaleCubit.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const RecapScreen(),
    ),
  );
}

void main() {
  testWidgets('renders Indonesian labels', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('id')));
    await tester.pumpAndSettle();

    expect(find.text('Penerimaan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Saldo Akhir'), findsOneWidget);
    expect(find.text('Total Penerimaan'), findsOneWidget);
  });

  testWidgets('renders English labels', (tester) async {
    await tester.pumpWidget(_wrap(const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Expenses'), findsOneWidget);
    expect(find.text('Closing Balance'), findsOneWidget);
    expect(find.text('Total Income'), findsOneWidget);
  });
}
