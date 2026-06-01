import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _emailFocus  = FocusNode();
  final _passFocus   = FocusNode();
  final _buttonFocus = FocusNode();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _buttonFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    await ref.read(authProvider.notifier).login(email, pass);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated) context.go('/');
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;
    final errorMsg  = authState is AuthError ? authState.message : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Iridescent background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4, -0.6),
                  radius: 1.4,
                  colors: [
                    Color(0x302C7DFF),
                    Color(0x187B5CF0),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: SizedBox(
              width: 460,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(44, 44, 44, 36),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x38FFFFFF), Color(0x12FFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        _Logo(),
                        const SizedBox(height: 36),

                        // CORS warning
                        if (kIsWeb) ...[
                          _GlassWarning(),
                          const SizedBox(height: 20),
                        ],

                        // Email
                        TextField(
                          controller: _emailCtrl,
                          focusNode: _emailFocus,
                          autofocus: true,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: const InputDecoration(labelText: 'Email'),
                          onSubmitted: (_) => FocusScope.of(context).requestFocus(_passFocus),
                        ),
                        const SizedBox(height: 18),

                        // Password
                        TextField(
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: const InputDecoration(labelText: 'Пароль'),
                          onSubmitted: (_) {
                            FocusScope.of(context).requestFocus(_buttonFocus);
                            _login();
                          },
                        ),
                        const SizedBox(height: 32),

                        // Login button — white glass pill
                        Focus(
                          focusNode: _buttonFocus,
                          child: _LoginButton(
                            isLoading: isLoading,
                            onPressed: _login,
                          ),
                        ),

                        // Error
                        if (errorMsg != null) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.red.withAlpha(80)),
                                ),
                                child: Text(
                                  errorMsg,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Skip
                        TextButton(
                          onPressed: () => context.go('/'),
                          style: TextButton.styleFrom(foregroundColor: AppColors.onSurfaceMuted),
                          child: const Text('Продолжить без входа', style: TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Logo ───────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'HDRezka',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Войдите для доступа к платному контенту',
          style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── CORS warning ───────────────────────────────────────────────────────────────

class _GlassWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withAlpha(80)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Вход недоступен в браузере из-за CORS. '
                  'Используйте Android TV.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Login button ───────────────────────────────────────────────────────────────

class _LoginButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  State<_LoginButton> createState() => _LoginButtonState();
}

class _LoginButtonState extends State<_LoginButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFD0DCFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: _focused ? const Color(0x80FFFFFF) : const Color(0x30FFFFFF),
                blurRadius: _focused ? 24 : 12,
              ),
              if (_focused)
                const BoxShadow(
                  color: AppColors.accentGlow,
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
            ],
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : Colors.white.withAlpha(100),
              width: _focused ? 2.5 : 1,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : const Text(
                    'Войти',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
