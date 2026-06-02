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
    if (_selectedSeason != null) params['season'] = '$_selectedSeason';
    if (_selectedEpisode != null) params['episode'] = '$_selectedEpisode';
    if (_selectedTranslatorId != null) params['tr'] = '$_selectedTranslatorId';
    context.push(Uri(path: '/player', queryParameters: params).toString());
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(contentProvider(widget.contentUrl));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: contentAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
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

// ── Main content layout ────────────────────────────────────────────────────────

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
    final thumbAsync        = ref.watch(FutureProvider((r) => api.thumbnailHQ).future);
    final translatorsAsync  = ref.watch(translatorsProvider(contentUrl));
    // Load episodes only for the selected translator; fall back to the default first translator
    final episodesAsync = selectedTranslatorId != null
        ? ref.watch(episodesForTranslatorProvider((url: contentUrl, translatorId: selectedTranslatorId!)))
        : ref.watch(episodesInfoProvider(contentUrl));
    final metaAsync         = ref.watch(metaProvider(contentUrl));
    final actorsAsync       = ref.watch(actorsProvider(contentUrl));
    final framesAsync       = ref.watch(framesWithFallbackProvider(contentUrl));
    final commentsAsync     = ref.watch(commentsProvider(contentUrl));
    final similarAsync      = ref.watch(similarProvider(contentUrl));
    final relatedAsync      = ref.watch(relatedReleasesProvider(contentUrl));
    final isBookmarked      = ref.watch(bookmarksProvider).any((b) => b.url == contentUrl);

    return Stack(
      children: [
        // Blurred background poster
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
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            );
          },
        ),

        // Gradient overlay
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
        Focus(
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent &&
                (event.logicalKey == LogicalKeyboardKey.goBack ||
                 event.logicalKey == LogicalKeyboardKey.escape ||
                 event.logicalKey == LogicalKeyboardKey.browserBack)) {
              Navigator.of(context).maybePop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            top: TvSafe.contentTop,
            left: TvSafe.h,
            right: TvSafe.h,
            bottom: TvSafe.v,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              FocusableCard(
                onSelect: () => context.pop(),
                borderRadius: BorderRadius.circular(50),
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
              const SizedBox(height: 28),

              // ── Hero row: poster + info ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster
                  FutureBuilder<String>(
                    future: thumbAsync,
                    builder: (_, snap) => _PosterWithGlass(url: snap.data ?? ''),
                  ),
                  const SizedBox(width: 52),

                  // Info column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status badge
                        metaAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (m) => m.status != null
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GlassChip(
                                    text: m.status!,
                                    textColor: const Color(0xFF4CD964),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        // Title
                        FutureBuilder<String>(
                          future: api.name,
                          builder: (_, snap) => Text(
                            snap.data ?? '',
                            style: Theme.of(context).textTheme.displayMedium,
                            maxLines: 2,
                          ),
                        ),

                        // Orig title
                        metaAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (m) => m.origTitle != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    m.origTitle!,
                                    style: const TextStyle(
                                      color: AppColors.onSurfaceMuted,
                                      fontSize: 15,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 14),

                        // Ratings row
                        _RatingsRow(contentUrl: contentUrl, api: api),
                        const SizedBox(height: 18),

                        // Meta info table
                        metaAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (m) => _MetaTable(meta: m),
                        ),
                        const SizedBox(height: 24),

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
                        const SizedBox(height: 20),

                        // Episodes (TVSeries only)
                        FutureBuilder(
                          future: api.type,
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
                                  const SizedBox(height: 20),
                                ],
                              ),
                            );
                          },
                        ),

                        // Action buttons
                        Row(
                          children: [
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
                            FutureBuilder<String>(
                              future: ref.watch(FutureProvider((r) => api.thumbnail).future),
                              builder: (_, thumbSnap) => FutureBuilder<String>(
                                future: api.name,
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
              const SizedBox(height: 40),

              // ── Description ──────────────────────────────────────────
              FutureBuilder<String>(
                future: api.description,
                builder: (_, snap) {
                  final desc = snap.data ?? '';
                  if (desc.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('О фильме'),
                      const SizedBox(height: 12),
                      _ExpandableText(text: desc),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),

              // ── Actors ───────────────────────────────────────────────
              actorsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (actors) {
                  if (actors.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('В ролях'),
                      const SizedBox(height: 14),
                      _ActorsRow(actors: actors),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),

              // ── Frames ───────────────────────────────────────────────
              framesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (frames) {
                  if (frames.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Кадры из фильма'),
                      const SizedBox(height: 14),
                      _FramesRow(frames: frames),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),

              // ── Episode schedule (TVSeries) ──────────────────────────
              FutureBuilder(
                future: api.type,
                builder: (_, snap) {
                  if (snap.data != const TVSeries()) return const SizedBox.shrink();
                  return episodesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (seasons) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('График серий'),
                        const SizedBox(height: 14),
                        _EpisodeSchedule(seasons: seasons),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),

              // ── Similar content ──────────────────────────────────────
              similarAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Похожие фильмы'),
                      const SizedBox(height: 14),
                      _SimilarRow(items: items),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),

              // ── Related releases ─────────────────────────────────────
              relatedAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (related) {
                  if (related.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Связанные релизы'),
                      const SizedBox(height: 14),
                      ...related.map((r) => _RelatedItem(release: r)),
                      const SizedBox(height: 40),
                    ],
                  );
                },
              ),

              // ── Comments ─────────────────────────────────────────────
              commentsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (comments) {
                  if (comments.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader('Комментарии (${comments.length})'),
                      const SizedBox(height: 14),
                      ...comments.take(20).map((c) => _CommentCard(comment: c)),
                    ],
                  );
                },
              ),
            ],
          ),
        ),      // SingleChildScrollView
        ),      // Focus
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ── Ratings row with vote ──────────────────────────────────────────────────────

