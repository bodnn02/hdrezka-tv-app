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

final translatorsProvider = FutureProvider.family<Map<int, TranslatorInfo>, String>(
  (ref, url) async {
    final api = await ref.watch(contentProvider(url).future);
    return api.translators;
  },
  name: 'translatorsProvider',
);
