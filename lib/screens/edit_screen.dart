import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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
  bool _isIncome = false;

  /// Controllers for editable cells, keyed "row_col".
  final Map<String, TextEditingController> _controllers = {};

  /// The grid the controllers were last built for. Used to rebuild controllers
  /// only when the grid instance actually changes (a new load/save result), not
  /// on every state emission (e.g. entering `saving`), which would needlessly
  /// dispose and recreate every controller — and yank the bottom edit bar's
  /// controller out from under it mid-edit.
  TabGrid? _controllersGrid;

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
              SnackBar(content: Text('${l10n.saveFailed}: ${state.error}')),
            );
        } else if (state.savedTick > 0) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.saved)));
        }
      },
      builder: (context, state) {
        if ((state.status == EditStatus.ready ||
                state.status == EditStatus.saving) &&
            state.grid != null &&
            !identical(state.grid, _controllersGrid)) {
          _rebuildControllers(state.grid!);
          _controllersGrid = state.grid;
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
                  onPressed: state.grid == null
                      ? null
                      : () => _save(state.grid!),
                ),
            ],
          ),
          body: SafeArea(
            // AppBar handles the top inset; guard the bottom so the grid and
            // keyboard "next" navigation aren't clipped by the system nav bar.
            top: false,
            child: Column(
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
        return _GridEditor(grid: grid, controllers: _controllers);
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
                  value: false,
                  label: Text(expenseLabel),
                  icon: const Icon(Icons.remove, size: 16),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(incomeLabel),
                  icon: const Icon(Icons.add, size: 16),
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

  const _GridEditor({required this.grid, required this.controllers});

  @override
  State<_GridEditor> createState() => _GridEditorState();
}

class _GridEditorState extends State<_GridEditor> {
  static const _cellWidth = 130.0;

  /// Column / row pixel extents. The +4 covers the 2px margin on each side of a
  /// cell so the bordered boxes don't touch.
  static const _colExtent = _cellWidth + 4;
  static const _rowExtent = 48.0;
  static const _columnSpan = TableSpan(
    extent: FixedTableSpanExtent(_colExtent),
  );
  static const _rowSpan = TableSpan(extent: FixedTableSpanExtent(_rowExtent));

  /// The selected cell, keyed "row_col". Cells are NOT edited inline; tapping a
  /// cell selects it and its content is edited in the persistent bar at the
  /// bottom (like the Google Sheets app). This keeps every grid cell a cheap
  /// Text — no EditableText to slow scrolling — and keeps the keyboard open
  /// while moving between cells (the bar is the one and only text field).
  ///
  /// It's a [ValueNotifier] rather than plain state so that changing the
  /// selection (tap, or "next" during data entry) does NOT rebuild the whole
  /// grid via setState. Instead, only the two cells whose selected-state flips
  /// rebuild (and the bottom bar). That's what keeps repeated "next" presses
  /// snappy on wide grids.
  final ValueNotifier<String?> _selected = ValueNotifier<String?>(null);

  /// Drives horizontal scrolling so we can reveal the selected cell.
  final ScrollController _hController = ScrollController();

  /// Focus for the bottom edit bar — the single text field for the whole grid.
  final FocusNode _barFocus = FocusNode();

  @override
  void dispose() {
    _selected.dispose();
    _hController.dispose();
    _barFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = widget.grid.rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final cols = widget.grid.columnCount;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Build the cell decorations and locked-text style once per build and share
    // the instances across every cell. Allocating them per-cell while scrolling
    // is wasteful, and reusing identical decorations lets the framework skip
    // rebuilding box painters for cells that haven't changed.
    final idleDecoration = BoxDecoration(
      border: Border.all(color: theme.dividerColor),
      borderRadius: BorderRadius.circular(4),
    );
    final selectedDecoration = BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.10),
      border: Border.all(color: scheme.primary, width: 2),
      borderRadius: BorderRadius.circular(4),
    );
    final lockedDecoration = BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    );
    final lockedStyle = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    // TableView virtualizes BOTH axes — only the cells visible in the viewport
    // are built and painted. (The old horizontal SingleChildScrollView built
    // every column of every visible row, which is what made wide tabs janky.)
    //
    // Note: this build does NOT read `_selected`, so changing the selection
    // never rebuilds the TableView. Cells subscribe to `_selected` themselves
    // and only the ones whose selection flips repaint.
    return Column(
      children: [
        Expanded(
          child: TableView.builder(
            horizontalDetails: ScrollableDetails.horizontal(
              controller: _hController,
            ),
            columnCount: cols,
            rowCount: rows.length,
            pinnedRowCount: 1, // keep the header row visible while scrolling
            columnBuilder: (_) => _columnSpan,
            rowBuilder: (_) => _rowSpan,
            cellBuilder: (context, vicinity) => TableViewCell(
              child: _cell(
                vicinity.row,
                vicinity.column,
                idleDecoration,
                selectedDecoration,
                lockedDecoration,
                lockedStyle,
              ),
            ),
          ),
        ),
        // Only the bar reacts to selection changes here; the grid above stays put.
        ValueListenableBuilder<String?>(
          valueListenable: _selected,
          builder: (context, _, _) => _editBar(context),
        ),
      ],
    );
  }

  /// Selects [key], moves the caret to the end of its value, focuses the bottom
  /// edit bar (opening the keyboard), and scrolls the cell into view.
  void _select(String key) {
    _selected.value = key;
    final ctrl = widget.controllers[key];
    if (ctrl != null) {
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barFocus.requestFocus();
    });
    _revealColumn(int.parse(key.split('_')[1]));
  }

  /// Keyboard "next" / Next button: select the next editable cell in the row
  /// (closing the keyboard if there is none). The bar stays focused throughout,
  /// so the keyboard never closes between cells.
  void _moveToNext() {
    final key = _selected.value;
    if (key == null) return;
    final parts = key.split('_');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);
    final nextKey = _nextEditableKey(r, c);
    if (nextKey == null) {
      _done();
      return;
    }
    _autoDateOnEntry(nextKey);
    _selected.value = nextKey;
    final ctrl = widget.controllers[nextKey];
    if (ctrl != null) {
      ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _barFocus.requestFocus();
    });
    _revealColumn(int.parse(nextKey.split('_')[1]));
  }

  /// Clears the selection and dismisses the keyboard.
  void _done() {
    _barFocus.unfocus();
    _selected.value = null;
  }

  /// Scrolls horizontally so column [col] sits fully inside the viewport. Defers
  /// to a post-frame so it runs after any selection rebuild.
  void _revealColumn(int col) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hController.hasClients) return;
      final pos = _hController.position;
      const pad = 12.0; // a little breathing room so the column isn't flush
      final left = col * _colExtent;
      final right = left + _colExtent;
      var target = pos.pixels;
      if (right + pad > pos.pixels + pos.viewportDimension) {
        target = right + pad - pos.viewportDimension;
      } else if (left - pad < pos.pixels) {
        target = left - pad;
      }
      target = target.clamp(0.0, pos.maxScrollExtent);
      if ((target - pos.pixels).abs() > 0.5) {
        _hController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// The bottom edit bar (Sheets-style): one persistent text field bound to the
  /// selected cell's controller. Because it never leaves the tree, the keyboard
  /// stays up while moving between cells, and it lives outside the grid so it
  /// can't scroll the grid around.
  Widget _editBar(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final key = _selected.value;
    final controller = key == null ? null : widget.controllers[key];
    final hasSel = controller != null;

    var label = '';
    var hasNext = false;
    if (key != null) {
      final parts = key.split('_');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      label = _headerLabel(c);
      hasNext = _nextEditableKey(r, c) != null;
    }

    return Material(
      elevation: 8,
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            if (label.isNotEmpty) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: _barFocus,
                readOnly: !hasSel,
                textInputAction: hasNext
                    ? TextInputAction.next
                    : TextInputAction.done,
                onSubmitted: (_) => hasNext ? _moveToNext() : _done(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hasSel ? null : 'Ketuk sel untuk mengedit',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
            IconButton(
              tooltip: hasNext ? 'Berikutnya' : 'Selesai',
              onPressed: !hasSel ? null : (hasNext ? _moveToNext : _done),
              icon: Icon(hasNext ? Icons.east : Icons.check),
            ),
          ],
        ),
      ),
    );
  }

  /// The header (grid row 0) text for column [c], used to label the edit bar.
  String _headerLabel(int c) {
    if (widget.grid.rows.isEmpty) return '';
    final header = widget.grid.rows[0];
    return c < header.length ? header[c].value.trim() : '';
  }

  /// Column index whose header (grid row 0) equals [name], case-insensitive,
  /// or null if there is no such column.
  int? _columnByHeader(String name) {
    if (widget.grid.rows.isEmpty) return null;
    final header = widget.grid.rows[0];
    final target = name.toLowerCase();
    for (var c = 0; c < header.length; c++) {
      if (header[c].value.trim().toLowerCase() == target) return c;
    }
    return null;
  }

  /// When navigation lands on the "Tanggal Pengeluaran" column, pre-fill today's
  /// date — but only for a data row whose "Global" total has a value, and only
  /// when the date cell is still empty (don't clobber a date the user set).
  void _autoDateOnEntry(String key) {
    final parts = key.split('_');
    final r = int.parse(parts[0]);
    final c = int.parse(parts[1]);
    if (r == 0) return; // header row

    final dateCol = _columnByHeader('tanggal pengeluaran');
    if (dateCol == null || c != dateCol) return;
    final globalCol = _columnByHeader('global');
    if (globalCol == null) return;

    final row = widget.grid.rows[r];
    final globalText = globalCol < row.length
        ? row[globalCol].value.trim()
        : '';
    final globalNum = double.tryParse(globalText);
    final globalHasValue =
        globalText.isNotEmpty && (globalNum == null || globalNum != 0);
    if (!globalHasValue) return;

    final ctrl = widget.controllers[key];
    if (ctrl == null || ctrl.text.trim().isNotEmpty) return;
    // Match the DD/MM/YYYY format the date column is displayed/edited in.
    ctrl.text = DateFormat('dd/MM/yyyy').format(DateTime.now());
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

  Widget _cell(
    int r,
    int c,
    BoxDecoration idleDecoration,
    BoxDecoration selectedDecoration,
    BoxDecoration lockedDecoration,
    TextStyle lockedStyle,
  ) {
    final row = widget.grid.rows[r];
    final cell = c < row.length ? row[c] : null;

    if (cell == null) return const SizedBox.shrink();

    if (cell.isEditable) {
      final key = '${r}_$c';
      // Editing happens in the bottom bar. Each editable cell watches the shared
      // `_selected` notifier and only rebuilds when ITS own selected-state
      // flips — so moving the selection repaints just the two affected cells,
      // not the whole viewport. Every cell is a plain Text (no EditableText),
      // which is what keeps a wide/tall grid scrolling smoothly.
      return _EditableCell(
        cellKey: key,
        controller: widget.controllers[key],
        fallback: cell.value,
        selection: _selected,
        onTap: () => _select(key),
        idleDecoration: idleDecoration,
        selectedDecoration: selectedDecoration,
      );
    }

    // Locked / computed cell.
    return Container(
      margin: const EdgeInsets.all(2),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: lockedDecoration,
      child: Text(
        cell.value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: lockedStyle,
      ),
    );
  }
}