class _RatingsRow extends ConsumerWidget {
  final String contentUrl;
  final HdRezkaApi api;
  const _RatingsRow({required this.contentUrl, required this.api});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metaAsync = ref.watch(metaProvider(contentUrl));
    final userVote  = ref.watch(userVoteProvider(contentUrl));

    return metaAsync.when(
      loading: () => FutureBuilder(
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
      error: (_, _) => const SizedBox.shrink(),
      data: (meta) {
        return Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // External ratings (IMDb, KP etc.)
            for (final r in meta.ratings)
              _RatingChip(source: r.source, value: r.value, votes: r.votes),

            // Internal HDRezka rating fallback
            if (meta.ratings.isEmpty)
              FutureBuilder(
                future: api.rating,
                builder: (_, snap) {
                  final r = snap.data;
                  if (r == null || r.isEmpty) return const SizedBox.shrink();
                  return _RatingChip(source: 'HDRezka', value: r.value, votes: r.votes);
                },
              ),

            // Vote buttons
            _VoteButton(
              icon: Icons.thumb_up_rounded,
              active: userVote == true,
              onTap: () async {
                final success = await api.voteRating(true);
                if (success) {
                  ref.read(userVoteProvider(contentUrl).notifier).state = true;
                }
              },
            ),
            _VoteButton(
              icon: Icons.thumb_down_rounded,
              active: userVote == false,
              onTap: () async {
                final success = await api.voteRating(false);
                if (success) {
                  ref.read(userVoteProvider(contentUrl).notifier).state = false;
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String source;
  final double value;
  final int votes;
  const _RatingChip({required this.source, required this.value, required this.votes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.glassFill,
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            source,
            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('★', style: TextStyle(color: Color(0xFFFFD60A), fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                value.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              if (votes > 0) ...[
                const SizedBox(width: 5),
                Text(
                  '(${_fmt(votes)})',
                  style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _VoteButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      borderRadius: BorderRadius.circular(8),
      onSelect: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? AppColors.accent.withAlpha(50) : AppColors.glassFill,
          border: Border.all(
            color: active ? AppColors.accent : AppColors.glassBorder,
          ),
        ),
        child: Icon(icon, color: active ? AppColors.accent : AppColors.onSurfaceMuted, size: 18),
      ),
    );
  }
}

// ── Meta info table ────────────────────────────────────────────────────────────

class _MetaTable extends StatelessWidget {
  final ContentMeta meta;
  const _MetaTable({required this.meta});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    if (meta.releaseDate != null && meta.releaseDate!.isNotEmpty) {
      rows.add(('Дата выхода', meta.releaseDate!));
    }
    if (meta.countries.isNotEmpty) {
      rows.add(('Страна', meta.countries.join(', ')));
    }
    if (meta.directors.isNotEmpty) {
      rows.add(('Режиссёр', meta.directors.join(', ')));
    }
    if (meta.genres.isNotEmpty) {
      rows.add(('Жанр', meta.genres.join(', ')));
    }
    if (meta.quality != null && meta.quality!.isNotEmpty) {
      rows.add(('Качество', meta.quality!));
    }
    if (meta.translation != null && meta.translation!.isNotEmpty) {
      rows.add(('Перевод', meta.translation!));
    }
    if (meta.duration != null && meta.duration!.isNotEmpty) {
      rows.add(('Время', meta.duration!));
    }
    if (meta.ageRating != null && meta.ageRating!.isNotEmpty) {
      rows.add(('Возраст', meta.ageRating!));
    }
    if (meta.slogan != null && meta.slogan!.isNotEmpty) {
      rows.add(('Слоган', '«${meta.slogan}»'));
    }
    if (meta.collections.isNotEmpty) {
      rows.add(('Из серии', meta.collections.join(', ')));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: rows.map((r) => _MetaRow(label: r.$1, value: r.$2)).toList(),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Expandable description ─────────────────────────────────────────────────────

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          style: const TextStyle(
            color: AppColors.onSurfaceMuted,
            fontSize: 14,
            height: 1.7,
          ),
          maxLines: _expanded ? null : 5,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (widget.text.length > 200)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FocusableCard(
              borderRadius: BorderRadius.circular(50),
              onSelect: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: AppColors.glassFill,
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  _expanded ? 'Скрыть' : 'Читать полностью',
                  style: const TextStyle(color: AppColors.accent, fontSize: 13),
                ),
              ),
            ),
          ),
      ],
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
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final actor = actors[i];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage: actor.photo != null && actor.photo!.isNotEmpty
                    ? CachedNetworkImageProvider(actor.photo!)
                    : null,
                child: actor.photo == null || actor.photo!.isEmpty
                    ? const Icon(Icons.person_rounded, color: AppColors.onSurfaceMuted, size: 24)
                    : null,
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 62,
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

// ── Frames ─────────────────────────────────────────────────────────────────────

class _FramesRow extends StatefulWidget {
  final List<String> frames;
  const _FramesRow({required this.frames});

  @override
  State<_FramesRow> createState() => _FramesRowState();
}

class _FramesRowState extends State<_FramesRow> {
  final _scrollController = ScrollController();
  final List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.frames.length; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  @override
  void dispose() {
    for (final n in _focusNodes) {
      n.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _openGallery(int initialIndex) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      pageBuilder: (_, _, _) => _FramesGallery(
        frames: widget.frames,
        initialIndex: initialIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: widget.frames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          return FocusableCard(
            focusNode: _focusNodes[i],
            borderRadius: BorderRadius.circular(10),
            onSelect: () => _openGallery(i),
            onFocusChange: (focused) {
              if (focused) {
                final offset = i * 206.0;
                _scrollController.animateTo(
                  offset.clamp(0.0, _scrollController.position.maxScrollExtent),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                );
              }
            },
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.frames[i],
                    width: 196,
                    height: 110,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 196,
                      height: 110,
                      color: AppColors.surfaceVariant,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${i + 1} / ${widget.frames.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                    ),
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

// ── Frames Gallery Overlay ──────────────────────────────────────────────────────

class _FramesGallery extends StatefulWidget {
  final List<String> frames;
  final int initialIndex;
  const _FramesGallery({required this.frames, required this.initialIndex});

  @override
  State<_FramesGallery> createState() => _FramesGalleryState();
}

class _FramesGalleryState extends State<_FramesGallery>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _fadeController;
  late int _currentIndex;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _close() {
    _fadeController.reverse().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.frames.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.mediaRewind) {
      _goTo(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.mediaFastForward) {
      _goTo(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      _close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          body: Stack(
            children: [
              // ── Main image PageView ──
              PageView.builder(
                controller: _pageController,
                itemCount: widget.frames.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.frames[i],
                      fit: BoxFit.contain,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(color: Colors.white38),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white38,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Top bar ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Text(
                        'Кадры из фильма',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentIndex + 1} / ${widget.frames.length}',
                        style: const TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Left arrow ──
              if (_currentIndex > 0)
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_left_rounded,
                      onTap: () => _goTo(_currentIndex - 1),
                    ),
                  ),
                ),

              // ── Right arrow ──
              if (_currentIndex < widget.frames.length - 1)
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_right_rounded,
                      onTap: () => _goTo(_currentIndex + 1),
                    ),
                  ),
                ),

              // ── Bottom thumbnail strip ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _ThumbnailStrip(
                  frames: widget.frames,
                  currentIndex: _currentIndex,
                  onTap: _goTo,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered ? Colors.white24 : Colors.white12,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _ThumbnailStrip extends StatefulWidget {
  final List<String> frames;
  final int currentIndex;
  final void Function(int) onTap;
  const _ThumbnailStrip({
    required this.frames,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_ThumbnailStrip> createState() => _ThumbnailStripState();
}

class _ThumbnailStripState extends State<_ThumbnailStrip> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(_ThumbnailStrip old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      final target = widget.currentIndex * 82.0;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          target.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      height: 90,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.frames.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final selected = i == widget.currentIndex;
          return GestureDetector(
            onTap: () => widget.onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? Colors.white : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Opacity(
                  opacity: selected ? 1.0 : 0.5,
                  child: CachedNetworkImage(
                    imageUrl: widget.frames[i],
                    width: 72,
                    height: 40,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 72,
                      height: 40,
                      color: AppColors.surfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Episode schedule ───────────────────────────────────────────────────────────

class _EpisodeSchedule extends StatefulWidget {
  final List<SeasonInfo> seasons;
  const _EpisodeSchedule({required this.seasons});

  @override
  State<_EpisodeSchedule> createState() => _EpisodeScheduleState();
}

class _EpisodeScheduleState extends State<_EpisodeSchedule> {
  late int _selectedSeason;

  @override
  void initState() {
    super.initState();
    _selectedSeason = widget.seasons.isNotEmpty ? widget.seasons.first.season : 0;
  }

  @override
  Widget build(BuildContext context) {
    final season = widget.seasons.firstWhere(
      (s) => s.season == _selectedSeason,
      orElse: () => widget.seasons.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Season tabs
        if (widget.seasons.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: widget.seasons.map((s) {
                final selected = s.season == _selectedSeason;
                return FocusableCard(
                  borderRadius: BorderRadius.circular(8),
                  onSelect: () => setState(() => _selectedSeason = s.season),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: selected
                          ? const LinearGradient(
                              colors: [Color(0x552C7DFF), Color(0x307B5CF0)],
                            )
                          : const LinearGradient(
                              colors: [AppColors.glassFill, AppColors.glassFill],
                            ),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.glassBorder,
                      ),
                    ),
                    child: Text(
                      s.seasonText.isNotEmpty ? s.seasonText : 'Сезон ${s.season}',
                      style: TextStyle(
                        color: selected ? AppColors.accent : AppColors.onSurface,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Episodes grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: season.episodes.map((ep) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.glassFill,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Text(
              ep.episodeText.isNotEmpty ? ep.episodeText : 'Эпизод ${ep.episode}',
              style: const TextStyle(color: AppColors.onSurface, fontSize: 12),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

// ── Similar content row ────────────────────────────────────────────────────────

class _SimilarRow extends StatelessWidget {
  final List<SimilarContent> items;
  const _SimilarRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final item = items[i];
          return FocusableCard(
            borderRadius: BorderRadius.circular(12),
            onSelect: () => context.push('/details/${Uri.encodeComponent(item.url)}'),
            child: SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 158,
                      child: item.poster != null && item.poster!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: item.poster!,
                              width: 120,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  Container(color: AppColors.surfaceVariant),
                            )
                          : Container(color: AppColors.surfaceVariant,
                              child: const Icon(Icons.movie_rounded,
                                  color: AppColors.onSurfaceMuted, size: 32)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      item.title,
                      style: const TextStyle(color: AppColors.onSurface, fontSize: 11, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
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
        onSelect: () => context.push('/details/${Uri.encodeComponent(release.url)}'),
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
                  style: const TextStyle(
                      color: AppColors.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
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

// ── Comment card ───────────────────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final CommentInfo comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.glassFill,
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceVariant,
                  backgroundImage: comment.authorPhoto != null && comment.authorPhoto!.isNotEmpty
                      ? CachedNetworkImageProvider(comment.authorPhoto!)
                      : null,
                  child: comment.authorPhoto == null || comment.authorPhoto!.isEmpty
                      ? const Icon(Icons.person_rounded, color: AppColors.onSurfaceMuted, size: 16)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.author,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      if (comment.date.isNotEmpty)
                        Text(
                          comment.date,
                          style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (comment.likes > 0 || comment.dislikes > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (comment.likes > 0) ...[
                        const Icon(Icons.thumb_up_rounded, color: AppColors.onSurfaceMuted, size: 13),
                        const SizedBox(width: 3),
                        Text('${comment.likes}',
                            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                        const SizedBox(width: 8),
                      ],
                      if (comment.dislikes > 0) ...[
                        const Icon(Icons.thumb_down_rounded, color: AppColors.onSurfaceMuted, size: 13),
                        const SizedBox(width: 3),
                        Text('${comment.dislikes}',
                            style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
                      ],
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              comment.text,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 13, height: 1.55),
            ),
          ],
        ),
      ),
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
          BoxShadow(
              color: Color(0x60000000),
              blurRadius: 40,
              spreadRadius: -4,
              offset: Offset(0, 12)),
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
    );
  }
}
