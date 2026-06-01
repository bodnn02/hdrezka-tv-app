import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'hdrezka_errors.dart';
import 'hdrezka_search.dart';
import 'hdrezka_session.dart';
import 'hdrezka_types.dart';

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

class HdRezkaBrowse {
  static Future<List<AdvancedSearchResult>> getCategory(
    HdRezkaSession session,
    String categoryPath, {
    int page = 1,
    String filter = 'watching',
  }) async {
    final origin = session.origin;
    if (origin == null) throw StateError('Session origin is required for browsing');

    final uri = Uri.parse('$origin/$categoryPath/').replace(queryParameters: {
      'filter': filter,
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

    // Collections are in .b-content__collections_list .b-content__collections_item
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
