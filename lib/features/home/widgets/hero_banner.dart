import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/hdrezka_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/content_provider.dart';
import '../../../shared/widgets/focusable_card.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../details/content_detail_panel.dart';

// How many slides to show in the banner
const _kMaxSlides = 8;
// How many upcoming slides to pre-fetch in the background
const _kPrefetchAhead = 2;
// Auto-advance interval (paused after manual navigation)
const _kAutoInterval = Duration(seconds: 7);

class HeroBanner extends ConsumerStatefulWidget {
  const HeroBanner({super.key});

  static const double height = 580.0;

  @override
  ConsumerState<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends ConsumerState<HeroBanner> {
  int _index = 0;
  Timer? _timer;
  // Once the user manually navigates, auto-advance stops permanently
  bool _autoPlay = true;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleAutoPlay(List<AdvancedSearchResult> items) {
    if (!_autoPlay) return;
    _timer?.cancel();
    _timer = Timer(_kAutoInterval, () {
      if (!mounted || !_autoPlay) return;
      _advance(items, (_index + 1) % items.length, manual: false);
    });
  }

  void _advance(List<AdvancedSearchResult> items, int next, {required bool manual}) {
    if (manual) {
      _autoPlay = false;
      _timer?.cancel();
    }
    setState(() => _index = next);
    // Pre-fetch upcoming slides so content is ready before they appear
    _prefetch(items, next);
    if (!manual) _scheduleAutoPlay(items);
  }

  void _prefetch(List<AdvancedSearchResult> items, int from) {
    for (var i = 1; i <= _kPrefetchAhead; i++) {
      final url = items[(from + i) % items.length].url;
      // Reading (not watching) just warms the Riverpod cache
      ref.read(thumbnailHqProvider(url).future).ignore();
      ref.read(descriptionProvider(url).future).ignore();
      ref.read(tagsProvider(url).future).ignore();
      ref.read(actorsProvider(url).future).ignore();
    }
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event, List<AdvancedSearchResult> items) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _advance(items, (_index - 1 + items.length) % items.length, manual: true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _advance(items, (_index + 1) % items.length, manual: true);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      categoryContentProvider((category: 'films', page: 1, filter: 'last')),
    );

    return SizedBox(
      height: HeroBanner.height,
      child: async.when(
        loading: () => Container(color: AppColors.surface),
        error: (_, _) => Container(color: AppColors.surface),
        data: (all) {
          if (all.isEmpty) return const SizedBox.shrink();

          final items = all.take(_kMaxSlides).toList();
          final index = _index.clamp(0, items.length - 1);

          // Start timer and initial pre-fetch once items are available
          if (_autoPlay && _timer == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _prefetch(items, index);
                _scheduleAutoPlay(items);
              }
            });
          }

          return Focus(
            // Captures left/right arrow keys before they leak to the scroll view
            onKeyEvent: (node, event) => _handleKey(node, event, items),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Slide content with crossfade
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                  child: _HeroBannerSlide(
                    key: ValueKey(items[index].url),
                    item: items[index],
                  ),
                ),

                // Dot indicators + nav arrows (bottom-right)
                Positioned(
                  bottom: TvSafe.v,
                  right: TvSafe.h,
                  child: _SlideControls(
                    count: items.length,
                    current: index,
                    autoPlay: _autoPlay,
                    onPrev: () => _advance(items, (index - 1 + items.length) % items.length, manual: true),
                    onNext: () => _advance(items, (index + 1) % items.length, manual: true),
                    onDot:  (i) => _advance(items, i, manual: true),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Slide controls: arrows + dots ─────────────────────────────────────────────

class _SlideControls extends StatelessWidget {
  final int count;
  final int current;
  final bool autoPlay;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final ValueChanged<int> onDot;

  const _SlideControls({
    required this.count,
    required this.current,
    required this.autoPlay,
    required this.onPrev,
    required this.onNext,
    required this.onDot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Auto-play indicator
        if (!autoPlay)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.pause_rounded, color: Colors.white54, size: 16),
          ),

        // Dots
        ...List.generate(count, (i) {
          final active = i == current;
          return GestureDetector(
            onTap: () => onDot(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.35),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ── Single slide ──────────────────────────────────────────────────────────────

class _HeroBannerSlide extends ConsumerWidget {
  final AdvancedSearchResult item;
  const _HeroBannerSlide({super.key, required this.item});

  void _openDetail(BuildContext context) =>
      showContentDetailPanel(context, item.url);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbHqAsync = ref.watch(thumbnailHqProvider(item.url));
    final descAsync    = ref.watch(descriptionProvider(item.url));
    final tagsAsync    = ref.watch(tagsProvider(item.url));
    final actorsAsync  = ref.watch(actorsProvider(item.url));

    final hqThumb = thumbHqAsync.valueOrNull;
    final bgUrl   = (hqThumb != null && hqThumb.isNotEmpty) ? hqThumb : item.image;

    return SizedBox(
      height: HeroBanner.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image — subtle desaturation
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.88, 0.04, 0.04, 0, 0,
              0.04, 0.88, 0.04, 0, 0,
              0.04, 0.04, 0.92, 0, 0,
              0,    0,    0,    1, 0,
            ]),
            child: CachedNetworkImage(
              imageUrl: bgUrl,
              fit: BoxFit.cover,
              memCacheWidth: 1920,
              filterQuality: FilterQuality.high,
              errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
            ),
          ),

          // Dark cinematic vignette
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Colors.transparent, Color(0x88000000)],
                ),
              ),
            ),
          ),

          // Left content gradient
          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xF0060608), Color(0x66060608), Colors.transparent],
                  stops: [0.0, 0.45, 0.75],
                ),
              ),
            ),
          ),

          // Bottom fade into page
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.background],
                ),
              ),
            ),
          ),

          // Top overlay for nav bar readability
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x70000000), Colors.transparent],
                ),
              ),
            ),
          ),

          // Text + buttons
          Positioned(
            left: 64, bottom: 72, right: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GlassChip(
                    text: item.category != null
                        ? item.category!.name.toUpperCase()
                        : 'НОВИНКА',
                    textColor: Colors.white,
                  ),
                ),

                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                    letterSpacing: -2.0,
                    shadows: [
                      Shadow(color: Color(0xA0000000), blurRadius: 32, offset: Offset(0, 4)),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                tagsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (tags) {
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: tags.take(5).map((t) => GlassChip(
                          text: t,
                          textColor: AppColors.onSurfaceMuted,
                          fillColor: const Color(0x55000000),
                        )).toList(),
                      ),
                    );
                  },
                ),

                descAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (desc) {
                    if (desc.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        desc,
                        style: const TextStyle(
                          color: Color(0xCCEEEEF4),
                          fontSize: 15,
                          height: 1.5,
                          shadows: [Shadow(color: Color(0x80000000), blurRadius: 12)],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),

                actorsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (actors) {
                    if (actors.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          const Text(
                            'В ролях: ',
                            style: TextStyle(
                              color: AppColors.onSurfaceMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              actors.take(4).map((a) => a.name).join(', '),
                              style: const TextStyle(
                                color: Color(0xBBEEEEF4),
                                fontSize: 13,
                                shadows: [Shadow(color: Color(0x80000000), blurRadius: 8)],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                Row(
                  children: [
                    FocusableCard(
                      autofocus: true,
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () => _openDetail(context),
                      child: _GlassPrimaryButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Смотреть',
                      ),
                    ),
                    const SizedBox(width: 14),
                    FocusableCard(
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () => _openDetail(context),
                      child: _GlassSecondaryButton(
                        icon: Icons.info_outline_rounded,
                        label: 'Подробнее',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Glass button variants ──────────────────────────────────────────────────────

class _GlassPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassPrimaryButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFD8E0FF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x60FFFFFF), blurRadius: 24, spreadRadius: -2),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          )),
        ],
      ),
    );
  }
}

class _GlassSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _GlassSecondaryButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        color: const Color(0x40000000),
        border: Border.all(color: AppColors.glassBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }
}
