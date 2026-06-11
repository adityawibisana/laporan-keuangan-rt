part of 'recap_bloc.dart';

enum RecapStatus { initial, loading, success, failure }

class RecapState extends Equatable {
  final RecapStatus status;
  final List<MonthRecap> months;
  final int selectedIndex;

  /// Whether [months] came from a live fetch of the source spreadsheet (true)
  /// or from the local cache / bundled seed (false).
  final bool fromSource;

  /// True while a background refresh from the source is in flight.
  final bool isRefreshing;

  /// Fatal load error (only meaningful when [status] is failure).
  final String? error;

  /// Last refresh failure, for a transient "couldn't update" notice while still
  /// showing cached data.
  final String? refreshError;

  const RecapState({
    this.status = RecapStatus.initial,
    this.months = const [],
    this.selectedIndex = 0,
    this.fromSource = false,
    this.isRefreshing = false,
    this.error,
    this.refreshError,
  });

  MonthRecap? get current =>
      (months.isNotEmpty && selectedIndex >= 0 && selectedIndex < months.length)
          ? months[selectedIndex]
          : null;

  bool get hasPrev => selectedIndex > 0;

  /// The user may step one month past the last data-ready month to preview that
  /// the upcoming month exists but isn't filled in yet; [hasNext] therefore
  /// allows reaching [months].length (the placeholder), but no further.
  bool get hasNext => selectedIndex < months.length;

  /// True when the selected month is the not-yet-data-ready month just after the
  /// last real month. Its content is rendered "inactive" by the UI.
  bool get isPlaceholder =>
      months.isNotEmpty && selectedIndex == months.length;

  /// Month number (1..12) for the placeholder month — the month following the
  /// last data-ready one. Meaningful only when [isPlaceholder] is true.
  int get placeholderMonth =>
      months.isEmpty ? 0 : (months.last.month % 12) + 1;

  /// Calendar year for the placeholder month, rolling over after December.
  int get placeholderYear =>
      months.isEmpty ? 0 : months.last.year + (months.last.month == 12 ? 1 : 0);

  RecapState copyWith({
    RecapStatus? status,
    List<MonthRecap>? months,
    int? selectedIndex,
    bool? fromSource,
    bool? isRefreshing,
    String? error,
    String? refreshError,
    bool clearRefreshError = false,
  }) {
    return RecapState(
      status: status ?? this.status,
      months: months ?? this.months,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      fromSource: fromSource ?? this.fromSource,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error ?? this.error,
      refreshError: clearRefreshError ? null : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [
        status,
        months,
        selectedIndex,
        fromSource,
        isRefreshing,
        error,
        refreshError,
      ];
}
