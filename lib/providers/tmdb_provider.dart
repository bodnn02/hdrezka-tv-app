import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/hdrezka_types.dart';
import '../core/services/tmdb_service.dart';
import 'content_provider.dart';

const _kTmdbApiKey = 'tmdb_api_key';

// Persisted TMDB API key — read once from SharedPreferences on first watch.
final tmdbApiKeyProvider = StateNotifierProvider<_TmdbKeyNotifier, String?>(
  (ref) => _TmdbKeyNotifier(),
  name: 'tmdbApiKeyProvider',
);

class _TmdbKeyNotifier extends StateNotifier<String?> {
  _TmdbKeyNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_kTmdbApiKey);
  }

  Future<void> save(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTmdbApiKey, key.trim());
    state = key.trim();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTmdbApiKey);
    state = null;
  }
}

// Frames with TMDB fallback.
// Returns HDRezka frames if non-empty, otherwise fetches TMDB backdrops.
final framesWithFallbackProvider = FutureProvider.family<List<String>, String>(
  (ref, url) async {
    final api    = await ref.watch(contentProvider(url).future);
    final frames = await api.frames;
    if (frames.isNotEmpty) return frames;

    final apiKey = ref.watch(tmdbApiKeyProvider);
    if (apiKey == null || apiKey.isEmpty) return [];

    final tmdb     = TmdbService(apiKey);
    final title    = await api.name;
    final year     = await api.releaseYear;
    final type     = await api.type;
    final isSeries = type == const TVSeries();

    return tmdb.getBackdrops(title: title, isSeries: isSeries, year: year);
  },
  name: 'framesWithFallbackProvider',
);
