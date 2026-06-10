import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App configuration sourced from the bundled `.env` file (see `.env.example`).
///
/// The only setting today is [sumberData] — the Google Sheets URL the app pulls
/// its financial data from. A forker changes `.env` to point at their own sheet.
class AppConfig {
  /// Fallback used if `.env` is missing or `SUMBER_DATA` is unset, so the app
  /// still runs out of the box.
  static const _fallbackUrl =
      'https://docs.google.com/spreadsheets/d/1zARd7ZwwGzY0pHopR3YQLIK_3clFbR5Rc40atLySVgw';

  /// The raw URL exactly as the user configured it.
  static String get sumberData {
    final v = dotenv.maybeGet('SUMBER_DATA');
    return (v == null || v.trim().isEmpty) ? _fallbackUrl : v.trim();
  }

  /// The spreadsheet ID extracted from [sumberData] (the part after
  /// `/spreadsheets/d/`). Throws [FormatException] if the URL has no ID.
  static String get spreadsheetId {
    final match =
        RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(sumberData);
    if (match == null) {
      throw FormatException(
        'SUMBER_DATA does not look like a Google Sheets URL: $sumberData',
      );
    }
    return match.group(1)!;
  }

  /// URL that downloads the whole workbook as .xlsx (all tabs, with computed
  /// values). This is what the app fetches and parses.
  static Uri get xlsxExportUri => Uri.parse(
        'https://docs.google.com/spreadsheets/d/$spreadsheetId/export?format=xlsx',
      );

  // --- OAuth (editing) configuration ---

  static String? get desktopClientId =>
      dotenv.maybeGet('GOOGLE_DESKTOP_CLIENT_ID')?.trim();

  static String? get desktopClientSecret =>
      dotenv.maybeGet('GOOGLE_DESKTOP_CLIENT_SECRET')?.trim();

  /// Web OAuth client ID used as the serverClientId for mobile sign-in.
  static String? get serverClientId {
    final v = dotenv.maybeGet('GOOGLE_SERVER_CLIENT_ID')?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// Whether desktop sign-in is configured (a Desktop-app OAuth client present).
  static bool get hasDesktopOAuth =>
      (desktopClientId?.isNotEmpty ?? false) &&
      (desktopClientSecret?.isNotEmpty ?? false);
}
