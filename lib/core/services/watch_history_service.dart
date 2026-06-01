import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchHistoryEntry {
  final String url;
  final String title;
  final String thumbnail;
  final int? season;
  final int? episode;
  final int? translatorId;
  final Duration position;
  final Duration? total;
  final DateTime watchedAt;

  const WatchHistoryEntry({
    required this.url,
    required this.title,
    required this.thumbnail,
    this.season,
    this.episode,
    this.translatorId,
    required this.position,
    this.total,
    required this.watchedAt,
  });

  double get progress {
    final t = total;
    if (t == null || t.inSeconds == 0) return 0;
    return (position.inSeconds / t.inSeconds).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'thumbnail': thumbnail,
    if (season != null) 'season': season,
    if (episode != null) 'episode': episode,
    if (translatorId != null) 'translatorId': translatorId,
    'positionSec': position.inSeconds,
    if (total != null) 'totalSec': total!.inSeconds,
    'watchedAt': watchedAt.millisecondsSinceEpoch,
  };

  factory WatchHistoryEntry.fromJson(Map<String, dynamic> j) => WatchHistoryEntry(
    url: j['url'] as String,
    title: j['title'] as String,
    thumbnail: j['thumbnail'] as String? ?? '',
    season: j['season'] as int?,
    episode: j['episode'] as int?,
    translatorId: j['translatorId'] as int?,
    position: Duration(seconds: (j['positionSec'] as int?) ?? 0),
    total: j['totalSec'] != null ? Duration(seconds: j['totalSec'] as int) : null,
    watchedAt: DateTime.fromMillisecondsSinceEpoch((j['watchedAt'] as int?) ?? 0),
  );

  WatchHistoryEntry copyWith({
    Duration? position,
    Duration? total,
    DateTime? watchedAt,
    int? season,
    int? episode,
    int? translatorId,
  }) => WatchHistoryEntry(
    url: url,
    title: title,
    thumbnail: thumbnail,
    season: season ?? this.season,
    episode: episode ?? this.episode,
    translatorId: translatorId ?? this.translatorId,
    position: position ?? this.position,
    total: total ?? this.total,
    watchedAt: watchedAt ?? this.watchedAt,
  );
}

class WatchHistoryNotifier extends StateNotifier<List<WatchHistoryEntry>> {
  WatchHistoryNotifier() : super([]) {
    _load();
  }

  static const _key = 'watch_history_v1';
  static const _maxEntries = 50;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(WatchHistoryEntry.fromJson)
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> record({
    required String url,
    required String title,
    required String thumbnail,
    int? season,
    int? episode,
    int? translatorId,
    required Duration position,
    Duration? total,
  }) async {
    final now = DateTime.now();
    final existing = state.indexWhere((e) => e.url == url && e.season == season && e.episode == episode);

    final entry = WatchHistoryEntry(
      url: url,
      title: title,
      thumbnail: thumbnail,
      season: season,
      episode: episode,
      translatorId: translatorId,
      position: position,
      total: total,
      watchedAt: now,
    );

    final updated = List<WatchHistoryEntry>.from(state);
    if (existing != -1) {
      updated.removeAt(existing);
    }
    updated.insert(0, entry);

    if (updated.length > _maxEntries) {
      updated.removeRange(_maxEntries, updated.length);
    }

    state = updated;
    await _save();
  }

  Future<void> remove(String url, {int? season, int? episode}) async {
    state = state.where((e) => !(e.url == url && e.season == season && e.episode == episode)).toList();
    await _save();
  }

  Future<void> clear() async {
    state = [];
    await _save();
  }

  WatchHistoryEntry? getEntry(String url, {int? season, int? episode}) {
    try {
      return state.firstWhere((e) => e.url == url && e.season == season && e.episode == episode);
    } catch (_) {
      return null;
    }
  }
}

final watchHistoryProvider = StateNotifierProvider<WatchHistoryNotifier, List<WatchHistoryEntry>>(
  (_) => WatchHistoryNotifier(),
);
