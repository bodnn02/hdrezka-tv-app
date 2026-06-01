import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api/hdrezka_search.dart';
import '../../../core/theme/app_theme.dart';
import '../../details/content_detail_panel.dart';

class SearchResultCard extends StatefulWidget {
  final FastSearchResult item;
  final bool isSelected;
  final void Function(bool focused) onFocused;

  const SearchResultCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onFocused,
  });

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final active = _focused || widget.isSelected;

    return Focus(
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocused(f);
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          showContentDetailPanel(context, widget.item.url);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => showContentDetailPanel(context, widget.item.url),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: active
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x40FFFFFF), Color(0x18FFFFFF)],
                        )
                      : const LinearGradient(
                          colors: [Color(0x18FFFFFF), Color(0x08FFFFFF)],
                        ),
                  border: Border.all(
                    color: _focused
                        ? AppColors.glassBorderFocus
                        : active
                            ? AppColors.glassBorder
                            : Colors.transparent,
                    width: _focused ? 2 : 1,
                  ),
                  boxShadow: _focused
                      ? const [
                          BoxShadow(color: Color(0x40FFFFFF), blurRadius: 16),
                          BoxShadow(color: AppColors.accentGlow, blurRadius: 20, spreadRadius: -4),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Icon placeholder (FastSearchResult has no thumbnail)
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.glassFill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(
                        Icons.movie_rounded,
                        color: AppColors.onSurfaceMuted,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.item.title,
                            style: TextStyle(
                              color: active ? Colors.white : AppColors.onSurface,
                              fontSize: 15,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.item.rating != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              '★  ${widget.item.rating!.toStringAsFixed(1)}',
                              style: const TextStyle(
                                color: Color(0xFFFFD60A),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceSubtle,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
