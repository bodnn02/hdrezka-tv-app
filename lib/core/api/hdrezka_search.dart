import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'hdrezka_errors.dart';
import 'hdrezka_types.dart';

class FastSearchResult {
  final String title;
  final String url;
  final double? rating;

  const FastSearchResult({required this.title, required this.url, this.rating});

  @override
  String toString() => 'FastSearchResult($title, rating: $rating)';
}

class AdvancedSearchResult {
  final String title;
  final String url;
  final String image;
  final HdRezkaCategory? category;

  const AdvancedSearchResult({
    required this.title,
    required this.url,
    required this.image,
    this.category,
  });

  @override
  String toString() => 'AdvancedSearchResult($title)';
}

class SearchResultPage {
  final int page;
  final List<AdvancedSearchResult> items;

  const SearchResultPage({required this.page, required this.items});

  bool get isEmpty => items.isEmpty;
  int get length => items.length;
}

class HdRezkaSearch {
  final String origin;
  final Map<String, String> headers;
  final Map<String, String> cookies;

  HdRezkaSearch({
    required this.origin,
    Map<String, String>? headers,
    Map<String, String>? cookies,
  })  : headers = {...defaultHeaders, ...?headers},
        cookies = {...defaultCookies, ...?cookies};

  String get _cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  Future<List<FastSearchResult>> fastSearch(String query) async {
    final response = await http.post(
      Uri.parse('$origin/engine/ajax/search.php'),
      headers: {...headers, 'Cookie': _cookieHeader},
      body: {'q': query},
    );

    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, response.reasonPhrase ?? '');
    }

    final document = html_parser.parse(utf8.decode(response.bodyBytes));
    final results = <FastSearchResult>[];

    for (final item in document.querySelectorAll('.b-search__section_list li')) {
      final titleEl = item.querySelector('span.enty');
      final linkEl = item.querySelector('a');
      final ratingEl = item.querySelector('span.rating');

      if (titleEl == null || linkEl == null) continue;

      final title = titleEl.text.trim();
      final url = linkEl.attributes['href'] ?? '';
      final ratingText = ratingEl?.text.trim();
      final rating = ratingText != null ? double.tryParse(ratingText) : null;

      results.add(FastSearchResult(title: title, url: url, rating: rating));
    }
    return results;
  }

  Future<SearchResultPage> advancedSearch(String query, {int page = 1}) async {
    final uri = Uri.parse('$origin/search/').replace(queryParameters: {
      'do': 'search',
      'subaction': 'search',
      'q': query,
      'page': page.toString(),
    });

    final response = await http.get(
      uri,
      headers: {...headers, 'Cookie': _cookieHeader},
    );

    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, response.reasonPhrase ?? '');
    }

    final document = html_parser.parse(utf8.decode(response.bodyBytes));

    final title = document.querySelector('title')?.text ?? '';
    if (title == 'Sign In') throw LoginRequiredError();
    if (title == 'Verify') throw CaptchaError();

    final items = <AdvancedSearchResult>[];
    for (final item in document.querySelectorAll('.b-content__inline_item')) {
      final linkEl = item.querySelector('.b-content__inline_item-link a');
      final imgEl = item.querySelector('.b-content__inline_item-cover img');
      if (linkEl == null || imgEl == null) continue;

      final url = linkEl.attributes['href'] ?? '';
      final itemTitle = linkEl.text.trim();
      final image = imgEl.attributes['src'] ?? '';
      final catEl = item.querySelector('.cat');
      final category = catEl != null ? detectCategory(catEl.classes.toList()) : null;

      items.add(AdvancedSearchResult(
        title: itemTitle,
        url: url,
        image: image,
        category: category,
      ));
    }

    return SearchResultPage(page: page, items: items);
  }

  /// Fetch all pages until empty.
  Future<List<AdvancedSearchResult>> advancedSearchAll(String query) async {
    final all = <AdvancedSearchResult>[];
    int page = 1;
    while (true) {
      final result = await advancedSearch(query, page: page);
      if (result.isEmpty) break;
      all.addAll(result.items);
      page++;
    }
    return all;
  }

  static HdRezkaCategory? detectCategory(List<String> classes) {
    final filtered = classes.where((c) => c != 'cat').toList();
    if (filtered.contains('films')) return const Film();
    if (filtered.contains('series')) return const Series();
    if (filtered.contains('cartoons')) return const Cartoon();
    if (filtered.contains('animation')) return const Anime();
    if (filtered.isNotEmpty) return UnknownCategory(filtered.first);
    return null;
  }
}
