import 'dart:convert';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://api.themoviedb.org/3';
const _imageBase = 'https://image.tmdb.org/t/p/w1280';

class TmdbService {
  final String apiKey;

  const TmdbService(this.apiKey);

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      };

  // Search movie or TV series by title + year, returns TMDB id or null.
  Future<_TmdbMatch?> _findMatch({
    required String title,
    required bool isSeries,
    int? year,
  }) async {
    final type = isSeries ? 'tv' : 'movie';
    final yearParam = year != null
        ? (isSeries ? '&first_air_date_year=$year' : '&year=$year')
        : '';
    final encoded = Uri.encodeQueryComponent(title);
    final uri = Uri.parse(
        '$_baseUrl/search/$type?query=$encoded&language=ru-RU$yearParam');

    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) return null;

    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final results = (data['results'] as List?)?.cast<Map<String, dynamic>>();
    if (results == null || results.isEmpty) return null;

    // Best match: first result (TMDB already sorts by relevance)
    final first = results.first;
    return _TmdbMatch(
      id: first['id'] as int,
      isSeries: isSeries,
    );
  }

  // Fetch backdrop image URLs for a movie or TV series.
  Future<List<String>> getBackdrops({
    required String title,
    required bool isSeries,
    int? year,
  }) async {
    final match = await _findMatch(title: title, isSeries: isSeries, year: year);
    if (match == null) return [];

    final type = match.isSeries ? 'tv' : 'movie';
    final uri = Uri.parse('$_baseUrl/$type/${match.id}/images?include_image_language=null');

    final resp = await http.get(uri, headers: _headers);
    if (resp.statusCode != 200) return [];

    final data = json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final backdrops = (data['backdrops'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return backdrops
        .take(12)
        .map((b) => '$_imageBase${b['file_path']}')
        .toList();
  }
}

class _TmdbMatch {
  final int id;
  final bool isSeries;
  const _TmdbMatch({required this.id, required this.isSeries});
}
