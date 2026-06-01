import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/hdrezka_search.dart';
import '../../core/theme/app_theme.dart';
import 'focusable_card.dart';

/// Portrait poster card — used in search results.
class PosterCard extends StatelessWidget {
  final AdvancedSearchResult item;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;
  final bool autofocus;

  static const double cardWidth  = 160.0;
  static const double cardHeight = 240.0;

  const PosterCard({
    super.key,
    required this.item,
    this.focusNode,
    this.onFocused,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (f) { if (f) onFocused?.call(); },
      borderRadius: BorderRadius.circular(14),
      onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.movie_rounded, color: AppColors.onSurfaceMuted, size: 40),
                ),
                placeholder: (_, _) => Container(color: AppColors.surfaceVariant),
              ),
              // Gradient label at bottom (no BackdropFilter — too expensive on TV)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xDD000000)],
                    ),
                  ),
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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

/// Wide landscape card (16:9) — Apple TV 26 Liquid Glass style.
class LandscapeCard extends StatelessWidget {
  final AdvancedSearchResult item;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;
  final bool autofocus;

  static const double cardWidth  = 290.0;
  static const double cardHeight = 163.0; // 16:9

  const LandscapeCard({
    super.key,
    required this.item,
    this.focusNode,
    this.onFocused,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      focusNode: focusNode,
      autofocus: autofocus,
      onFocusChange: (f) { if (f) onFocused?.call(); },
      borderRadius: BorderRadius.circular(16),
      onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster image
              CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.movie_rounded, color: AppColors.onSurfaceMuted, size: 40),
                ),
                placeholder: (_, _) => Container(color: AppColors.surfaceCard),
              ),

              // Bottom gradient label (no BackdropFilter — too expensive on TV)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xCC000000)],
                    ),
                    border: Border(
                      top: BorderSide(color: Color(0x18FFFFFF), width: 0.5),
                    ),
                  ),
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Category pill — top left (solid fill, no blur)
              if (item.category != null)
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(
                      item.category!.name.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
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
