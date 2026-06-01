import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkEntry {
  final String url;
  final String title;
  final String thumbnail;
  final String? category;
  final DateTime addedAt;

  const BookmarkEntry({
    required this.url,
    required this.title,
    required this.thumbnail,
    this.category,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'url': url,
    'title': title,
    'thumbnail': thumbnail,
    if (category != null) 'category': category,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  factory BookmarkEntry.fromJson(Map<String, dynamic> j) => BookmarkEntry(
    url: j['url'] as String,
    title: j['title'] as String,
    thumbnail: j['thumbnail'] as String? ?? '',
    category: j['category'] as String?,
    addedAt: DateTime.fromMillisecondsSinceEpoch((j['addedAt'] as int?) ?? 0),
  );
}

class BookmarksNotifier extends StateNotifier<List<BookmarkEntry>> {
  BookmarksNotifier() : super([]) {
    _load();
  }

  static const _key = 'bookmarks_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(BookmarkEntry.fromJson)
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  bool isBookmarked(String url) => state.any((e) => e.url == url);

  Future<void> toggle({
    required String url,
    required String title,
    required String thumbnail,
    String? category,
  }) async {
    if (isBookmarked(url)) {
      state = state.where((e) => e.url != url).toList();
    } else {
      final entry = BookmarkEntry(
        url: url,
        title: title,
        thumbnail: thumbnail,
        category: category,
        addedAt: DateTime.now(),
      );
      state = [entry, ...state];
    }
    await _save();
  }

  Future<void> remove(String url) async {
    state = state.where((e) => e.url != url).toList();
    await _save();
  }

  Future<void> clear() async {
    state = [];
    await _save();
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<BookmarkEntry>>(
  (_) => BookmarksNotifier(),
);
