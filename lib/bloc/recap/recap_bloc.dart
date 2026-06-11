import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/recap_repository.dart';
import '../../models/recap.dart';

part 'recap_event.dart';
part 'recap_state.dart';

class RecapBloc extends Bloc<RecapEvent, RecapState> {
  final RecapRepository _repository;

  /// Provides "now" so the default selected month is testable. Defaults to the
  /// real clock.
  final DateTime Function() _now;

  RecapBloc(
    this._repository, {
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        super(const RecapState()) {
    on<RecapStarted>(_onStarted);
    on<RecapRefreshRequested>(_onRefreshRequested);
    on<MonthSelected>(_onMonthSelected);
  }

  /// Index of the month to select by default: today's month, clamped to the
  /// available data.
  int _defaultIndex(int count) =>
      (_now().month - 1).clamp(0, count == 0 ? 0 : count - 1);

  /// On every app open: show the loading indicator, then fetch live data. If
  /// the fetch fails, fall back to the last cached data (offline), or to a
  /// failure screen if there is none.
  Future<void> _onStarted(RecapStarted event, Emitter<RecapState> emit) async {
    emit(state.copyWith(status: RecapStatus.loading));
    try {
      final months = await _repository.refreshFromSource();
      emit(state.copyWith(
        status: RecapStatus.success,
        months: months,
        selectedIndex: _defaultIndex(months.length),
        fromSource: true,
      ));
    } catch (e) {
      await _fallbackToCache(emit, fetchError: e.toString());
    }
  }

  /// Manual refresh from the UI. Keeps the current data visible (with a spinner)
  /// and only shows a transient error if it fails.
  Future<void> _onRefreshRequested(
      RecapRefreshRequested event, Emitter<RecapState> emit) async {
    emit(state.copyWith(isRefreshing: true, clearRefreshError: true));
    try {
      final months = await _repository.refreshFromSource();
      final index = state.months.isEmpty
          ? _defaultIndex(months.length)
          : state.selectedIndex.clamp(0, months.length - 1);
      emit(state.copyWith(
        status: RecapStatus.success,
        months: months,
        selectedIndex: index,
        fromSource: true,
        isRefreshing: false,
      ));
    } catch (e) {
      if (state.months.isEmpty) {
        await _fallbackToCache(emit, fetchError: e.toString());
      } else {
        emit(state.copyWith(isRefreshing: false, refreshError: e.toString()));
      }
    }
  }

  Future<void> _fallbackToCache(Emitter<RecapState> emit,
      {required String fetchError}) async {
    try {
      final cached = await _repository.loadCached();
      if (cached.isNotEmpty) {
        emit(state.copyWith(
          status: RecapStatus.success,
          months: cached,
          selectedIndex: _defaultIndex(cached.length),
          fromSource: false,
          isRefreshing: false,
          refreshError: fetchError,
        ));
        return;
      }
    } catch (_) {
      // fall through to failure
    }
    emit(state.copyWith(
      status: RecapStatus.failure,
      isRefreshing: false,
      error: fetchError,
    ));
  }

  void _onMonthSelected(MonthSelected event, Emitter<RecapState> emit) {
    // Allow index == months.length: the not-yet-data-ready placeholder month
    // shown one step past the last real month.
    if (event.index < 0 || event.index > state.months.length) return;
    emit(state.copyWith(selectedIndex: event.index));
  }
}
