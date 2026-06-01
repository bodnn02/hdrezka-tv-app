import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/hdrezka_browse.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/catalog_provider.dart';
import '../../shared/widgets/app_shell.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/poster_card.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  final String title;
  final String category;

  const CategoryScreen({
    super.key,
    required this.title,
    required this.category,
  });

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  static const _allSortFilters = [
    (label: 'Сейчас смотрят', value: 'watching'),
    (label: 'Новые',          value: 'last'),
    (label: 'Популярные',     value: 'popular'),
    (label: 'Скоро',          value: 'soon'),
  ];

  // animation category doesn't have a "soon" section on HDrezka
  static const _animationSortFilters = [
    (label: 'Сейчас смотрят', value: 'watching'),
    (label: 'Новые',          value: 'last'),
    (label: 'Популярные',     value: 'popular'),
  ];

  List<({String label, String value})> get _sortFilters =>
      widget.category == 'animation' ? _animationSortFilters : _allSortFilters;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode  = FocusNode();
  final Map<int, FocusNode> _cardFocusNodes = {};

  // Overlay-based filter panel so it renders above the app nav bar
  OverlayEntry? _filterOverlay;

  bool get _filterOpen => _filterOverlay != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _removeFilterOverlay();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    for (final n in _cardFocusNodes.values) { n.dispose(); }
    super.dispose();
  }

  bool _isLoadingMoreGuard = false;

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 600 && !_isLoadingMoreGuard) {
      _isLoadingMoreGuard = true;
      ref.read(catalogProvider(widget.category).notifier).loadMore().then((_) {
        _isLoadingMoreGuard = false;
      });
    }
  }

  FocusNode _cardFocus(int index) =>
      _cardFocusNodes.putIfAbsent(index, () => FocusNode());

  KeyEventResult _handleGridKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp &&
        _scrollController.hasClients &&
        _scrollController.offset <= 0) {
      AppShell.focusTopBar(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _removeFilterOverlay() {
    _filterOverlay?.remove();
    _filterOverlay = null;
  }

  void _openFilterPanel() {
    if (_filterOpen) return;
    final notifier = ref.read(catalogProvider(widget.category).notifier);
    final genres = categoryGenres[widget.category] ?? {};

    _filterOverlay = OverlayEntry(
      builder: (_) {
        // Re-read current filters every rebuild so sliders stay in sync
        final currentFilters = ref.read(catalogProvider(widget.category)).filters;
        return _FilterPanel(
          category: widget.category,
          filters: currentFilters,
          genres: genres,
          onGenre: (g) {
            _cardFocusNodes.clear();
            notifier.setGenre(g);
            _closeFilterPanel();
          },
          onYearFrom: (y) {
            _cardFocusNodes.clear();
            notifier.setYearFrom(y);
            _filterOverlay?.markNeedsBuild();
          },
          onYearTo: (y) {
            notifier.setYearTo(y);
            _filterOverlay?.markNeedsBuild();
          },
          onClose: _closeFilterPanel,
        );
      },
    );

    // rootNavigator: true → Overlay принадлежит MaterialApp, выше AppShell
    Navigator.of(context, rootNavigator: true).overlay!.insert(_filterOverlay!);
    setState(() {});
  }

  void _closeFilterPanel() {
    _removeFilterOverlay();
    if (mounted) setState(() {});
  }

  void _toggleFilterPanel() {
    if (_filterOpen) {
      _closeFilterPanel();
    } else {
      _openFilterPanel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(catalogProvider(widget.category));
    final notifier = ref.read(catalogProvider(widget.category).notifier);
    final filters = state.filters;
    final genres = categoryGenres[widget.category] ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        onKeyEvent: _handleGridKey,
        child: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              // ── Header row ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(64, 24, 64, 0),
                child: Row(
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(width: 24),

                    // Sort filter tabs
                    _SortFilterTabs(
                      filters: _sortFilters.map((f) => f.label).toList(),
                      values:  _sortFilters.map((f) => f.value).toList(),
                      selectedValue: filters.sortFilter,
                      onSelect: (v) {
                        _cardFocusNodes.clear();
                        notifier.setSortFilter(v);
                      },
                    ),

                    const Spacer(),

                    // Search field — fixed width, no layout animation
                    _SearchField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (q) {
                        _cardFocusNodes.clear();
                        notifier.setSearchQuery(q);
                        setState(() {}); // rebuild to update clear button
                      },
                      onClear: () {
                        _searchController.clear();
                        _cardFocusNodes.clear();
                        notifier.setSearchQuery('');
                        setState(() {});
                      },
                    ),

                    const SizedBox(width: 12),

                    // Filter toggle button
                    _FilterButton(
                      active: filters.hasActiveFilters || _filterOpen,
                      badge: filters.hasActiveFilters,
                      onTap: _toggleFilterPanel,
                    ),
                  ],
                ),
              ),

              // ── Active filter chips ──────────────────────────────────────
              if (filters.hasActiveFilters)
                Padding(
                  padding: const EdgeInsets.fromLTRB(64, 10, 64, 0),
                  child: _ActiveFilterChips(
                    filters: filters,
                    genres: genres,
                    onRemoveGenre: () {
                      _cardFocusNodes.clear();
                      notifier.setGenre(null);
                    },
                    onRemoveYear: () {
                      _cardFocusNodes.clear();
                      notifier.setYearFrom(null);
                      notifier.setYearTo(null);
                    },
                    onClearAll: () {
                      _searchController.clear();
                      _cardFocusNodes.clear();
                      notifier.clearFilters();
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // ── Content grid ─────────────────────────────────────────────
              Expanded(child: _buildContent(state, notifier)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(CatalogState state, CatalogNotifier notifier) {
    if (state.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 64),
        child: LoadingShimmerGrid(rows: 3, cols: 7),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
            const SizedBox(height: 8),
            _GlassButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onTap: notifier.refresh,
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.onSurfaceMuted),
            const SizedBox(height: 12),
            Text(
              'Ничего не найдено',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(64, 0, 64, 48),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: PosterCard.cardWidth / PosterCard.cardHeight,
      ),
      itemCount: state.items.length + (state.isLoadingMore ? 7 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        }
        return PosterCard(
          item: state.items[index],
          focusNode: _cardFocus(index),
          autofocus: index == 0,
          onFocused: () {
            final row = index ~/ 7;
            final rowOffset = row * (PosterCard.cardHeight + 16);
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                rowOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sort filter tabs
// ─────────────────────────────────────────────────────────────────────────────

class _SortFilterTabs extends StatelessWidget {
  final List<String> filters;
  final List<String> values;
  final String selectedValue;
  final void Function(String) onSelect;

  const _SortFilterTabs({
    required this.filters,
    required this.values,
    required this.selectedValue,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(filters.length, (i) => _FilterTab(
        label: filters[i],
        selected: selectedValue == values[i],
        onSelect: () => onSelect(values[i]),
      )),
    );
  }
}

class _FilterTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  const _FilterTab({required this.label, required this.selected, required this.onSelect});

  @override
  State<_FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<_FilterTab> {
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
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: widget.selected
                ? AppColors.accent.withAlpha(220)
                : active ? AppColors.glassFillHover : AppColors.glassFill,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected ? AppColors.accent : AppColors.glassBorder,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 16)]
                : widget.selected
                    ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 12, spreadRadius: -2)]
                    : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.onSurfaceMuted,
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field — fixed 280 px wide, no width animation
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() => _focused = widget.focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    return SizedBox(
      width: 280,
      height: 44,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: _focused ? AppColors.glassFillHover : AppColors.glassFill,
          border: Border.all(
            color: _focused ? AppColors.glassBorderFocus : AppColors.glassBorder,
            width: _focused ? 2 : 1,
          ),
          boxShadow: _focused
              ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 16)]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_rounded,
                size: 18,
                color: _focused ? Colors.white : AppColors.onSurfaceMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  onChanged: widget.onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: AppColors.accent,
                  decoration: InputDecoration(
                    hintText: 'Поиск...',
                    hintStyle: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.only(bottom: 2),
                  ),
                ),
              ),
              if (hasText)
                GestureDetector(
                  onTap: widget.onClear,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, size: 16, color: AppColors.onSurfaceMuted),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter toggle button
// ─────────────────────────────────────────────────────────────────────────────

class _FilterButton extends StatefulWidget {
  final bool active;
  final bool badge;
  final VoidCallback onTap;

  const _FilterButton({required this.active, required this.badge, required this.onTap});

  @override
  State<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<_FilterButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.active
                    ? AppColors.accent.withAlpha(200)
                    : _focused ? AppColors.glassFillHover : AppColors.glassFill,
                border: Border.all(
                  color: _focused
                      ? AppColors.glassBorderFocus
                      : widget.active ? AppColors.accent : AppColors.glassBorder,
                  width: _focused ? 2 : 1,
                ),
                boxShadow: (_focused || widget.active)
                    ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 16)]
                    : null,
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: widget.active || _focused ? Colors.white : AppColors.onSurfaceMuted,
              ),
            ),
            if (widget.badge)
              Positioned(
                top: -2, right: -2,
                child: Container(
                  width: 10, height: 10,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active filter chips row
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveFilterChips extends StatelessWidget {
  final CatalogFilters filters;
  final Map<String, String> genres;
  final VoidCallback onRemoveGenre;
  final VoidCallback onRemoveYear;
  final VoidCallback onClearAll;

  const _ActiveFilterChips({
    required this.filters,
    required this.genres,
    required this.onRemoveGenre,
    required this.onRemoveYear,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (filters.genre != null)
          _Chip(
            label: genres[filters.genre] ?? filters.genre!,
            icon: Icons.category_rounded,
            onRemove: onRemoveGenre,
          ),
        if (filters.yearFrom != null)
          _Chip(
            label: filters.yearTo != null && filters.yearTo != filters.yearFrom
                ? '${filters.yearFrom}–${filters.yearTo}'
                : '${filters.yearFrom}',
            icon: Icons.calendar_today_rounded,
            onRemove: onRemoveYear,
          ),
        if (filters.searchQuery.isNotEmpty)
          _Chip(
            label: '"${filters.searchQuery}"',
            icon: Icons.search_rounded,
            onRemove: null,
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClearAll,
          child: const Text(
            'Сбросить всё',
            style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onRemove;

  const _Chip({required this.label, required this.icon, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: AppColors.accent.withAlpha(40),
        border: Border.all(color: AppColors.accent.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded, size: 13, color: AppColors.onSurfaceMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter side panel — rendered via Overlay to appear above the nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatefulWidget {
  final String category;
  final CatalogFilters filters;
  final Map<String, String> genres;
  final void Function(String?) onGenre;
  final void Function(int?) onYearFrom;
  final void Function(int?) onYearTo;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.category,
    required this.filters,
    required this.genres,
    required this.onGenre,
    required this.onYearFrom,
    required this.onYearTo,
    required this.onClose,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  int? _localYearFrom;
  int? _localYearTo;

  static const int _minYear = 1950;
  static final int _maxYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _localYearFrom = widget.filters.yearFrom;
    _localYearTo   = widget.filters.yearTo;
    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 240));
    _slide = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _fade  = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _anim.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fade,
        child: GestureDetector(
          onTap: _close,
          child: Container(
            color: Colors.black54,
            child: Align(
              alignment: Alignment.centerRight,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(_slide),
                child: GestureDetector(
                  onTap: () {},   // absorb taps inside panel
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                      child: Container(
                        width: 380,
                        height: double.infinity,
                        decoration: const BoxDecoration(
                          color: Color(0xCC0C0C10),
                          border: Border(
                            left: BorderSide(color: AppColors.glassBorder),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 20, 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 20, color: Colors.white),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Фильтры',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: _close,
                                      child: Container(
                                        width: 36, height: 36,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.glassFill,
                                          border: Border.all(color: AppColors.glassBorder),
                                        ),
                                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Divider(color: Color(0x30FFFFFF), height: 1),
                              ),

                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                  children: [
                                    if (widget.genres.isNotEmpty) ...[
                                      _SectionTitle('Жанр'),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _PanelChip(
                                            label: 'Все',
                                            selected: widget.filters.genre == null,
                                            onTap: () => widget.onGenre(null),
                                          ),
                                          ...widget.genres.entries.map((e) => _PanelChip(
                                            label: e.value,
                                            selected: widget.filters.genre == e.key,
                                            onTap: () => widget.onGenre(e.key),
                                          )),
                                        ],
                                      ),
                                      const SizedBox(height: 28),
                                    ],

                                    _SectionTitle('Год выпуска'),
                                    const SizedBox(height: 16),

                                    _YearRow(
                                      label: 'С',
                                      value: _localYearFrom,
                                      min: _minYear,
                                      max: _localYearTo ?? _maxYear,
                                      onChanged: (y) {
                                        setState(() => _localYearFrom = y);
                                        widget.onYearFrom(y);
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    _YearRow(
                                      label: 'По',
                                      value: _localYearTo,
                                      min: _localYearFrom ?? _minYear,
                                      max: _maxYear,
                                      onChanged: (y) {
                                        setState(() => _localYearTo = y);
                                        widget.onYearTo(y);
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    _SectionTitle('Быстрый выбор года'),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8, runSpacing: 8,
                                      children: _quickYearPresets(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _quickYearPresets() {
    final now = DateTime.now().year;
    final presets = [
      (label: 'Этот год',    from: now,    to: now),
      (label: 'Прошлый год', from: now -1, to: now -1),
      (label: '2020–е',      from: 2020,   to: now),
      (label: '2010–е',      from: 2010,   to: 2019),
      (label: '2000–е',      from: 2000,   to: 2009),
      (label: '90–е',        from: 1990,   to: 1999),
      (label: '80–е',        from: 1980,   to: 1989),
    ];
    return presets.map((p) => _PanelChip(
      label: p.label,
      selected: _localYearFrom == p.from && _localYearTo == p.to,
      onTap: () {
        setState(() { _localYearFrom = p.from; _localYearTo = p.to; });
        widget.onYearFrom(p.from);
        widget.onYearTo(p.to);
      },
    )).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.onSurfaceMuted,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    ),
  );
}

class _PanelChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PanelChip({required this.label, required this.selected, required this.onTap});

  @override
  State<_PanelChip> createState() => _PanelChipState();
}

class _PanelChipState extends State<_PanelChip> {
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
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: widget.selected
                ? AppColors.accent.withAlpha(220)
                : active ? AppColors.glassFillHover : AppColors.glassFill,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected ? AppColors.accent : AppColors.glassBorder,
              width: _focused ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 10, spreadRadius: -2)]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.onSurfaceMuted,
              fontSize: 13,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _YearRow extends StatelessWidget {
  final String label;
  final int? value;
  final int min;
  final int max;
  final ValueChanged<int?> onChanged;

  const _YearRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label, style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${value ?? min}',
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              activeTrackColor: AppColors.accent,
              inactiveTrackColor: AppColors.glassFill,
              thumbColor: Colors.white,
              overlayColor: AppColors.accentGlow,
            ),
            child: Slider(
              value: (value ?? min).toDouble().clamp(min.toDouble(), max.toDouble()),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: (max - min).clamp(1, 9999),
              onChanged: (v) => onChanged(v.round()),
              onChangeEnd: (v) {
                if (v.round() == min && label == 'С') onChanged(null);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic glass button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GlassButton({required this.label, required this.icon, required this.onTap});

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: _focused ? AppColors.accent.withAlpha(200) : AppColors.glassFill,
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : AppColors.glassBorder,
              width: _focused ? 2 : 1,
            ),
            boxShadow: _focused
                ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 20)]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(widget.label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
