import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

// ── Public API ─────────────────────────────────────────────────────────────────

/// Shell that wraps every ShellRoute screen.
///
/// Layout: true Column — nav bar (fixed height) on top, content fills the rest.
/// Two explicit [FocusScopeNode]s:
///   • [_navScope]     — owns all nav-bar items
///   • [_contentScope] — owns the current screen
///
/// Boundary rules (handled here, screens need no arrowUp logic):
///   • Arrow-Down from nav bar  → content scope gets focus (first focusable)
///   • Arrow-Up   in content    → intercepted only when content is at scroll top
///                                → nav bar scope gets focus
///   • Back/Escape in content   → nav bar scope gets focus
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _mainRoutes = ['/', '/search'];
  static const _mainIcons  = [Icons.home_filled, Icons.search_rounded];
  static const _mainLabels = ['Главная', 'Поиск'];

  static const _catRoutes = ['/films', '/series', '/cartoons', '/anime'];
  static const _catLabels = ['Фильмы', 'Сериалы', 'Мультфильмы', 'Аниме'];

  /// Called by content to hand focus back to the nav bar.
  static void focusNavBar(BuildContext context) {
    context.findAncestorStateOfType<_AppShellState>()?._focusNavBar();
  }

  /// Called by nav bar to hand focus down to content.
  static void focusContent(BuildContext context) {
    context.findAncestorStateOfType<_AppShellState>()?._focusContent();
  }

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _navScope     = FocusScopeNode(debugLabel: 'NavBar');
  final _contentScope = FocusScopeNode(debugLabel: 'Content');

  @override
  void dispose() {
    _navScope.dispose();
    _contentScope.dispose();
    super.dispose();
  }

  void _focusNavBar() {
    // Move focus into the nav bar; it restores its last focused child.
    if (!_navScope.hasFocus) {
      FocusScope.of(context).setFirstFocus(_navScope);
    }
  }

  void _focusContent() {
    // Move focus into the content area; it restores its last focused child
    // or falls through to the first autofocus descendant.
    if (!_contentScope.hasFocus) {
      FocusScope.of(context).setFirstFocus(_contentScope);
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
          // ── Nav bar (fixed height, always on top) ──────────────────────
          FocusScope(
            node: _navScope,
            child: Focus(
              skipTraversal: true,
              onKeyEvent: (_, event) {
                // Arrow-Down: hand focus to content
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
          ),

          // ── Content area ───────────────────────────────────────────────
          Expanded(
            child: FocusScope(
              node: _contentScope,
              child: Focus(
                skipTraversal: true,
                onKeyEvent: (_, event) {
                  // Back/Escape always returns to nav bar
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.goBack ||
                       event.logicalKey == LogicalKeyboardKey.escape ||
                       event.logicalKey == LogicalKeyboardKey.browserBack)) {
                    _focusNavBar();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
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
