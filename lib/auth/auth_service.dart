import 'package:googleapis/sheets/v4.dart' show SheetsApi;
import 'package:googleapis_auth/googleapis_auth.dart' show AuthClient;

/// Scopes requested when signing in to edit the sheet.
const authScopes = <String>[
  SheetsApi.spreadsheetsScope, // read/write spreadsheets
  'email',
];

/// A signed-in session: who the user is plus an authenticated client usable
/// with the googleapis Sheets API.
class AuthSession {
  final String email;
  final String? displayName;
  final AuthClient client;

  AuthSession({
    required this.email,
    required this.displayName,
    required this.client,
  });
}

/// Abstracts Google sign-in so the app can use the native flow on mobile and a
/// loopback OAuth flow on desktop, behind one interface.
abstract class AuthService {
  /// Whether sign-in is possible on this platform / configuration.
  bool get isAvailable;

  /// Interactively signs in. Throws [AuthException] on failure or cancel.
  Future<AuthSession> signIn();

  Future<void> signOut();
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}
