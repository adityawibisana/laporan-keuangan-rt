import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;

/// One cell of an editable tab grid.
class GridCell {
  final String value;

  /// Formula cells are shown read-only so we never overwrite a formula with its
  /// computed value.
  final bool isFormula;

  GridCell(this.value, {required this.isFormula});

  bool get isEditable => !isFormula;
}

/// A tab loaded for editing: a rectangular grid of cells.
class TabGrid {
  final String title;
  final List<List<GridCell>> rows;

  TabGrid({required this.title, required this.rows});

  int get columnCount =>
      rows.fold(0, (max, r) => r.length > max ? r.length : max);
}

/// A single edited cell, addressed by zero-based row/column.
class CellEdit {
  final int row;
  final int col;
  final String value;
  CellEdit({required this.row, required this.col, required this.value});
}

/// Reads and writes a worksheet tab through the Google Sheets API using the
/// signed-in user's credentials.
class SheetEditor {
  final sheets.SheetsApi _api;
  final String _spreadsheetId;

  SheetEditor({required AuthClient client, required String spreadsheetId})
      : _api = sheets.SheetsApi(client),
        // ignore: prefer_initializing_formals
        _spreadsheetId = spreadsheetId;

  /// Loads [title] as a grid, combining unformatted values (for editing) with a
  /// formula mask (to lock computed cells).
  Future<TabGrid> loadTab(String title) async {
    // Raw values, so number inputs edit as plain numbers.
    final valueRange = await _api.spreadsheets.values.get(
      _spreadsheetId,
      title,
      valueRenderOption: 'UNFORMATTED_VALUE',
    );
    final values = valueRange.values ?? const [];

    // Which cells are formulas (so we can lock them).
    final meta = await _api.spreadsheets.get(
      _spreadsheetId,
      ranges: [title],
      includeGridData: true,
      $fields: 'sheets/data/rowData/values/userEnteredValue/formulaValue',
    );
    final rowData =
        meta.sheets?.firstOrNull?.data?.firstOrNull?.rowData ?? const [];

    bool isFormula(int r, int c) {
      if (r >= rowData.length) return false;
      final cells = rowData[r].values;
      if (cells == null || c >= cells.length) return false;
      return cells[c].userEnteredValue?.formulaValue != null;
    }

    // The Sheets API trims each row to its last non-empty cell (and omits empty
    // rows entirely), so a sparse tab comes back ragged. Pad every row out to a
    // common width so all columns and rows of the used range are present and
    // editable — not just the cells that happen to hold a value.
    var width = 0;
    for (final raw in values) {
      if (raw.length > width) width = raw.length;
    }

    final rows = <List<GridCell>>[];
    for (var r = 0; r < values.length; r++) {
      final raw = values[r];
      final cells = <GridCell>[];
      for (var c = 0; c < width; c++) {
        final value = c < raw.length ? _stringify(raw[c]) : '';
        cells.add(GridCell(value, isFormula: isFormula(r, c)));
      }
      rows.add(cells);
    }
    return TabGrid(title: title, rows: rows);
  }

  /// Writes [edits] back to [title]. Uses USER_ENTERED so typed numbers are
  /// stored as numbers and any typed formulas are honored.
  Future<void> saveCells(String title, List<CellEdit> edits) async {
    if (edits.isEmpty) return;
    final data = edits
        .map((e) => sheets.ValueRange(
              range: '$title!${_a1(e.row, e.col)}',
              values: [
                [e.value]
              ],
            ))
        .toList();

    await _api.spreadsheets.values.batchUpdate(
      sheets.BatchUpdateValuesRequest(
        valueInputOption: 'USER_ENTERED',
        data: data,
      ),
      _spreadsheetId,
    );
  }

  static String _stringify(Object? v) {
    if (v == null) return '';
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  /// (row, col) zero-based -> A1 like "C5".
  static String _a1(int row, int col) {
    var c = col;
    final letters = StringBuffer();
    do {
      letters.write(String.fromCharCode(65 + (c % 26)));
      c = (c ~/ 26) - 1;
    } while (c >= 0);
    final reversed = letters.toString().split('').reversed.join();
    return '$reversed${row + 1}';
  }
}
