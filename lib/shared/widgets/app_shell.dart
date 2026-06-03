import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Shell wrapping every ShellRoute screen.
///
/// Focus model:
///   • Nav-bar items live in [_navBarFocus] (a FocusNode, not a FocusScopeNode).
///   • Content lives below in the same scope — Flutter's default traversal
///     order (top-to-bottom, reading-order) handles left/right/up/down inside.
///   • ArrowDown on the last focused nav item → move to content (_contentKey).
///   • ArrowUp from content at scroll-top → move back to nav bar.
///   • Back/Escape in content → move back to nav bar.
///
/// Screens call [AppShell.focusNavBar] to hand focus up.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _mainRoutes = ['/', '/search'];
  static const _mainIcons  = [Icons.home_filled, Icons.search_rounded];
  static const _mainLabels = ['Главная', 'Поиск'];

  static const _catRoutes = ['/films', '/series', '/cartoons', '/anime'];
  static const _catLabels = ['Фильмы', 'Сериалы', 'Мультфильмы', 'Аниме'];

  /// Move focus to the nav bar from any descendant.
  static void focusNavBar(BuildContext context) {
    context.findAncestorStateOfType<_AppShellState>()?._focusNavBar();
  }

  /// Move focus to the content area from any descendant.
  static void focusContent(BuildContext context) {
    context.findAncestorStateOfType<_AppShellState>()?._focusContent();
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Focus node for the entire nav bar row — requesting it focuses the bar.
  final _navBarFocus = FocusScopeNode(debugLabel: 'nav-bar');
  // Key on the content subtree so we can find its first focusable child.
  final _contentKey  = GlobalKey();

  @override
  void dispose() {
    _navBarFocus.dispose();
    super.dispose();
  }

  void _focusNavBar() {
    if (!_navBarFocus.hasFocus) {
      _navBarFocus.requestFocus();
    }
  }

  void _focusContent() {
    final ctx = _contentKey.currentContext;
    if (ctx == null) return;
    final scope = FocusScope.of(ctx);
    // Restore the last focused child, or move to the scope itself so Flutter
    // falls through to the first autofocus descendant.
    if (!scope.hasFocus) {
      scope.requestFocus();
    }
  }

  String _selectedRoute(String location) {
    if (location.startsWith('/profile')) return '/profile';
    for (final r in [...AppShell._mainRoutes, ...AppShell._catRoutes]) {
      if (r == '/' ? location == '/' : location.startsWith(r)) return r;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _selectedRoute(location);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Nav bar ────────────────────────────────────────────────────
          FocusScope(
            node: _navBarFocus,
            // Intercept ArrowDown at the scope level so it always reaches
            // content regardless of which nav item currently has focus.
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _focusContent();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: _GlassTopBar(
              selectedRoute: selected,
              mainRoutes: AppShell._mainRoutes,
              mainIcons:  AppShell._mainIcons,
              mainLabels: AppShell._mainLabels,
              catRoutes:  AppShell._catRoutes,
              catLabels:  AppShell._catLabels,
            ),
          ),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: Focus(
              // Intercept Back/Escape bubbling up from content.
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.goBack ||
                     event.logicalKey == LogicalKeyboardKey.escape ||
                     event.logicalKey == LogicalKeyboardKey.browserBack)) {
                  _focusNavBar();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: KeyedSubtree(
                key: _contentKey,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liquid Glass top bar ───────────────────────────────────────────────────────

class _GlassTopBar extends StatelessWidget {
  final String selectedRoute;
  final List<String> mainRoutes;
  final List<IconData> mainIcons;
  final List<String> mainLabels;
  final List<String> catRoutes;
  final List<String> catLabels;

  const _GlassTopBar({
    required this.selectedRoute,
    required this.mainRoutes,
    required this.mainIcons,
    required this.mainLabels,
    required this.catRoutes,
    required this.catLabels,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TvSafe.navBarHeight,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x60000000), Color(0x28000000)],
              ),
              border: Border(
                bottom: BorderSide(color: AppColors.glassBorder, width: 0.5),
              ),
            ),
            child: Stack(
              children: [
                // Iridescent top rim
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Color(0x60FFFFFF),
                          Color(0xA0FFFFFF),
                          Color(0x60FFFFFF),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(TvSafe.h, TvSafe.v - 20, TvSafe.h, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _LogoButton(),
                      const SizedBox(width: 44),

                      for (var i = 0; i < mainRoutes.length; i++)
                        _NavItem(
                          icon: mainIcons[i],
                          label: mainLabels[i],
                          selected: selectedRoute == mainRoutes[i],
                          onSelect: () => context.go(mainRoutes[i]),
                        ),

                      Container(
                        width: 1, height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: AppColors.glassBorder,
                      ),

                      for (var i = 0; i < catRoutes.length; i++)
                        _NavItem(
                          label: catLabels[i],
                          selected: selectedRoute == catRoutes[i],
                          onSelect: () => context.go(catRoutes[i]),
                        ),

                      const Spacer(),
                      _AuthItem(selected: selectedRoute == '/profile'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── HDRezka logo button ────────────────────────────────────────────────────────

class _LogoButton extends StatefulWidget {
  @override
  State<_LogoButton> createState() => _LogoButtonState();
}

class _LogoButtonState extends State<_LogoButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          context.go('/');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => context.go('/'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : Colors.transparent,
              width: 2,
            ),
            boxShadow: _focused
                ? const [BoxShadow(color: Color(0x40FFFFFF), blurRadius: 16)]
                : null,
          ),
          child: const Text(
            'HDRezka',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Nav item ───────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  const _NavItem({
    this.icon,
    required this.label,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(_focused ? 50 : 30),
                      Colors.white.withAlpha(_focused ? 20 : 10),
                    ],
                  )
                : null,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected
                      ? AppColors.glassBorder
                      : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(color: Color(0x45FFFFFF), blurRadius: 16),
                    BoxShadow(color: AppColors.accentGlow, blurRadius: 20, spreadRadius: -4),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon,
                    color: active ? Colors.white : AppColors.onSurfaceMuted,
                    size: 18),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.onSurfaceMuted,
                  fontSize: 15,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 7),
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 6)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Profile button ─────────────────────────────────────────────────────────────

class _AuthItem extends StatefulWidget {
  final bool selected;
  const _AuthItem({required this.selected});

  @override
  State<_AuthItem> createState() => _AuthItemState();
}

class _AuthItemState extends State<_AuthItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _focused;

    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          context.go('/profile');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => context.go('/profile'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: active
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withAlpha(_focused ? 50 : 30),
                      Colors.white.withAlpha(_focused ? 20 : 10),
                    ],
                  )
                : null,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected
                      ? AppColors.glassBorder
                      : Colors.transparent,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(color: Color(0x45FFFFFF), blurRadius: 16),
                    BoxShadow(color: AppColors.accentGlow, blurRadius: 20, spreadRadius: -4),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_rounded,
                  color: active ? Colors.white : AppColors.onSurfaceMuted,
                  size: 17),
              const SizedBox(width: 7),
              Text(
                'Профиль',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.onSurfaceMuted,
                  fontSize: 15,
                  fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (widget.selected) ...[
                const SizedBox(width: 7),
                Container(
                  width: 5, height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.accentGlow, blurRadius: 6)],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
