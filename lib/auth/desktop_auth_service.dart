import 'dart:convert';

import 'package:googleapis_auth/auth_io.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

/// Desktop (Windows/macOS/Linux) sign-in using the installed-app OAuth flow:
/// a browser opens for consent and the token is captured on a loopback URL.
/// `google_sign_in` does not support desktop, so this path enables editing
/// while developing on Windows.
class DesktopAuthService implements AuthService {
  AuthClient? _client;

  @override
  bool get isAvailable => AppConfig.hasDesktopOAuth;

  @override
  Future<AuthSession> signIn() async {
    if (!isAvailable) {
      throw AuthException(
        'Desktop editing is not configured. Set GOOGLE_DESKTOP_CLIENT_ID and '
        'GOOGLE_DESKTOP_CLIENT_SECRET in .env.',
      );
    }

    final clientId =
        ClientId(AppConfig.desktopClientId!, AppConfig.desktopClientSecret!);

    try {
      final client = await clientViaUserConsent(
        clientId,
        [...authScopes, 'openid'],
        (url) {
          // Fire-and-forget: open the consent page in the system browser.
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
      );
      _client = client;
      final email = await _fetchEmail(client);
      return AuthSession(email: email, displayName: null, client: client);
    } catch (e) {
      throw AuthException('Sign-in failed: $e');
    }
  }

  @override
  Future<void> signOut() async {
    _client?.close();
    _client = null;
  }

  Future<String> _fetchEmail(AuthClient client) async {
    try {
      final res = await client
          .get(Uri.parse('https://openidconnect.googleapis.com/v1/userinfo'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (data['email'] as String?) ?? 'signed in';
      }
    } catch (_) {
      // ignore — email is cosmetic
    }
    return 'signed in';
  }
}
