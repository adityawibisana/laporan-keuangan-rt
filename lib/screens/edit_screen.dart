import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/edit/edit_cubit.dart';
import '../data/sheet_editor.dart';
import '../l10n/app_localizations.dart';
import '../utils/months.dart';

/// Edit screen for a single `+month` (income) or `-month` (expense) tab.
/// Loads the tab from the sheet, lets the user change non-formula cells, and
/// pushes the edits back via the Sheets API. Requires a signed-in [EditCubit]
/// provided above it.
class EditScreen extends StatefulWidget {
  final int initialMonthIndex;
  const EditScreen({super.key, required this.initialMonthIndex});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late int _monthIndex;
  bool _isIncome = true;

  /// Controllers for editable cells, keyed "row_col".
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _monthIndex = widget.initialMonthIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String get _title =>
      _isIncome ? incomeTab(_monthIndex) : expenseTab(_monthIndex);

  void _load() => context.read<EditCubit>().loadTab(_title);

  void _rebuildControllers(TabGrid grid) {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (var r = 0; r < grid.rows.length; r++) {
      for (var c = 0; c < grid.rows[r].length; c++) {
        final cell = grid.rows[r][c];
        if (cell.isEditable) {
          _controllers['${r}_$c'] = TextEditingController(text: cell.value);
        }
      }
    }
  }

  List<CellEdit> _collectEdits(TabGrid grid) {
    final edits = <CellEdit>[];
    for (var r = 0; r < grid.rows.length; r++) {
      for (var c = 0; c < grid.rows[r].length; c++) {
        final cell = grid.rows[r][c];
        if (!cell.isEditable) continue;
        final ctrl = _controllers['${r}_$c'];
        if (ctrl != null && ctrl.text != cell.value) {
          edits.add(CellEdit(row: r, col: c, value: ctrl.text));
        }
      }
    }
    return edits;
  }

  void _save(TabGrid grid) {
    final edits = _collectEdits(grid);
    final l10n = AppLocalizations.of(context);
    if (edits.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.noChanges)));
      return;
    }
    context.read<EditCubit>().save(_title, edits);
  }

  /// Save triggered inline from the keyboard action button while moving across
  /// columns. Stays quiet when nothing changed (no "no changes" snackbar).
  void _saveChanged(TabGrid grid) {
    final edits = _collectEdits(grid);
    if (edits.isNotEmpty) context.read<EditCubit>().save(_title, edits);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return BlocConsumer<EditCubit, EditState>(
      listenWhen: (p, c) =>
          p.savedTick != c.savedTick || (c.error != null && p.error != c.error),
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.error != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
                SnackBar(content: Text('${l10n.saveFailed}: ${state.error}')));
        } else if (state.savedTick > 0) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.saved)));
        }
      },
      builder: (context, state) {
        if (state.status == EditStatus.ready || state.status == EditStatus.saving) {
          if (state.grid != null) _rebuildControllers(state.grid!);
        }
        final saving = state.status == EditStatus.saving;

        return Scaffold(
          appBar: AppBar(
            title: Text('${l10n.editTitle} $_title'),
            actions: [
              if (saving)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.save),
                  tooltip: l10n.save,
                  onPressed: state.grid == null ? null : () => _save(state.grid!),
                ),
            ],
          ),
          body: Column(
            children: [
              _Selectors(
                monthIndex: _monthIndex,
                isIncome: _isIncome,
                incomeLabel: l10n.income,
                expenseLabel: l10n.expenses,
                monthLabel: l10n.month,
                onMonth: (i) {
                  setState(() => _monthIndex = i);
                  _load();
                },
                onType: (income) {
                  setState(() => _isIncome = income);
                  _load();
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.lockedNotice,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, EditState state) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case EditStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case EditStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(state.error ?? '', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.retry),
                ),
              ],
            ),
          ),
        );
      case EditStatus.ready:
      case EditStatus.saving:
        final grid = state.grid;
        if (grid == null) return const SizedBox.shrink();
        return _GridEditor(
          grid: grid,
          controllers: _controllers,
          onSave: () => _saveChanged(grid),
        );
    }
  }
}

class _Selectors extends StatelessWidget {
  final int monthIndex;
  final bool isIncome;
  final String incomeLabel;
  final String expenseLabel;
  final String monthLabel;
  final ValueChanged<int> onMonth;
  final ValueChanged<bool> onType;

