import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/hdrezka_browse.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../shared/widgets/focusable_card.dart';
import '../../../shared/widgets/loading_shimmer.dart';

class CollectionsCarousel extends ConsumerStatefulWidget {
  const CollectionsCarousel({super.key});

  @override
  ConsumerState<CollectionsCarousel> createState() => _CollectionsCarouselState();
}

class _CollectionsCarouselState extends ConsumerState<CollectionsCarousel> {
  final _scrollController = ScrollController();
  final Map<int, FocusNode> _focusNodes = {};

  static const double _cardWidth  = 260.0;
  static const double _cardHeight = 160.0;

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes.values) node.dispose();
    super.dispose();
  }

  FocusNode _focusNodeFor(int index) =>
      _focusNodes.putIfAbsent(index, () => FocusNode());

  void _scrollToIndex(int index) {
    const cardWidth = _cardWidth + 14.0;
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
    final async = ref.watch(collectionsProvider);

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 32, 0, 14),
            child: Text(
              'Подборки',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          SizedBox(
            height: _cardHeight + 8,
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 64),
                child: LoadingShimmerRow(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 64),
                child: Text('Ошибка загрузки', style: Theme.of(context).textTheme.bodyMedium),
              ),
              data: (collections) => collections.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      controller: _scrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 64),
                      itemCount: collections.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: _CollectionCard(
                          item: collections[index],
                          focusNode: _focusNodeFor(index),
                          onFocused: () => _scrollToIndex(index),
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

class _CollectionCard extends StatelessWidget {
  final CollectionResult item;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;

  static const double _cardWidth  = 260.0;
  static const double _cardHeight = 160.0;

  const _CollectionCard({
    required this.item,
    this.focusNode,
    this.onFocused,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      focusNode: focusNode,
      onFocusChange: (f) { if (f) onFocused?.call(); },
      borderRadius: BorderRadius.circular(16),
      onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
      child: SizedBox(
        width: _cardWidth,
        height: _cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              item.image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.image,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
                      placeholder: (_, _) => Container(color: AppColors.surfaceCard),
                    )
                  : Container(color: AppColors.surfaceVariant),

              // Dark gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x20000000), Color(0xCC000000)],
                    ),
                  ),
                ),
              ),

              // Title + count
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.itemCount != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              '${item.itemCount} фильмов',
                              style: const TextStyle(
                                color: AppColors.onSurfaceMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Collection icon badge
              Positioned(
                top: 10, right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(
                        Icons.collections_bookmark_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
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
