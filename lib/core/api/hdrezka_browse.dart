import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'hdrezka_errors.dart';
import 'hdrezka_search.dart';
import 'hdrezka_session.dart';

class CollectionResult {
  final String title;
  final String url;
  final String image;
  final int? itemCount;

  const CollectionResult({
    required this.title,
    required this.url,
    required this.image,
    this.itemCount,
  });
}

// Genre slug → display label per category
const Map<String, Map<String, String>> categoryGenres = {
  'films': {
    'abonement': 'Абонемент',
    'boevik': 'Боевик',
    'vestern': 'Вестерн',
    'voennyi': 'Военный',
    'detektiv': 'Детектив',
    'detskii': 'Детский',
    'dokumentalnyi': 'Документальный',
    'drama': 'Драма',
    'istoricheskii': 'Исторический',
    'komediya': 'Комедия',
    'kriminal': 'Криминал',
    'melodrama': 'Мелодрама',
    'mistika': 'Мистика',
    'muzei': 'Мюзикл',
    'priklyucheniya': 'Приключения',
    'semeinyi': 'Семейный',
    'sport': 'Спорт',
    'triller': 'Триллер',
    'uzhasy': 'Ужасы',
    'fantastika': 'Фантастика',
    'fentezi': 'Фэнтези',
    'erotika': 'Эротика',
  },
  'series': {
    'abonement': 'Абонемент',
    'boevik': 'Боевик',
    'vestern': 'Вестерн',
    'voennyi': 'Военный',
    'detektiv': 'Детектив',
    'detskii': 'Детский',
    'dokumentalnyi': 'Документальный',
    'drama': 'Драма',
    'istoricheskii': 'Исторический',
    'komediya': 'Комедия',
    'kriminal': 'Криминал',
    'melodrama': 'Мелодрама',
    'mistika': 'Мистика',
    'muzei': 'Мюзикл',
    'priklyucheniya': 'Приключения',
    'semeinyi': 'Семейный',
    'sport': 'Спорт',
    'triller': 'Триллер',
    'uzhasy': 'Ужасы',
    'fantastika': 'Фантастика',
    'fentezi': 'Фэнтези',
  },
  'cartoons': {
    'abonement': 'Абонемент',
    'boevik': 'Боевик',
    'vestern': 'Вестерн',
    'voennyi': 'Военный',
    'detektiv': 'Детектив',
    'detskii': 'Детский',
    'dokumentalnyi': 'Документальный',
    'drama': 'Драма',
    'istoricheskii': 'Исторический',
    'komediya': 'Комедия',
    'kriminal': 'Криминал',
    'melodrama': 'Мелодрама',
    'mistika': 'Мистика',
    'muzei': 'Мюзикл',
    'priklyucheniya': 'Приключения',
    'semeinyi': 'Семейный',
    'sport': 'Спорт',
    'triller': 'Триллер',
    'uzhasy': 'Ужасы',
    'fantastika': 'Фантастика',
    'fentezi': 'Фэнтези',
  },
  'animation': {
    'boevik': 'Боевик',
    'detektiv': 'Детектив',
    'drama': 'Драма',
    'istoricheskii': 'Исторический',
    'komediya': 'Комедия',
    'melodrama': 'Мелодрама',
    'mistika': 'Мистика',
    'priklyucheniya': 'Приключения',
    'triller': 'Триллер',
    'uzhasy': 'Ужасы',
    'fantastika': 'Фантастика',
    'fentezi': 'Фэнтези',
  },
};

class BrowseParams {
  final String category;
  final int page;
  final String filter;
  final String? genre;
  final int? year;

  const BrowseParams({
    required this.category,
    this.page = 1,
    this.filter = 'watching',
    this.genre,
    this.year,
  });

  @override
  bool operator ==(Object other) =>
      other is BrowseParams &&
      category == other.category &&
      page == other.page &&
      filter == other.filter &&
      genre == other.genre &&
      year == other.year;

  @override
  int get hashCode => Object.hash(category, page, filter, genre, year);
}

