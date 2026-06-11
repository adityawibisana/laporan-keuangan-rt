import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/auth/auth_cubit.dart';
import '../bloc/edit/edit_cubit.dart';
import '../bloc/locale/locale_cubit.dart';
import '../bloc/recap/recap_bloc.dart';
import '../config/app_config.dart';
import '../data/sheet_editor.dart';
import '../l10n/app_localizations.dart';
import '../models/recap.dart';
import '../utils/rupiah.dart';
import 'edit_screen.dart';

/// The single screen of v1: shows one month's recap (Laporan Keuangan), lets the
/// user switch months, switch language, and refresh from the source sheet.
class RecapScreen extends StatelessWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (p, c) => p.error != c.error && c.error != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
              SnackBar(content: Text('${l10n.signInFailed}: ${state.error}')));
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        centerTitle: true,
        actions: const [_AccountButton(), _RefreshButton(), _LanguageButton()],
      ),
      body: SafeArea(
        // The AppBar already insets the top; only guard the bottom so content
        // isn't clipped by the Android system navigation bar.
        top: false,
        child: BlocConsumer<RecapBloc, RecapState>(
        listenWhen: (prev, curr) =>
            prev.refreshError != curr.refreshError && curr.refreshError != null,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.updateFailed)));
        },
        builder: (context, state) {
          switch (state.status) {
            case RecapStatus.initial:
            case RecapStatus.loading:
              return const Center(child: CircularProgressIndicator());
            case RecapStatus.failure:
              return _FailureView(
                message: l10n.loadFailed,
                detail: state.error,
                retryLabel: l10n.retry,
                onRetry: () =>
                    context.read<RecapBloc>().add(const RecapStarted()),
              );
            case RecapStatus.success:
              final recap = state.current;
              if (recap == null) {
                return Center(child: Text(l10n.noData));
              }
              return _RecapView(state: state, recap: recap);
          }
        },
      ),
      ),
      ),
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton();

  Future<void> _openEditor(BuildContext context) async {
    final session = context.read<AuthCubit>().session;
    if (session == null) return;
    final recapBloc = context.read<RecapBloc>();
    final monthIndex = (DateTime.now().month - 1).clamp(0, 11);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => EditCubit(SheetEditor(
            client: session.client,
            spreadsheetId: AppConfig.spreadsheetId,
          )),
          child: EditScreen(initialMonthIndex: monthIndex),
        ),
      ),
    );
    // Returning from the editor — refresh the recap to reflect saved changes.
    recapBloc.add(const RecapRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthCubit>();

    // Editing isn't available on this platform/config (e.g. desktop without an
    // OAuth client configured) — hide the control entirely.
    if (!auth.isAvailable) return const SizedBox.shrink();

    if (auth.state.status == AuthStatus.signingIn) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (auth.state.isSignedIn) {
      return PopupMenuButton<String>(
        icon: const Icon(Icons.account_circle),
        tooltip: auth.session?.email,
        onSelected: (v) {
          if (v == 'edit') _openEditor(context);
          if (v == 'out') context.read<AuthCubit>().signOut();
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            enabled: false,
            child: Text(
              auth.session?.email ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          PopupMenuItem<String>(value: 'edit', child: Text(l10n.editData)),
          PopupMenuItem<String>(value: 'out', child: Text(l10n.signOut)),
        ],
      );
    }

    return IconButton(
      icon: const Icon(Icons.login),
      tooltip: l10n.signInToEdit,
      onPressed: () => context.read<AuthCubit>().signIn(),
    );
  }
}

class _RecapView extends StatelessWidget {
  final RecapState state;
  final MonthRecap recap;

