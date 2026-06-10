import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/auth_service.dart';

enum AuthStatus { signedOut, signingIn, signedIn }

class AuthState extends Equatable {
  final AuthStatus status;
  final AuthSession? session;
  final String? error;

  const AuthState({
    this.status = AuthStatus.signedOut,
    this.session,
    this.error,
  });

  bool get isSignedIn => status == AuthStatus.signedIn && session != null;

  @override
  List<Object?> get props => [status, session?.email, error];
}

class AuthCubit extends Cubit<AuthState> {
  final AuthService _service;

  AuthCubit(this._service) : super(const AuthState());

  bool get isAvailable => _service.isAvailable;

  /// The authenticated session, if signed in (used by the editor to call the
  /// Sheets API).
  AuthSession? get session => state.session;

  Future<void> signIn() async {
    emit(const AuthState(status: AuthStatus.signingIn));
    try {
      final session = await _service.signIn();
      emit(AuthState(status: AuthStatus.signedIn, session: session));
    } catch (e) {
      emit(AuthState(status: AuthStatus.signedOut, error: e.toString()));
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    emit(const AuthState());
  }
}
