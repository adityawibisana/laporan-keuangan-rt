import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/recap.dart';
import 'recap_extractor.dart';
import 'xlsx_reader.dart';

/// Downloads the configured Google Sheet (as .xlsx) and extracts the monthly
/// recaps. Throws on network / parse failure so the caller can fall back to
/// cached data.
class SheetFetcher {
  final http.Client _client;
  SheetFetcher({http.Client? client}) : _client = client ?? http.Client();

  Future<List<MonthRecap>> fetch() async {
    final uri = AppConfig.xlsxExportUri;
    final res = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception(
        'Sheet download failed (HTTP ${res.statusCode}). '
        'Is the sheet shared as "Anyone with the link can view"?',
      );
    }

    final workbook = XlsxWorkbook.decode(res.bodyBytes);
    final months = RecapExtractor.extract(workbook);
    if (months.isEmpty) {
      throw Exception('No monthly data found in the sheet.');
    }
    return months;
  }
}
