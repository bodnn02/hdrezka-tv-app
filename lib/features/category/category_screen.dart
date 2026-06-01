import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/category_provider.dart';
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
  static const _filters = [
    (label: 'Сейчас смотрят', value: 'watching'),
    (label: 'Новые',          value: 'last'),
    (label: 'Популярные',     value: 'popular'),
    (label: 'Скоро',          value: 'soon'),
  ];

  int _filterIndex = 0;
  final _scrollController = ScrollController();
  final Map<int, FocusNode> _focusNodes = {};

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (_scrollController.hasClients && _scrollController.offset <= 0) {
        AppShell.focusTopBar(context);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String get _currentFilter => _filters[_filterIndex].value;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes.values) { node.dispose(); }
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode());

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      categoryContentProvider((category: widget.category, page: 1, filter: _currentFilter)),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Focus(
        onKeyEvent: _handleKey,
        child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top padding for glass bar
            const SizedBox(height: 80),

            // Title + filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 24, 64, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(width: 32),
                  _FilterTabs(
                    filters: _filters.map((f) => f.label).toList(),
                    selectedIndex: _filterIndex,
                    onSelect: (i) {
                      setState(() {
                        _filterIndex = i;
                        _focusNodes.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Content grid
            Expanded(
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 64),
                  child: _GridShimmer(),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Ошибка загрузки',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                data: (items) => GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(64, 0, 64, 48),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: PosterCard.cardWidth / PosterCard.cardHeight,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) => PosterCard(
                    item: items[index],
                    focusNode: _focusNodeFor(index),
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final void Function(int) onSelect;

  const _FilterTabs({
    required this.filters,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(filters.length, (i) {
        return _FilterTab(
          label: filters[i],
          selected: selectedIndex == i,
          onSelect: () => onSelect(i),
        );
      }),
    );
  }
}

class _FilterTab extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelect;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onSelect,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: widget.selected
                ? AppColors.accent.withAlpha(220)
                : active
                    ? AppColors.glassFillHover
                    : AppColors.glassFill,
            border: Border.all(
              color: _focused
                  ? AppColors.glassBorderFocus
                  : widget.selected
                      ? AppColors.accent
                      : AppColors.glassBorder,
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
              fontSize: 14,
              fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _GridShimmer extends StatelessWidget {
  const _GridShimmer();

  @override
  Widget build(BuildContext context) {
    return const LoadingShimmerGrid(rows: 3, cols: 7);
  }
}
