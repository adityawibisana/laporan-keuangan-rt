import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'auth_service.dart';
import 'desktop_auth_service.dart';
import 'mobile_auth_service.dart';

/// Picks the right sign-in implementation for the current platform.
AuthService createAuthService() {
  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  return isDesktop ? DesktopAuthService() : MobileAuthService();
}
