import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart'
    show AccessCredentials, AccessToken, authenticatedClient;
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'auth_service.dart';

/// Android/iOS sign-in using the classic (Activity-based) google_sign_in v6
/// flow. We intentionally avoid v7 here: its Credential Manager flow fails on
/// some OEM ROMs (e.g. Vivo/FuntouchOS) with "CredentialSelector: Unexpected
/// type of request", flashing the picker and hanging. The v6 flow is broadly
/// compatible. The authorized googleapis client is built directly from the
/// access token.
class MobileAuthService implements AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: authScopes,
    serverClientId: AppConfig.serverClientId,
  );

  @override
  bool get isAvailable => true;

  @override
  Future<AuthSession> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw AuthException('Sign-in cancelled');
      }

      final tokens = await account.authentication;
      final accessToken = tokens.accessToken;
      if (accessToken == null) {
        throw AuthException('No access token returned');
      }

      final client = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            accessToken,
            DateTime.now().toUtc().add(const Duration(minutes: 55)),
          ),
          null, // no refresh token from google_sign_in
          authScopes,
        ),
      );

      return AuthSession(
        email: account.email,
        displayName: account.displayName,
        client: client,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException('Sign-in failed: $e');
    }
  }

  @override
  Future<void> signOut() => _googleSignIn.signOut();
}
