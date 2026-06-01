import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/hdrezka_api.dart';
import '../core/api/hdrezka_types.dart';
import 'session_provider.dart';

final contentProvider = FutureProvider.family<HdRezkaApi, String>(
  (ref, url) async {
    // Keep cached for 5 minutes after last listener disposes
    final link = ref.keepAlive();
    Timer(const Duration(minutes: 5), link.close);

    final session = ref.watch(sessionProvider);
    return session.get(url);
  },
  name: 'contentProvider',
);

final episodesInfoProvider = FutureProvider.family<List<SeasonInfo>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.episodesInfo;
  },
  name: 'episodesInfoProvider',
);

// Loads episodes for a specific translator only — avoids fetching all translators at once
final episodesForTranslatorProvider = FutureProvider.family<List<SeasonInfo>, ({String url, int translatorId})>(
  (ref, params) async {
    final api = await ref.watch(contentProvider(params.url).future);
    return api.getEpisodesInfoForTranslator(params.translatorId);
  },
  name: 'episodesForTranslatorProvider',
);

final translatorsProvider = FutureProvider.family<Map<int, TranslatorInfo>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.translators;
  },
  name: 'translatorsProvider',
);

final thumbnailHqProvider = FutureProvider.family<String, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.thumbnailHQ;
  },
  name: 'thumbnailHqProvider',
);

final descriptionProvider = FutureProvider.family<String, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.description;
  },
  name: 'descriptionProvider',
);

final actorsProvider = FutureProvider.family<List<ActorInfo>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.actors;
  },
  name: 'actorsProvider',
);

final tagsProvider = FutureProvider.family<List<String>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.tags;
  },
  name: 'tagsProvider',
);

final framesProvider = FutureProvider.family<List<String>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.frames;
  },
  name: 'framesProvider',
);

final relatedReleasesProvider = FutureProvider.family<List<RelatedRelease>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.relatedReleases;
  },
  name: 'relatedReleasesProvider',
);

final metaProvider = FutureProvider.family<ContentMeta, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.meta;
  },
  name: 'metaProvider',
);

final commentsProvider = FutureProvider.family<List<CommentInfo>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.comments;
  },
  name: 'commentsProvider',
);

final similarProvider = FutureProvider.family<List<SimilarContent>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.similar;
  },
  name: 'similarProvider',
);

// Tracks user vote per content URL: null = not voted, true = liked, false = disliked
final userVoteProvider = StateProvider.family<bool?, String>(
  (ref, url) => null,
  name: 'userVoteProvider',
);