/// A single editable grid cell. Tapping it selects the cell (editing happens in
/// the bottom bar). It listens to the shared [selection] notifier but only
/// rebuilds when its own selected/unselected state changes, so moving the
/// selection across the grid never rebuilds cells that aren't directly involved.
///
/// While selected, the cell mirrors the bottom bar's controller live (via a
/// [ListenableBuilder]); otherwise it's a plain [Text] showing the controller's
/// current text (so an edited value stays visible after moving on).
class _EditableCell extends StatefulWidget {
  final String cellKey;
  final TextEditingController? controller;
  final String fallback;
  final ValueNotifier<String?> selection;
  final VoidCallback onTap;
  final BoxDecoration idleDecoration;
  final BoxDecoration selectedDecoration;

  const _EditableCell({
    required this.cellKey,
    required this.controller,
    required this.fallback,
    required this.selection,
    required this.onTap,
    required this.idleDecoration,
    required this.selectedDecoration,
  });

  @override
  State<_EditableCell> createState() => _EditableCellState();
}

class _EditableCellState extends State<_EditableCell> {
  static const _textStyle = TextStyle(fontSize: 12);

  late bool _isSelected;

  @override
  void initState() {
    super.initState();
    _isSelected = widget.selection.value == widget.cellKey;
    widget.selection.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(_EditableCell old) {
    super.didUpdateWidget(old);
    // TableView reuses cell elements as you scroll, so the same State can be
    // handed a different cell. Re-point the listener and re-evaluate selection.
    if (!identical(old.selection, widget.selection)) {
      old.selection.removeListener(_onSelectionChanged);
      widget.selection.addListener(_onSelectionChanged);
    }
    _isSelected = widget.selection.value == widget.cellKey;
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    final selected = widget.selection.value == widget.cellKey;
    if (selected != _isSelected) setState(() => _isSelected = selected);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.all(2),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration:
            _isSelected ? widget.selectedDecoration : widget.idleDecoration,
        child: _isSelected && controller != null
            ? ListenableBuilder(
                listenable: controller,
                builder: (context, _) => Text(
                  controller.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _textStyle,
                ),
              )
            : Text(
                controller?.text ?? widget.fallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _textStyle,
              ),
      ),
    );
  }
}
