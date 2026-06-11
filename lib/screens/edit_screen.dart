import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderProxyBox;
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
        if (state.status == EditStatus.ready ||
            state.status == EditStatus.saving) {
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

  /// The single cell currently promoted to a live TextField, keyed "row_col".
  /// Every other cell renders as a cheap Text, which keeps scrolling smooth on
  /// wide/tall grids (a TextField per cell builds a heavy EditableText each).
  String? _editing;

  /// Drives horizontal scrolling so we can reveal the next column on IME "next".
  final ScrollController _hController = ScrollController();

  /// Focus for the single active editor. Shared because only one cell edits at
  /// a time; we drive focus manually (not `autofocus`) so it lands AFTER the
  /// target column is scrolled into view.
  final FocusNode _editFocus = FocusNode();

  @override
  void dispose() {
    _hController.dispose();
    _editFocus.dispose();
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
    final lockedDecoration = BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(4),
    );
    final lockedStyle = TextStyle(fontSize: 12, color: scheme.onSurfaceVariant);

    // TableView virtualizes BOTH axes — only the cells visible in the viewport
    // are built and painted. (The old horizontal SingleChildScrollView built
    // every column of every visible row, which is what made wide tabs janky.)
    return TableView.builder(
      horizontalDetails: ScrollableDetails.horizontal(controller: _hController),
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
          lockedDecoration,
          lockedStyle,
        ),
      ),
    );
  }

  /// Promotes [key] to the live editor (or clears it when null) and focuses it
  /// after the frame. Focus is driven manually (not via `autofocus`) so we
  /// control its timing relative to scrolling.
  void _startEditing(String? key) {
    setState(() => _editing = key);
    if (key == null) {
      _editFocus.unfocus();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  /// Handles the keyboard "next" action: move the editor to the next column
  /// immediately (so the cursor follows), re-grab focus to keep the keyboard up,
  /// then scroll that column fully into view. Because the editor is wrapped in a
  /// [_SwallowShowOnScreen], focusing it never scrolls the table itself, so our
  /// horizontal reveal runs uncontested (and nothing jumps vertically).
  void _moveToNext(String key) {
    final col = int.parse(key.split('_')[1]);
    setState(() => _editing = key);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _editFocus.requestFocus();
      _revealColumn(col).then((_) {
        if (mounted) _editFocus.requestFocus();
      });
    });
  }

  /// Scrolls horizontally so column [col] sits fully inside the viewport.
  /// Completes once the scroll animation (if any) finishes.
  Future<void> _revealColumn(int col) {
    if (!_hController.hasClients) return Future<void>.value();
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
    if ((target - pos.pixels).abs() <= 0.5) return Future<void>.value();
    return _hController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
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
    BoxDecoration lockedDecoration,
    TextStyle lockedStyle,
  ) {
    final row = widget.grid.rows[r];
    final cell = c < row.length ? row[c] : null;

    if (cell == null) return const SizedBox.shrink();

    if (cell.isEditable) {
      final key = '${r}_$c';
      final controller = widget.controllers[key];

      // Active editor: the one tapped cell. Autofocus and drop back to a Text
      // when focus leaves (tap elsewhere / scroll dismiss).
      if (_editing == key) {
        final nextKey = _nextEditableKey(r, c);
        return Padding(
          padding: const EdgeInsets.all(2),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SwallowShowOnScreen(
              child: TextField(
                controller: controller,
                focusNode: _editFocus,
                style: const TextStyle(fontSize: 12),
                textInputAction: nextKey != null
                    ? TextInputAction.next
                    : TextInputAction.done,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(),
                ),
                onTapOutside: (_) => _startEditing(null),
                // Suppress the default focus traversal so we control where the
                // caret lands (handled in onSubmitted).
                onEditingComplete: () {},
                // Action button: jump to the next editable column (or close the
                // keyboard if this is the last one), scrolling it fully into view.
                // We deliberately do NOT save here: saving reloads the grid and
                // rebuilds controllers, which would reset scroll/focus mid-entry.
                // Use the Save button in the app bar to persist all edits at once.
                onSubmitted: (_) {
                  if (nextKey == null) {
                    _startEditing(null); // last column → close the keyboard
                    return;
                  }
                  _autoDateOnEntry(nextKey);
                  _moveToNext(nextKey);
                },
              ),
            ),
          ),
        );
      }

      // Idle editable cell: a tappable, text-field-looking box (cheap to build).
      return GestureDetector(
        onTap: () => _startEditing(key),
        child: Container(
          margin: const EdgeInsets.all(2),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: idleDecoration,
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

/// Stops a descendant's `showOnScreen` from bubbling up to the [TableView].
///
/// A focused [TextField] (via `EditableText`) asks its ancestors to scroll its
/// caret into view whenever it gains focus or its position shifts. Inside the
/// grid that yanks the whole table — vertically, and in a way that fights the
/// horizontal column reveal we drive ourselves. Swallowing the request here
/// makes our [_GridEditorState._revealColumn] the only thing that scrolls the
/// grid, so column navigation is predictable.
class _SwallowShowOnScreen extends SingleChildRenderObjectWidget {
  const _SwallowShowOnScreen({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSwallowShowOnScreen();
}

class _RenderSwallowShowOnScreen extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // Intentionally do not forward to ancestors.
  }
}
