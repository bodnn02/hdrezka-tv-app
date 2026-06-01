import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/hdrezka_api.dart';
import '../../core/api/hdrezka_types.dart';
import '../../core/services/bookmarks_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/content_provider.dart';
import '../../providers/tmdb_provider.dart';
import '../../shared/widgets/focusable_card.dart';
import '../../shared/widgets/glass_surface.dart';

/// Shows a slide-in detail panel from the left side of the screen.
void showContentDetailPanel(BuildContext context, String contentUrl) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => ContentDetailPanel(contentUrl: contentUrl),
      transitionsBuilder: (_, animation, _, child) {
        final slide = Tween<Offset>(
          begin: const Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    ),
  );
}

class ContentDetailPanel extends ConsumerStatefulWidget {
  final String contentUrl;
  const ContentDetailPanel({super.key, required this.contentUrl});

  @override
  ConsumerState<ContentDetailPanel> createState() => _ContentDetailPanelState();
}

class _ContentDetailPanelState extends ConsumerState<ContentDetailPanel> {
  final _closeFocusNode = FocusNode();

  @override
  void dispose() {
    _closeFocusNode.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  void _watch() {
    Navigator.of(context, rootNavigator: true).pop();
    context.push('/details/${Uri.encodeComponent(widget.contentUrl)}');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.escape ||
             event.logicalKey == LogicalKeyboardKey.goBack)) {
          _close();
        }
      },
      child: Stack(
        children: [
          // Tap outside to close
          Positioned.fill(
            child: GestureDetector(onTap: _close, child: const SizedBox.expand()),
          ),
          // Panel
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 480,
              height: double.infinity,
              child: _PanelContent(
                contentUrl: widget.contentUrl,
                closeFocusNode: _closeFocusNode,
                onClose: _close,
                onWatch: _watch,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _PanelContent extends ConsumerWidget {
  final String contentUrl;
  final FocusNode closeFocusNode;
  final VoidCallback onClose;
  final VoidCallback onWatch;

  const _PanelContent({
    required this.contentUrl,
    required this.closeFocusNode,
    required this.onClose,
    required this.onWatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync      = ref.watch(contentProvider(contentUrl));
    final tagsAsync         = ref.watch(tagsProvider(contentUrl));
    final actorsAsync       = ref.watch(actorsProvider(contentUrl));
    final framesAsync       = ref.watch(framesWithFallbackProvider(contentUrl));
    final relatedAsync      = ref.watch(relatedReleasesProvider(contentUrl));
    final metaAsync         = ref.watch(metaProvider(contentUrl));
    final isBookmarked      = ref.watch(bookmarksProvider).any((b) => b.url == contentUrl);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF2060608), Color(0xCC060608)],
            ),
            border: Border(
              right: BorderSide(color: AppColors.glassBorder, width: 1),
            ),
          ),
          child: contentAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            ),
            error: (e, _) => Center(
              child: Text('Ошибка: $e', style: const TextStyle(color: Colors.white)),
            ),
            data: (api) => _PanelBody(
              api: api,
              contentUrl: contentUrl,
              tagsAsync: tagsAsync,
              actorsAsync: actorsAsync,
              framesAsync: framesAsync,
              relatedAsync: relatedAsync,
              metaAsync: metaAsync,
              isBookmarked: isBookmarked,
              closeFocusNode: closeFocusNode,
              onClose: onClose,
              onWatch: onWatch,
              onBookmark: () async {
                final name = await api.name;
                final thumb = await api.thumbnail;
                ref.read(bookmarksProvider.notifier).toggle(
                  url: contentUrl,
                  title: name,
                  thumbnail: thumb,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  final HdRezkaApi api;
  final String contentUrl;
  final AsyncValue<List<String>> tagsAsync;
  final AsyncValue<List<ActorInfo>> actorsAsync;
  final AsyncValue<List<String>> framesAsync;
  final AsyncValue<List<RelatedRelease>> relatedAsync;
  final AsyncValue<ContentMeta> metaAsync;
  final bool isBookmarked;
  final FocusNode closeFocusNode;
  final VoidCallback onClose;
  final VoidCallback onWatch;
  final VoidCallback onBookmark;

  const _PanelBody({
    required this.api,
    required this.contentUrl,
    required this.tagsAsync,
    required this.actorsAsync,
    required this.framesAsync,
    required this.relatedAsync,
    required this.metaAsync,
    required this.isBookmarked,
    required this.closeFocusNode,
    required this.onClose,
    required this.onWatch,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 56, bottom: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: poster + title + meta ─────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                FutureBuilder<String>(
                  future: api.thumbnail,
                  builder: (_, snap) {
                    final url = snap.data ?? '';
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 110,
                        height: 165,
                        child: url.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => Container(color: AppColors.surfaceVariant),
                              )
                            : Container(color: AppColors.surfaceVariant),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 20),

                // Title + meta + actions
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Close button
                      Align(
                        alignment: Alignment.topRight,
                        child: FocusableCard(
                          focusNode: closeFocusNode,
                          autofocus: true,
                          borderRadius: BorderRadius.circular(50),
                          onSelect: onClose,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.glassFill,
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close_rounded, color: AppColors.onSurfaceMuted, size: 16),
                                SizedBox(width: 6),
                                Text('Закрыть',
                                    style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Title
                      FutureBuilder<String>(
                        future: api.name,
                        builder: (_, snap) => Text(
                          snap.data ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Status badge
                      metaAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (m) => m.status != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GlassChip(
                                  text: m.status!,
                                  textColor: const Color(0xFF4CD964),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Orig title
                      metaAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (m) => m.origTitle != null
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  m.origTitle!,
                                  style: const TextStyle(
                                    color: AppColors.onSurfaceMuted,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Year + ratings
                      metaAsync.when(
                        loading: () => FutureBuilder<int?>(
                          future: api.releaseYear,
                          builder: (_, snap) => snap.data != null
                              ? GlassChip(text: '${snap.data}')
                              : const SizedBox.shrink(),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (m) => Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FutureBuilder<int?>(
                              future: api.releaseYear,
                              builder: (_, snap) => snap.data != null
                                  ? GlassChip(text: '${snap.data}')
                                  : const SizedBox.shrink(),
                            ),
                            for (final r in m.ratings)
                              GlassChip(
                                text: '${r.source} ${r.value.toStringAsFixed(1)}',
                                textColor: const Color(0xFFFFD60A),
                              ),
                            if (m.ratings.isEmpty)
                              FutureBuilder(
                                future: api.rating,
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Meta table ─────────────────────────────────────────────
          metaAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (m) {
              final rows = <(String, String)>[];
              if (m.releaseDate != null && m.releaseDate!.isNotEmpty) rows.add(('Дата выхода', m.releaseDate!));
              if (m.countries.isNotEmpty) rows.add(('Страна', m.countries.join(', ')));
              if (m.directors.isNotEmpty) rows.add(('Режиссёр', m.directors.join(', ')));
              if (m.genres.isNotEmpty) rows.add(('Жанр', m.genres.join(', ')));
              if (m.quality != null && m.quality!.isNotEmpty) rows.add(('Качество', m.quality!));
              if (m.translation != null && m.translation!.isNotEmpty) rows.add(('Перевод', m.translation!));
              if (m.duration != null && m.duration!.isNotEmpty) rows.add(('Время', m.duration!));
              if (m.ageRating != null && m.ageRating!.isNotEmpty) rows.add(('Возраст', m.ageRating!));
              if (m.slogan != null && m.slogan!.isNotEmpty) rows.add(('Слоган', '«${m.slogan}»'));
              if (m.collections.isNotEmpty) rows.add(('Из серии', m.collections.join(', ')));
              if (rows.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                child: Column(
                  children: rows.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(r.$1,
                              style: const TextStyle(
                                  color: AppColors.onSurfaceMuted, fontSize: 12)),
                        ),
                        Expanded(
                          child: Text(r.$2,
                              style: const TextStyle(
                                  color: AppColors.onSurface, fontSize: 12)),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Action buttons ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                // Watch
                Expanded(
                  child: FocusableCard(
                    borderRadius: BorderRadius.circular(50),
                    onSelect: onWatch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFFFFF), Color(0xFFD8E4FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                          SizedBox(width: 8),
                          Text('Смотреть',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Bookmark
                FocusableCard(
                  borderRadius: BorderRadius.circular(50),
                  onSelect: onBookmark,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    child: Icon(
                      isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isBookmarked ? AppColors.accent : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Description ────────────────────────────────────────────
          FutureBuilder<String>(
            future: api.description,
            builder: (_, snap) {
              final desc = snap.data ?? '';
              if (desc.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.onSurfaceMuted,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),

          // ── Tags ───────────────────────────────────────────────────
          tagsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (tags) {
              if (tags.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Теги',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: tags.map((t) => GlassChip(text: t)).toList(),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Actors ─────────────────────────────────────────────────
          actorsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (actors) {
              if (actors.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Актёры',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    _ActorsRow(actors: actors),
                  ],
                ),
              );
            },
          ),

          // ── Frames ─────────────────────────────────────────────────
          framesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (frames) {
              if (frames.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(32, 0, 32, 8),
                      child: Text('Кадры из фильма',
                          style: TextStyle(
                              color: AppColors.onSurfaceMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        itemCount: frames.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: frames[i],
                            width: 160,
                            height: 90,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) =>
                                Container(width: 160, height: 90, color: AppColors.surfaceVariant),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // ── Related releases ───────────────────────────────────────
          relatedAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (related) {
              if (related.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Связанные релизы',
                        style: TextStyle(
                            color: AppColors.onSurfaceMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    ...related.map((r) => _RelatedItem(release: r)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Actors horizontal row ──────────────────────────────────────────────────────

class _ActorsRow extends StatelessWidget {
  final List<ActorInfo> actors;
  const _ActorsRow({required this.actors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final actor = actors[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: actor.photo != null && actor.photo!.isNotEmpty
                    ? CachedNetworkImageProvider(actor.photo!)
                    : null,
                child: actor.photo == null || actor.photo!.isEmpty
                    ? const Icon(Icons.person_rounded, color: AppColors.onSurfaceMuted, size: 22)
                    : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 58,
                child: Text(
                  actor.name,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 10, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Related release row item ───────────────────────────────────────────────────

class _RelatedItem extends StatelessWidget {
  final RelatedRelease release;
  const _RelatedItem({required this.release});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: FocusableCard(
        borderRadius: BorderRadius.circular(10),
        onSelect: () {
          Navigator.of(context, rootNavigator: true).pop();
          showContentDetailPanel(context, release.url);
        },
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: AppColors.glassFill,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              if (release.image.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  child: CachedNetworkImage(
                    imageUrl: release.image,
                    width: 40,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox(width: 40),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  release.title,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.onSurfaceMuted, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
