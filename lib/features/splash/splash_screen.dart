import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeIn = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _scaleIn = Tween<double>(begin: 0.88, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();

    final authState = ref.read(authProvider);
    if (authState is! AuthLoading) {
      _navigateAfterDelay(authState);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigateAfterDelay(AuthState authState) {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev is AuthLoading && next is! AuthLoading) {
        _navigateAfterDelay(next);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Iridescent radial glow — bottom-centre origin
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, 0.6),
                  radius: 1.4,
                  colors: [
                    Color(0x282C7DFF),
                    Color(0x127B5CF0),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Secondary glow — top-left
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.7),
                  radius: 0.9,
                  colors: [
                    Color(0x147B5CF0),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Centre content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Glass logo pill
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 22),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0x40FFFFFF), Color(0x14FFFFFF)],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppColors.glassBorder, width: 1),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x30FFFFFF),
                                blurRadius: 40,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'HDRezka',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2.0,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      'TV',
                      style: TextStyle(
                        color: Colors.white.withAlpha(80),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 6,
                      ),
                    ),

                    const SizedBox(height: 64),

                    // Loading indicator — thin glass arc
                    _GlassLoader(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass loading indicator ────────────────────────────────────────────────────

class _GlassLoader extends StatefulWidget {
  @override
  State<_GlassLoader> createState() => _GlassLoaderState();
}

class _GlassLoaderState extends State<_GlassLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, _) => CircularProgressIndicator(
          value: null,
          strokeWidth: 2,
          color: Colors.white.withAlpha(160),
          backgroundColor: Colors.white.withAlpha(25),
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}
