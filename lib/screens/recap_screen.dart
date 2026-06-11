import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/auth/auth_cubit.dart';
import '../bloc/edit/edit_cubit.dart';
import '../bloc/locale/locale_cubit.dart';
import '../bloc/recap/recap_bloc.dart';
import '../config/app_config.dart';
import '../config/app_theme.dart';
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
              // recap is null on the not-yet-data-ready placeholder month; that
              // case is rendered as an "inactive" view by _RecapView. Only a
              // genuinely empty data set falls through to the no-data message.
              if (recap == null && !state.isPlaceholder) {
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

  /// The month to display, or null when showing the not-yet-data-ready
  /// placeholder month (rendered "inactive").
  final MonthRecap? recap;

  const _RecapView({required this.state, required this.recap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeName = Localizations.localeOf(context).toString();

    final inactive = recap == null;
    final year = recap?.year ?? state.placeholderYear;
    final month = recap?.month ?? state.placeholderMonth;
    final monthTitle = DateFormat.yMMMM(localeName).format(DateTime(year, month));

    // The not-ready month shows the same layout with empty/zero figures, dimmed
    // so it reads as "this page isn't data-ready yet". The month switcher and
    // the notice stay at full strength so the user can read it and step back.
    final content = <Widget>[
      Center(
        child: Text(
          l10n.neighborhood,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: 20),
      _SaldoHero(label: l10n.closingBalance, saldo: recap?.saldoAkhir ?? 0),
      const SizedBox(height: 16),
      _Section(
        title: l10n.income,
        accent: AppTheme.income,
        items: recap?.penerimaan ?? const [],
        totalLabel: l10n.totalIncome,
        total: recap?.totalPenerimaan ?? 0,
        emptyLabel: l10n.noData,
      ),
      const SizedBox(height: 12),
      _Section(
        title: l10n.expenses,
        accent: AppTheme.expense,
        items: recap?.pengeluaran ?? const [],
        totalLabel: l10n.totalExpenses,
        total: recap?.totalPengeluaran ?? 0,
        emptyLabel: l10n.noData,
      ),
      if (recap != null && recap!.rincian.isNotEmpty) ...[
        const SizedBox(height: 12),
        _Section(
          title: l10n.categoryBreakdown,
          accent: theme.colorScheme.onSurfaceVariant,
          items: [
            for (final e in recap!.rincian)
              LineItem(keterangan: e.pos, amount: e.amount),
          ],
          totalLabel: l10n.total,
          total: recap!.rincian.fold<int>(0, (s, e) => s + e.amount),
          emptyLabel: l10n.noData,
        ),
      ],
    ];

    return Column(
      children: [
        // Show an offline notice while we're displaying cached (not-yet-live)
        // data — unless a refresh is currently in progress.
        if (!state.fromSource && !state.isRefreshing)
          _OfflineBanner(text: l10n.offlineNotice),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
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
              if (inactive) ...[
                const SizedBox(height: 24),
                _NotReadyNotice(text: l10n.notReadyNotice),
                Opacity(opacity: 0.38, child: Column(children: content)),
              ] else
                ...content,
            ],
          ),
        ),
      ],
    );
  }
}

/// A muted, centered notice shown on the not-yet-data-ready placeholder month.
class _NotReadyNotice extends StatelessWidget {
  final String text;
  const _NotReadyNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.hourglass_empty, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
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
        IconButton(
          onPressed: canPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        IconButton(
          onPressed: canNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

/// The closing balance, presented as the screen's hero: a modern gradient teal
/// card with the big monospace amount in white. Carries the brand colour.
class _SaldoHero extends StatelessWidget {
  final String label;
  final int saldo;
  const _SaldoHero({required this.label, required this.saldo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF26A69A), Color(0xFF00695C)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seed.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: Colors.white70,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            formatRupiah(saldo),
            textAlign: TextAlign.center,
            style: AppTheme.money(theme.textTheme.headlineMedium).copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A modern card section: a small accent header, its line items as label/amount
/// rows, and a bold total. White card with rounded corners and a soft shadow.
class _Section extends StatelessWidget {
  final String title;
  final Color accent;
  final List<LineItem> items;
  final String totalLabel;
  final int total;
  final String emptyLabel;

  const _Section({
    required this.title,
    required this.accent,
    required this.items,
    required this.totalLabel,
    required this.total,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...items.map((e) => _row(context, e.keterangan, e.amount)),
          const SizedBox(height: 8),
          _row(context, totalLabel, total, bold: true),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount,
      {bool bold = false}) {
    final theme = Theme.of(context);
    final labelStyle = bold
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final amountStyle = AppTheme.money(theme.textTheme.bodyMedium).copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      color: bold ? accent : theme.colorScheme.onSurface,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 16),
          Text(formatRupiah(amount), style: amountStyle),
        ],
      ),
    );
  }
}
