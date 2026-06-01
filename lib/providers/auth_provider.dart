import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hdrezka_tv/core/api/hdrezka_api_lib.dart';
import 'auth_state.dart';
import 'session_provider.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
  name: 'authProvider',
);

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthLoading()) {
    _checkSavedSession();
  }

  final Ref _ref;

  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('dle_user_id');
      final pwHash = prefs.getString('dle_password');
      if (userId != null && userId.isNotEmpty && pwHash != null && pwHash.isNotEmpty) {
        final session = _ref.read(sessionProvider);
        session.cookies['dle_user_id'] = userId;
        session.cookies['dle_password'] = pwHash;
        state = const AuthAuthenticated();
      } else {
        state = const AuthUnauthenticated();
      }
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final session = _ref.read(sessionProvider);
      final ok = await session.login(email, password);
      if (ok) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dle_user_id', session.cookies['dle_user_id'] ?? '');
        await prefs.setString('dle_password', session.cookies['dle_password'] ?? '');
        state = const AuthAuthenticated();
      } else {
        state = const AuthError('Неверный логин или пароль');
      }
    } on LoginFailed catch (e) {
      state = AuthError(e.message);
    } catch (e) {
      state = AuthError('Ошибка сети: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dle_user_id');
    await prefs.remove('dle_password');
    final session = _ref.read(sessionProvider);
    session.cookies.remove('dle_user_id');
    session.cookies.remove('dle_password');
    state = const AuthUnauthenticated();
  }
}
