import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/hdrezka_stream.dart';
import 'content_provider.dart';

class StreamParams {
  final String url;
  final int? season;
  final int? episode;
  final int? translatorId;

  const StreamParams({
    required this.url,
    this.season,
    this.episode,
    this.translatorId,
  });

  @override
  bool operator ==(Object other) =>
      other is StreamParams &&
      other.url == url &&
      other.season == season &&
      other.episode == episode &&
      other.translatorId == translatorId;

  @override
  int get hashCode => Object.hash(url, season, episode, translatorId);
}

final streamProvider = FutureProvider.family<HdRezkaStream, StreamParams>(
  (ref, params) async {
    final api = await ref.watch(contentProvider(params.url).future);
    return api.getStream(
      season: params.season,
      episode: params.episode,
      translation: params.translatorId,
    );
  },
  name: 'streamProvider',
);
