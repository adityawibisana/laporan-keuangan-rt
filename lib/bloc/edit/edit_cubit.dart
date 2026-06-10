import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/sheet_editor.dart';

enum EditStatus { loading, ready, saving, error }

class EditState extends Equatable {
  final EditStatus status;
  final TabGrid? grid;
  final String? error;

  /// Bumps each time a save succeeds, so the UI can react (snackbar).
  final int savedTick;

  const EditState({
    this.status = EditStatus.loading,
    this.grid,
    this.error,
    this.savedTick = 0,
  });

  EditState copyWith({
    EditStatus? status,
    TabGrid? grid,
    String? error,
    int? savedTick,
  }) {
    return EditState(
      status: status ?? this.status,
      grid: grid ?? this.grid,
      error: error,
      savedTick: savedTick ?? this.savedTick,
    );
  }

  @override
  List<Object?> get props => [status, grid, error, savedTick];
}

class EditCubit extends Cubit<EditState> {
  final SheetEditor _editor;

  EditCubit(this._editor) : super(const EditState());

  Future<void> loadTab(String title) async {
    emit(const EditState(status: EditStatus.loading));
    try {
      final grid = await _editor.loadTab(title);
      emit(EditState(status: EditStatus.ready, grid: grid));
    } catch (e) {
      emit(EditState(status: EditStatus.error, error: e.toString()));
    }
  }

  /// Saves [edits] to [title], then reloads so computed (formula) cells refresh.
  Future<void> save(String title, List<CellEdit> edits) async {
    emit(state.copyWith(status: EditStatus.saving));
    try {
      await _editor.saveCells(title, edits);
      final grid = await _editor.loadTab(title);
      emit(EditState(
        status: EditStatus.ready,
        grid: grid,
        savedTick: state.savedTick + 1,
      ));
    } catch (e) {
      emit(state.copyWith(status: EditStatus.ready, error: e.toString()));
    }
  }
}
