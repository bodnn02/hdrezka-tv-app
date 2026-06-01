import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/hdrezka_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/category_provider.dart';
import '../../../shared/widgets/focusable_card.dart';
import '../../../shared/widgets/glass_surface.dart';

class HeroBanner extends ConsumerWidget {
  const HeroBanner({super.key});

  static const double _height = 560.0;

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

class _HeroBannerContent extends StatelessWidget {
  final AdvancedSearchResult item;
  const _HeroBannerContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HeroBanner._height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background — slightly desaturated for glass depth
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              0.85, 0.05, 0.05, 0, 0,
              0.05, 0.85, 0.05, 0, 0,
              0.05, 0.05, 0.90, 0, 0,
              0,    0,    0,    1, 0,
            ]),
            child: CachedNetworkImage(
              imageUrl: item.image,
              fit: BoxFit.cover,
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
                  colors: [Color(0xEA060608), Color(0x55060608), Colors.transparent],
                  stops: [0.0, 0.42, 0.72],
                ),
              ),
            ),
          ),

          // Bottom fade into page
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 180,
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
            left: 64, bottom: 80, right: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glass category pill
                if (item.category != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
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
                const SizedBox(height: 32),

                // Glass pill buttons
                Row(
                  children: [
                    // Primary: white glass pill
                    FocusableCard(
                      autofocus: true,
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
                      child: _GlassPrimaryButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Смотреть',
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Secondary: frosted glass pill
                    FocusableCard(
                      borderRadius: BorderRadius.circular(50),
                      onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(50),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x40FFFFFF), Color(0x18FFFFFF)],
            ),
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
        ),
      ),
    );
  }
}