class HdRezkaBrowse {
  /// Builds the request URI for a browse page.
  /// HDrezka URL patterns:
  ///   /films/?filter=watching&page=2         — plain browse
  ///   /films/genre/boevik/?filter=...&page=2 — genre filter
  ///   /films/year/2024/?filter=...&page=2    — year filter
  static Uri _buildUri(String origin, BrowseParams p) {
    String path;
    if (p.genre != null && p.genre!.isNotEmpty) {
      path = '/${ p.category}/genre/${p.genre}/';
    } else if (p.year != null) {
      path = '/${p.category}/year/${p.year}/';
    } else {
      path = '/${p.category}/';
    }
    return Uri.parse('$origin$path').replace(queryParameters: {
      'filter': p.filter,
      'page': p.page.toString(),
    });
  }

  static Future<List<AdvancedSearchResult>> getCategory(
    HdRezkaSession session,
    String categoryPath, {
    int page = 1,
    String filter = 'watching',
    String? genre,
    int? year,
  }) async {
    return getCategoryParams(
      session,
      BrowseParams(
        category: categoryPath,
        page: page,
        filter: filter,
        genre: genre,
        year: year,
      ),
    );
  }

  static Future<List<AdvancedSearchResult>> getCategoryParams(
    HdRezkaSession session,
    BrowseParams params,
  ) async {
    final origin = session.origin;
    if (origin == null) throw StateError('Session origin is required for browsing');

    final uri = _buildUri(origin, params);

    final cookieHeader = session.cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final response = await http.get(
      uri,
      headers: {...session.headers, 'Cookie': cookieHeader},
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
      final imgEl  = item.querySelector('.b-content__inline_item-cover img');
      if (linkEl == null || imgEl == null) continue;

      final url       = linkEl.attributes['href'] ?? '';
      final itemTitle = linkEl.text.trim();
      final image     = imgEl.attributes['src'] ?? '';
      final catEl     = item.querySelector('.cat');
      final category  = catEl != null
          ? HdRezkaSearch.detectCategory(catEl.classes.toList())
          : null;

      items.add(AdvancedSearchResult(
        title: itemTitle,
        url: url,
        image: image,
        category: category,
      ));
    }
    return items;
  }

  static Future<List<CollectionResult>> getCollections(
    HdRezkaSession session, {
    int page = 1,
  }) async {
    final origin = session.origin;
    if (origin == null) throw StateError('Session origin is required for browsing');

    final uri = Uri.parse('$origin/collections/').replace(queryParameters: {
      'page': page.toString(),
    });

    final cookieHeader = session.cookies.entries
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    final response = await http.get(
      uri,
      headers: {...session.headers, 'Cookie': cookieHeader},
    );

    if (response.statusCode != 200) {
      throw HttpError(response.statusCode, response.reasonPhrase ?? '');
    }

    final document = html_parser.parse(utf8.decode(response.bodyBytes));

    final pageTitle = document.querySelector('title')?.text ?? '';
    if (pageTitle == 'Sign In') throw LoginRequiredError();
    if (pageTitle == 'Verify') throw CaptchaError();

    final collections = <CollectionResult>[];

    for (final item in document.querySelectorAll('.b-content__collections_item')) {
      final linkEl  = item.querySelector('a');
      final imgEl   = item.querySelector('img');
      final titleEl = item.querySelector('.title');
      final countEl = item.querySelector('.num');

      if (linkEl == null || imgEl == null) continue;

      final url        = linkEl.attributes['href'] ?? '';
      final itemTitle  = titleEl?.text.trim() ?? linkEl.text.trim();
      final image      = imgEl.attributes['src'] ?? '';
      final countText  = countEl?.text.trim().replaceAll(RegExp(r'[^\d]'), '');
      final itemCount  = countText != null ? int.tryParse(countText) : null;

      if (url.isEmpty || itemTitle.isEmpty) continue;

      collections.add(CollectionResult(
        title: itemTitle,
        url: url,
        image: image,
        itemCount: itemCount,
      ));
    }

    return collections;
  }
}