  const _Selectors({
    required this.monthIndex,
    required this.isIncome,
    required this.incomeLabel,
    required this.expenseLabel,
    required this.monthLabel,
    required this.onMonth,
    required this.onType,
  });

  @override
  Widget build(BuildContext context) {
    final localeName = Localizations.localeOf(context).toString();
    final year = DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          DropdownButton<int>(
            value: monthIndex,
            onChanged: (v) => v == null ? null : onMonth(v),
            items: [
              for (var i = 0; i < monthKeys.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    DateFormat.MMMM(localeName).format(DateTime(year, i + 1)),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(incomeLabel),
                  icon: const Icon(Icons.add, size: 16),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(expenseLabel),
                  icon: const Icon(Icons.remove, size: 16),
                ),
              ],
              selected: {isIncome},
              onSelectionChanged: (s) => onType(s.first),
              showSelectedIcon: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridEditor extends StatefulWidget {
  final TabGrid grid;
  final Map<String, TextEditingController> controllers;

  /// Called when the user commits a cell with the keyboard action button.
  final VoidCallback onSave;

  const _GridEditor({
    required this.grid,
    required this.controllers,
    required this.onSave,
  });

  @override
  State<_GridEditor> createState() => _GridEditorState();
}

class _GridEditorState extends State<_GridEditor> {
  static const _cellWidth = 130.0;

  /// The single cell currently promoted to a live TextField, keyed "row_col".
  /// Every other cell renders as a cheap Text, which keeps scrolling smooth on
  /// wide/tall grids (a TextField per cell builds a heavy EditableText each).
  String? _editing;

  @override
  Widget build(BuildContext context) {
    final cols = widget.grid.columnCount;
    // Build rows lazily so a large padded tab doesn't construct everything at
    // once; the fixed-width SizedBox lets the vertical ListView live inside the
    // horizontal scroll view.
    final rowWidth = cols * (_cellWidth + 4) + 16;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: rowWidth,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: widget.grid.rows.length,
          itemExtent: 48,
          itemBuilder: (context, r) => Row(
            children: [
              for (var c = 0; c < cols; c++) _cell(context, r, c),
            ],
          ),
        ),
      ),
    );
  }

  /// The next editable cell to the right of (r, c) in the same row, or null if
  /// this is the last editable column in the row.
  String? _nextEditableKey(int r, int c) {
    final row = widget.grid.rows[r];
    for (var nc = c + 1; nc < row.length; nc++) {
      if (row[nc].isEditable) return '${r}_$nc';
    }
    return null;
  }

  Widget _cell(BuildContext context, int r, int c) {
    final row = widget.grid.rows[r];
    final cell = c < row.length ? row[c] : null;
    final scheme = Theme.of(context).colorScheme;

    if (cell == null) {
      return const SizedBox(width: _cellWidth, height: 44);
    }

    if (cell.isEditable) {
      final key = '${r}_$c';
      final controller = widget.controllers[key];

      // Active editor: the one tapped cell. Autofocus and drop back to a Text
      // when focus leaves (tap elsewhere / scroll dismiss).
      if (_editing == key) {
        final nextKey = _nextEditableKey(r, c);
        return Container(
          width: _cellWidth,
          padding: const EdgeInsets.all(2),
          child: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(fontSize: 12),
            textInputAction:
                nextKey != null ? TextInputAction.next : TextInputAction.done,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onTapOutside: (_) => setState(() => _editing = null),
            // Suppress the default focus traversal so we control where the
            // caret lands (handled in onSubmitted).
            onEditingComplete: () {},
            // Action button: save the row's changes, then jump to the next
            // editable column (or close the keyboard if this is the last one).
            onSubmitted: (_) {
              widget.onSave();
              setState(() => _editing = nextKey);
            },
          ),
        );
      }

      // Idle editable cell: a tappable, text-field-looking box (cheap to build).
      return GestureDetector(
        onTap: () => setState(() => _editing = key),
        child: Container(
          width: _cellWidth,
          height: 40,
          margin: const EdgeInsets.all(2),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            controller?.text ?? cell.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      );
    }

    // Locked / computed cell.
    return Container(
      width: _cellWidth,
      height: 40,
      margin: const EdgeInsets.all(2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        cell.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
