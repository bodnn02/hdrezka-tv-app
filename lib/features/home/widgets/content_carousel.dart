import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/hdrezka_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../shared/widgets/loading_shimmer.dart';
import '../../../shared/widgets/poster_card.dart';

class ContentCarousel extends ConsumerStatefulWidget {
  final String title;
  final String category;
  final String filter;

  const ContentCarousel({
    super.key,
    required this.title,
    required this.category,
    this.filter = 'watching',
  });

  @override
  ConsumerState<ContentCarousel> createState() => _ContentCarouselState();
}

class _ContentCarouselState extends ConsumerState<ContentCarousel> {
  final _scrollController = ScrollController();
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes.values) node.dispose();
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode());

  void _scrollToIndex(int index) {
    const cardWidth = LandscapeCard.cardWidth + 14.0;
    final offset = (index * cardWidth).clamp(
      0.0,
      _scrollController.hasClients ? _scrollController.position.maxScrollExtent : double.infinity,
    );
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      categoryContentProvider((category: widget.category, page: 1, filter: widget.filter)),
    );

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 32, 0, 14),
            child: Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SizedBox(
            height: LandscapeCard.cardHeight + 8,
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 64),
                child: LoadingShimmerRow(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Text('Ошибка загрузки', style: Theme.of(context).textTheme.bodyMedium),
              ),
              data: (items) => _CarouselList(
                items: items,
                scrollController: _scrollController,
                focusNodeFor: _focusNodeFor,
                onFocused: _scrollToIndex,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselList extends StatelessWidget {
  final List<AdvancedSearchResult> items;
  final ScrollController scrollController;
  final FocusNode Function(int) focusNodeFor;
  final void Function(int) onFocused;

  const _CarouselList({
    required this.items,
    required this.scrollController,
    required this.focusNodeFor,
    required this.onFocused,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 64),
      itemCount: items.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: LandscapeCard(
          item: items[index],
          focusNode: focusNodeFor(index),
          onFocused: () => onFocused(index),
        ),
      ),
    );
  }
}
