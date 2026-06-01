class HdRezkaStreamSubtitles {
  // { code: { title, link } }
  final Map<String, Map<String, String>> subtitles;
  final List<String> keys;

  HdRezkaStreamSubtitles._({required this.subtitles, required this.keys});

  factory HdRezkaStreamSubtitles.empty() =>
      HdRezkaStreamSubtitles._(subtitles: {}, keys: []);

  /// [data]  — raw subtitle string, e.g. "[Русский]https://...vtt,[English]https://...vtt"
  /// [codes] — map of lang-title → language code, e.g. {"Русский": "ru"}
  factory HdRezkaStreamSubtitles.parse(String? data, Map<String, String> codes) {
    if (data == null || data.isEmpty) return HdRezkaStreamSubtitles.empty();

    final Map<String, Map<String, String>> result = {};
    for (final chunk in data.split(',')) {
      final bracketStart = chunk.indexOf('[');
      final bracketEnd = chunk.indexOf(']');
      if (bracketStart == -1 || bracketEnd == -1) continue;
      final lang = chunk.substring(bracketStart + 1, bracketEnd);
      final link = chunk.substring(bracketEnd + 1);
      final code = codes[lang] ?? lang;
      result[code] = {'title': lang, 'link': link};
    }
    return HdRezkaStreamSubtitles._(subtitles: result, keys: result.keys.toList());
  }

  /// Get subtitle link by code, title, or index (int).
  String? call(dynamic id) {
    if (subtitles.isEmpty) return null;
    if (id == null) return null;

    if (id is int) {
      if (id < keys.length) return subtitles[keys[id]]?['link'];
      return null;
    }

    final s = id.toString();
    if (subtitles.containsKey(s)) return subtitles[s]!['link'];

    for (final entry in subtitles.entries) {
      if (entry.value['title'] == s) return entry.value['link'];
    }
    throw ArgumentError('Subtitles "$id" is not defined');
  }

  @override
  String toString() => keys.toString();
}

class HdRezkaStream {
  final int? season;
  final int? episode;
  final String name;
  final int translatorId;
  final HdRezkaStreamSubtitles subtitles;

  // { resolution: [url1, url2, ...] }
  final Map<String, List<String>> _videos = {};

  HdRezkaStream({
    required this.season,
    required this.episode,
    required this.name,
    required this.translatorId,
    required this.subtitles,
  });

  Map<String, List<String>> get videos => Map.unmodifiable(_videos);

  void append(String resolution, String link) {
    _videos.putIfAbsent(resolution, () => []).add(link);
  }

  /// Get list of URLs for a resolution (fuzzy match, like original Python).
  List<String> call(String resolution) {
    final key = _videos.keys.firstWhere(
      (k) => k.contains(resolution),
      orElse: () => throw ArgumentError('Resolution "$resolution" is not defined'),
    );
    return _videos[key]!;
  }

  /// Best available URL for the given resolution (first link in list).
  String? bestUrl(String resolution) {
    try {
      return call(resolution).first;
    } catch (_) {
      return null;
    }
  }

  /// Sorted resolution keys, highest first.
  List<String> get sortedResolutions {
    final keys = _videos.keys.toList();
    keys.sort((a, b) {
      final na = int.tryParse(a.replaceAll(RegExp(r'\D'), '')) ?? 0;
      final nb = int.tryParse(b.replaceAll(RegExp(r'\D'), '')) ?? 0;
      return nb.compareTo(na);
    });
    return keys;
  }

  @override
  String toString() {
    final res = _videos.keys.toList();
    if (subtitles.subtitles.isNotEmpty) {
      return '<HdRezkaStream>: $res, subtitles=$subtitles';
    }
    return '<HdRezkaStream>: $res';
  }
}
