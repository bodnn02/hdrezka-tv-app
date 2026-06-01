import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/hdrezka_api.dart';
import '../../core/api/hdrezka_types.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/content_provider.dart';
import '../../shared/widgets/focusable_card.dart';
import '../../shared/widgets/glass_surface.dart';
import 'widgets/episode_selector.dart';
import 'widgets/translator_selector.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  final String contentUrl;
  const DetailsScreen({super.key, required this.contentUrl});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  int? _selectedTranslatorId;
  int? _selectedSeason;
  int? _selectedEpisode;

  void _play() {
    final params = <String, String>{
      'url': Uri.encodeComponent(widget.contentUrl),
    };
    if (_selectedSeason       != null) params['season']   = '$_selectedSeason';
    if (_selectedEpisode      != null) params['episode']  = '$_selectedEpisode';
    if (_selectedTranslatorId != null) params['tr']       = '$_selectedTranslatorId';
    context.push(Uri(path: '/player', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(contentProvider(widget.contentUrl));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            color: AppColors.accent,
            strokeWidth: 2,
          ),
        ),
        error: (e, _) => Center(
          child: Text('Ошибка: $e', style: const TextStyle(color: Colors.white)),
        ),
        data: (api) => _DetailsContent(
          api: api,
          contentUrl: widget.contentUrl,
          selectedTranslatorId: _selectedTranslatorId,
          onTranslatorChanged: (id) => setState(() => _selectedTranslatorId = id),
          onEpisodeSelected: (s, e, tr) => setState(() {
            _selectedSeason = s;
            _selectedEpisode = e;
            _selectedTranslatorId = tr;
          }),
          onPlay: _play,
        ),
      ),
    );
  }
}

class _DetailsContent extends ConsumerWidget {
  final HdRezkaApi api;
  final String contentUrl;
  final int? selectedTranslatorId;
  final void Function(int) onTranslatorChanged;
  final void Function(int, int, int) onEpisodeSelected;
  final VoidCallback onPlay;