  const _RecapView({required this.state, required this.recap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeName = Localizations.localeOf(context).toString();
    final monthTitle =
        DateFormat.yMMMM(localeName).format(DateTime(recap.year, recap.month));

    return Column(
      children: [
        // Show an offline notice while we're displaying cached (not-yet-live)
        // data — unless a refresh is currently in progress.
        if (!state.fromSource && !state.isRefreshing)
          _OfflineBanner(text: l10n.offlineNotice),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _MonthSwitcher(
                title: monthTitle,
                canPrev: state.hasPrev,
                canNext: state.hasNext,
                onPrev: () => context
                    .read<RecapBloc>()
                    .add(MonthSelected(state.selectedIndex - 1)),
                onNext: () => context
                    .read<RecapBloc>()
                    .add(MonthSelected(state.selectedIndex + 1)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  l10n.neighborhood,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              _SaldoCard(label: l10n.closingBalance, saldo: recap.saldoAkhir),
              const SizedBox(height: 16),
              _LineItemsCard(
                title: l10n.income,
                icon: Icons.south_west,
                accent: const Color(0xFF2E7D32),
                items: recap.penerimaan,
                totalLabel: l10n.totalIncome,
                total: recap.totalPenerimaan,
                emptyLabel: l10n.noData,
              ),
              const SizedBox(height: 16),
              _LineItemsCard(
                title: l10n.expenses,
                icon: Icons.north_east,
                accent: const Color(0xFFC62828),
                items: recap.pengeluaran,
                totalLabel: l10n.totalExpenses,
                total: recap.totalPengeluaran,
                emptyLabel: l10n.noData,
              ),
              if (recap.rincian.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RincianCard(
                  title: l10n.categoryBreakdown,
                  totalLabel: l10n.total,
                  rincian: recap.rincian,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  final String message;
  final String? detail;
  final String retryLabel;
  final VoidCallback onRetry;

  const _FailureView({
    required this.message,
    required this.detail,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String text;
  const _OfflineBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatelessWidget {
  const _RefreshButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRefreshing =
        context.select((RecapBloc b) => b.state.isRefreshing);

    if (isRefreshing) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: l10n.refresh,
      onPressed: () =>
          context.read<RecapBloc>().add(const RecapRefreshRequested()),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = Localizations.localeOf(context).languageCode;

    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.translate),
      tooltip: l10n.language,
      onSelected: (locale) => context.read<LocaleCubit>().setLocale(locale),
      itemBuilder: (context) => [
        CheckedPopupMenuItem(
          value: const Locale('id'),
          checked: current == 'id',
          child: Text(l10n.languageIndonesian),
        ),
        CheckedPopupMenuItem(
          value: const Locale('en'),
          checked: current == 'en',
          child: Text(l10n.languageEnglish),
        ),
      ],
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final String title;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSwitcher({
    required this.title,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: canPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.filledTonal(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SaldoCard extends StatelessWidget {
  final String label;
  final int saldo;
  const _SaldoCard({required this.label, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              formatRupiah(saldo),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<LineItem> items;
  final String totalLabel;
  final int total;
  final String emptyLabel;

  const _LineItemsCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
    required this.totalLabel,
    required this.total,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, color: accent),
                ),
              ],
            ),
            const Divider(height: 20),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(emptyLabel),
              )
            else
              ...items.map((e) => _row(context, e.keterangan, e.amount)),
            const Divider(height: 20),
            _row(context, totalLabel, total, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount,
      {bool bold = false}) {
    final style = bold
        ? Theme.of(context)
            .textTheme
            .bodyLarge
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(formatRupiah(amount), style: style),
        ],
      ),
    );
  }
}

class _RincianCard extends StatelessWidget {
  final String title;
  final String totalLabel;
  final List<RincianItem> rincian;
  const _RincianCard({
    required this.title,
    required this.totalLabel,
    required this.rincian,
  });

  @override
  Widget build(BuildContext context) {
    final total = rincian.fold<int>(0, (sum, e) => sum + e.amount);
    final boldStyle = Theme.of(context)
        .textTheme
        .bodyLarge
        ?.copyWith(fontWeight: FontWeight.bold);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: boldStyle),
            const Divider(height: 20),
            ...rincian.map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(e.pos)),
                    const SizedBox(width: 12),
                    Text(formatRupiah(e.amount)),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: Text(totalLabel, style: boldStyle)),
                const SizedBox(width: 12),
                Text(formatRupiah(total), style: boldStyle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
