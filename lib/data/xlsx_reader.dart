import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// A minimal, read-only XLSX reader that returns each sheet as a grid of
/// cell strings using the *cached computed values* of formula cells.
///
/// We deliberately avoid the `excel` package here: it returns the formula text
/// (e.g. "SUM(...)") instead of the cached result for numeric formula cells,
/// which would break the recap totals. Reading `<v>` directly mirrors what
/// `openpyxl(data_only=True)` does on the Python side.
class XlsxWorkbook {
  /// Sheet name -> rows -> column cells (null for blank cells).
  final Map<String, List<List<String?>>> sheets;

  XlsxWorkbook(this.sheets);

  List<List<String?>>? sheet(String name) => sheets[name];

  static XlsxWorkbook decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final files = {for (final f in archive) f.name: f};

    String readXml(String path) {
      final f = files[path];
      if (f == null) {
        throw FormatException('XLSX missing entry: $path');
      }
      return utf8.decode(f.content as List<int>);
    }

    // 1. Shared strings table (cells with t="s" reference into this).
    final shared = <String>[];
    if (files.containsKey('xl/sharedStrings.xml')) {
      final doc = XmlDocument.parse(readXml('xl/sharedStrings.xml'));
      for (final si in doc.rootElement.findElements('si')) {
        // A shared string item may be split into multiple <t> runs.
        final sb = StringBuffer();
        for (final t in si.findAllElements('t')) {
          sb.write(t.innerText);
        }
        shared.add(sb.toString());
      }
    }

    // 2. Map sheet name -> relationship id, then rId -> file target.
    final wb = XmlDocument.parse(readXml('xl/workbook.xml'));
    final nameToRid = <String, String>{};
    for (final s in wb.rootElement.findAllElements('sheet')) {
      final name = s.getAttribute('name');
      final rid = s.getAttribute('r:id');
      if (name != null && rid != null) nameToRid[name] = rid;
    }

    final rels = XmlDocument.parse(readXml('xl/_rels/workbook.xml.rels'));
    final ridToTarget = <String, String>{};
    for (final r in rels.rootElement.findAllElements('Relationship')) {
      final id = r.getAttribute('Id');
      final target = r.getAttribute('Target');
      if (id != null && target != null) ridToTarget[id] = target;
    }

    // 3. Parse each sheet into a positional grid.
    final sheets = <String, List<List<String?>>>{};
    nameToRid.forEach((name, rid) {
      final target = ridToTarget[rid];
      if (target == null) return;
      final path =
          target.startsWith('/') ? target.substring(1) : 'xl/$target';
      if (!files.containsKey(path)) return;

      final doc = XmlDocument.parse(readXml(path));
      final rows = <List<String?>>[];
      for (final row in doc.rootElement.findAllElements('row')) {
        final cells = <String?>[];
        for (final c in row.findElements('c')) {
          final ref = c.getAttribute('r');
          final col = ref == null ? cells.length : _columnIndex(ref);
          while (cells.length < col) {
            cells.add(null);
          }
          cells.add(_cellValue(c, shared));
        }
        rows.add(cells);
      }
      sheets[name] = rows;
    });

    return XlsxWorkbook(sheets);
  }

  /// Resolve a cell's textual value, dereferencing shared strings and using the
  /// cached `<v>` for formula/number cells.
  static String? _cellValue(XmlElement c, List<String> shared) {
    final type = c.getAttribute('t');
    if (type == 's') {
      final v = c.getElement('v');
      if (v == null) return null;
      final idx = int.tryParse(v.innerText);
      return (idx != null && idx >= 0 && idx < shared.length)
          ? shared[idx]
          : null;
    }
    if (type == 'inlineStr') {
      final sb = StringBuffer();
      for (final t in c.findAllElements('t')) {
        sb.write(t.innerText);
      }
      return sb.toString();
    }
    // number, boolean, "str" (string formula result) -> use cached <v>.
    final v = c.getElement('v');
    return v?.innerText;
  }

  /// "C5" -> 2 (zero-based column index from the leading letters).
  static int _columnIndex(String ref) {
    var index = 0;
    for (final code in ref.codeUnits) {
      if (code >= 65 && code <= 90) {
        index = index * 26 + (code - 64);
      } else if (code >= 97 && code <= 122) {
        index = index * 26 + (code - 96);
      } else {
        break; // hit the row digits
      }
    }
    return index - 1;
  }
}