  const _DetailsContent({
    required this.api,
    required this.contentUrl,
    required this.selectedTranslatorId,
    required this.onTranslatorChanged,
    required this.onEpisodeSelected,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameAsync        = ref.watch(FutureProvider((r) => api.name).future);
    final typeAsync        = ref.watch(FutureProvider((r) => api.type).future);
    final ratingAsync      = ref.watch(FutureProvider((r) => api.rating).future);
    final thumbAsync       = ref.watch(FutureProvider((r) => api.thumbnailHQ).future);
    final descAsync        = ref.watch(FutureProvider((r) => api.description).future);
    final yearAsync        = ref.watch(FutureProvider((r) => api.releaseYear).future);
    final translatorsAsync = ref.watch(translatorsProvider(contentUrl));
    final episodesAsync    = ref.watch(episodesInfoProvider(contentUrl));
    final isBookmarked     = ref.watch(bookmarksProvider).any((b) => b.url == contentUrl);

    return Stack(
      children: [
        // Full-bleed background poster (very dim)
        FutureBuilder<String>(
          future: thumbAsync,
          builder: (_, snap) {
            if (snap.data == null || snap.data!.isEmpty) return const SizedBox.shrink();
            return Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(imageUrl: snap.data!, fit: BoxFit.cover),
                  Container(color: Colors.black.withAlpha(180)),
                  // Strong blur
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            );
          },
        ),

        // Gradient overlay on top of blurred background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withAlpha(200),
                  AppColors.background.withAlpha(230),
                ],
              ),
            ),
          ),
        ),

        // Scrollable content
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: 80, left: 60, right: 60, bottom: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Poster ────────────────────────────────────────────────
              FutureBuilder<String>(
                future: thumbAsync,
                builder: (_, snap) {
                  final url = snap.data ?? '';
                  return _PosterWithGlass(url: url);
                },
              ),
              const SizedBox(width: 52),

              // ── Info ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back
                    FocusableCard(
                      onSelect: () => context.pop(),
                      borderRadius: BorderRadius.circular(50),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded, color: AppColors.onSurfaceMuted, size: 16),
                                SizedBox(width: 6),
                                Text('Назад', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    FutureBuilder<String>(
                      future: nameAsync,
                      builder: (_, snap) => Text(
                        snap.data ?? '',
                        style: Theme.of(context).textTheme.displayMedium,
                        maxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Meta chips row
                    Row(
                      children: [
                        FutureBuilder<int?>(
                          future: yearAsync,
                          builder: (_, snap) => snap.data != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GlassChip(text: '${snap.data}'),
                                )
                              : const SizedBox.shrink(),
                        ),
                        FutureBuilder(
                          future: ratingAsync,
                          builder: (_, snap) {
                            final r = snap.data;
                            if (r == null || r.isEmpty) return const SizedBox.shrink();
                            return GlassChip(
                              text: '★  ${r.value.toStringAsFixed(1)}',
                              textColor: const Color(0xFFFFD60A),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Description
                    FutureBuilder<String>(
                      future: descAsync,
                      builder: (_, snap) => Text(
                        snap.data ?? '',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.onSurfaceMuted),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Translators
                    translatorsAsync.when(
                      loading: () => const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (t) => TranslatorSelector(
                        translators: t,
                        selectedId: selectedTranslatorId,
                        onChanged: onTranslatorChanged,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Episodes
                    FutureBuilder(
                      future: typeAsync,
                      builder: (_, snap) {
                        if (snap.data != const TVSeries()) return const SizedBox.shrink();
                        return episodesAsync.when(
                          loading: () => const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (seasons) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EpisodeSelector(seasons: seasons, onSelect: onEpisodeSelected),
                              const SizedBox(height: 24),
                            ],
                          ),
                        );
                      },
                    ),

                    // Action buttons
                    Row(
                      children: [
                        // Play — white glass pill
                        FocusableCard(
                          borderRadius: BorderRadius.circular(50),
                          onSelect: onPlay,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(50),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFFFFF), Color(0xFFD8E4FF)],
                              ),
                              boxShadow: const [
                                BoxShadow(color: Color(0x50FFFFFF), blurRadius: 20),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                                SizedBox(width: 10),
                                Text('Смотреть',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Bookmark — frosted glass pill
                        FutureBuilder<String>(
                          future: ref.watch(FutureProvider((r) => api.thumbnail).future),
                          builder: (_, thumbSnap) => FutureBuilder<String>(
                            future: nameAsync,
                            builder: (_, nameSnap) => _BookmarkButton(
                              isBookmarked: isBookmarked,
                              onToggle: () => ref.read(bookmarksProvider.notifier).toggle(
                                url: contentUrl,
                                title: nameSnap.data ?? '',
                                thumbnail: thumbSnap.data ?? '',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Poster with glass frame ────────────────────────────────────────────────────

class _PosterWithGlass extends StatelessWidget {
  final String url;
  const _PosterWithGlass({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 375,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder, width: 1),
        boxShadow: const [
          BoxShadow(color: Color(0x60000000), blurRadius: 40, spreadRadius: -4, offset: Offset(0, 12)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: url.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.movie_rounded, color: AppColors.onSurfaceMuted, size: 60),
                ),
              )
            : Container(color: AppColors.surfaceVariant),
      ),
    );
  }
}

// ── Bookmark button ────────────────────────────────────────────────────────────

class _BookmarkButton extends StatelessWidget {
  final bool isBookmarked;
  final VoidCallback onToggle;
  const _BookmarkButton({required this.isBookmarked, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      borderRadius: BorderRadius.circular(50),
      onSelect: onToggle,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              gradient: isBookmarked
                  ? const LinearGradient(
                      colors: [Color(0x552C7DFF), Color(0x307B5CF0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0x35FFFFFF), Color(0x15FFFFFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              border: Border.all(
                color: isBookmarked ? AppColors.accent : AppColors.glassBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: isBookmarked ? AppColors.accent : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 9),
                Text(
                  isBookmarked ? 'В закладках' : 'В закладки',
                  style: TextStyle(
                    color: isBookmarked ? AppColors.accent : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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
