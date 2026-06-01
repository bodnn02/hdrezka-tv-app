import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/watch_history_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/focusable_card.dart';

class ContinueWatchingRow extends ConsumerStatefulWidget {
  const ContinueWatchingRow({super.key});

  @override
  ConsumerState<ContinueWatchingRow> createState() => _ContinueWatchingRowState();
}

class _ContinueWatchingRowState extends ConsumerState<ContinueWatchingRow> {
  final _scrollController = ScrollController();
  final Map<int, FocusNode> _focusNodes = {};

  @override
  void dispose() {
    _scrollController.dispose();
    for (final node in _focusNodes.values) { node.dispose(); }
    super.dispose();
  }

  FocusNode _focusNodeFor(int i) => _focusNodes.putIfAbsent(i, () => FocusNode());

  void _scrollToIndex(int index) {
    const w = _ContinueCard.cardWidth + 14.0;
    final offset = (index * w).clamp(
      0.0,
      _scrollController.hasClients ? _scrollController.position.maxScrollExtent : double.infinity,
    );
    if (_scrollController.hasClients) {
      _scrollController.animateTo(offset,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(watchHistoryProvider);
    final items = history.where((e) => e.progress < 0.95).take(12).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 36, 64, 14),
            child: Row(
              children: [
                Text(
                  'Продолжить просмотр',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                _ClearButton(
                  onClear: () => ref.read(watchHistoryProvider.notifier).clear(),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _ContinueCard.cardHeight + 8,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 64),
              itemCount: items.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _ContinueCard(
                  entry: items[i],
                  focusNode: _focusNodeFor(i),
                  onFocused: () => _scrollToIndex(i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onClear;
  const _ClearButton({required this.onClear});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onClear();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onClear,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: _focused ? AppColors.glassBorderFocus : AppColors.glassBorder,
              width: _focused ? 2 : 1,
            ),
            color: _focused ? AppColors.glassFillHover : AppColors.glassFill,
          ),
          child: const Text(
            'Очистить',
            style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }
}

// ── Continue card ──────────────────────────────────────────────────────────────

class _ContinueCard extends StatelessWidget {
  final WatchHistoryEntry entry;
  final FocusNode? focusNode;
  final VoidCallback? onFocused;

  static const double cardWidth  = 290.0;
  static const double cardHeight = 198.0;

  const _ContinueCard({required this.entry, this.focusNode, this.onFocused});

  void _open(BuildContext context) {
    final params = <String, String>{'url': Uri.encodeComponent(entry.url)};
    if (entry.season != null)       params['season']  = '${entry.season}';
    if (entry.episode != null)      params['episode'] = '${entry.episode}';
    if (entry.translatorId != null) params['tr']      = '${entry.translatorId}';
    context.push(Uri(path: '/player', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      focusNode: focusNode,
      onFocusChange: (f) { if (f) onFocused?.call(); },
      borderRadius: BorderRadius.circular(16),
      onSelect: () => _open(context),
      child: SizedBox(
        width: cardWidth,
        height: cardHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              entry.thumbnail.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: entry.thumbnail,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
                    )
                  : Container(color: AppColors.surfaceVariant),

              // Cinematic tint
              Positioned.fill(
                child: Container(color: Colors.black.withAlpha(40)),
              ),

              // Play button overlay — glass circle
              Center(
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.glassFillStrong,
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),

              // Glass bottom info strip
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC000000)],
                        ),
                        border: Border(
                          top: BorderSide(color: AppColors.glassBorder, width: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar — glass track
                          Stack(
                            children: [
                              Container(
                                height: 3,
                                color: Colors.white.withAlpha(30),
                              ),
                              FractionallySizedBox(
                                widthFactor: entry.progress.clamp(0.0, 1.0),
                                child: Container(
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.accent, AppColors.accentSecondary],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entry.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _subtitle(),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    if (entry.season != null && entry.episode != null) {
      return 'С${entry.season} · Е${entry.episode}';
    }
    final t = entry.total;
    if (t != null && t.inSeconds > 0) {
      final remaining = t - entry.position;
      final m = remaining.inMinutes;
      return m > 0 ? 'Осталось $m мин' : 'Почти конец';
    }
    return '';
  }
}
