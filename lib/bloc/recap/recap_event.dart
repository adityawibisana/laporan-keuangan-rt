part of 'recap_bloc.dart';

sealed class RecapEvent extends Equatable {
  const RecapEvent();

  @override
  List<Object?> get props => [];
}

/// Load cached data, then refresh from the source spreadsheet.
class RecapStarted extends RecapEvent {
  const RecapStarted();
}

/// Re-download from the source spreadsheet (e.g. user tapped refresh).
class RecapRefreshRequested extends RecapEvent {
  const RecapRefreshRequested();
}

/// Select the month at [index] within the loaded list.
class MonthSelected extends RecapEvent {
  final int index;
  const MonthSelected(this.index);

  @override
  List<Object?> get props => [index];
}
