import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/hdrezka_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/content_provider.dart';
import '../../../shared/widgets/focusable_card.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../details/content_detail_panel.dart';

class HeroBanner extends ConsumerWidget {
  const HeroBanner({super.key});

  static const double _height = 580.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoryContentProvider((category: 'films', page: 1, filter: 'watching')));

    return SizedBox(
      height: _height,
      child: async.when(
        loading: () => Container(color: AppColors.surface),
        error: (_, _) => Container(color: AppColors.surface),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return _HeroBannerContent(item: items.first);
        },
      ),
    );
  }
}

class _HeroBannerContent extends ConsumerWidget {
  final AdvancedSearchResult item;
  const _HeroBannerContent({required this.item});

  void _showDetailPanel(BuildContext context) {
    showContentDetailPanel(context, item.url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbHqAsync = ref.watch(thumbnailHqProvider(item.url));
    final descAsync    = ref.watch(descriptionProvider(item.url));
    final tagsAsync    = ref.watch(tagsProvider(item.url));
    final actorsAsync  = ref.watch(actorsProvider(item.url));

    // Best available background: HQ thumbnail, fall back to poster image
    final hqThumb = thumbHqAsync.valueOrNull;
    final bgUrl   = (hqThumb != null && hqThumb.isNotEmpty) ? hqThumb : item.image;

    return SizedBox(
      height: HeroBanner._height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background — high quality, subtle desaturation
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
            child: DecoratedBox(
              decoration: const BoxDecoration(
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

          // Top dark overlay so top-bar text stays legible
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

          // Content: left-aligned text + glass buttons
          Positioned(
            left: 64, bottom: 72, right: 240,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glass category pill
                if (item.category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: GlassChip(
                      text: item.category!.name.toUpperCase(),
                      textColor: Colors.white,
                    ),
                  ),

                // Title
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

                // Tags row
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

                // Description
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
                          shadows: [
                            Shadow(color: Color(0x80000000), blurRadius: 12),
                          ],
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),

                // Actors row
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
                                shadows: [
                                  Shadow(color: Color(0x80000000), blurRadius: 8),
                                ],
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

                // Glass pill buttons
                Row(
                  children: [
                    // Primary: watch
                    FocusableCard(
                      autofocus: true,
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () {
                        // Navigate straight to details for translator/episode selection
                        _showDetailPanel(context);
                      },
                      child: _GlassPrimaryButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Смотреть',
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Secondary: detail panel
                    FocusableCard(
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () => _showDetailPanel(context),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
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
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
