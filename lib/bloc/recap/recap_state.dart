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
  bool get hasNext => selectedIndex < months.length - 1;

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
