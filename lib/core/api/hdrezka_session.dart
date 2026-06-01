import 'hdrezka_api.dart';
import 'hdrezka_errors.dart';
import 'hdrezka_search.dart';
import 'hdrezka_types.dart';

class HdRezkaSession {
  final String? origin;
  final Map<String, String> headers;
  Map<String, String> cookies;
  List<int> translatorsPriority;
  List<int> translatorsNonPriority;

  HdRezkaSession({
    String? origin,
    Map<String, String>? headers,
    Map<String, String>? cookies,
    List<int>? translatorsPriority,
    List<int>? translatorsNonPriority,
  })  : origin = origin != null ? _extractOrigin(origin) : null,
        headers = {...defaultHeaders, ...?headers},
        cookies = {...defaultCookies, ...?cookies},
        translatorsPriority = translatorsPriority ?? defaultTranslatorsPriority,
        translatorsNonPriority = translatorsNonPriority ?? defaultTranslatorsNonPriority;

  static String _extractOrigin(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}';
  }

  Future<bool> login(String email, String password) async {
    final o = origin;
    if (o == null) throw StateError('origin is required for login');
    final api = HdRezkaApi(
      o,
      headers: headers,
      cookies: cookies,
      translatorsPriority: translatorsPriority,
      translatorsNonPriority: translatorsNonPriority,
    );
    final result = await api.login(email, password);
    if (result) {
      cookies = {...cookies, ...api.cookies};
    }
    return result;
  }

  /// Get content by full URL or path relative to [origin].
  Future<HdRezkaApi> get(String url) async {
    String fullUrl = url;
    final o = origin;
    if (o != null) {
      final uri = Uri.parse(url);
      if (!uri.hasScheme) {
        fullUrl = '$o/${uri.path.replaceFirst(RegExp(r'^/'), '')}';
      } else {
        fullUrl = '$o/${uri.path.replaceFirst(RegExp(r'^/'), '')}';
      }
    }

    final api = HdRezkaApi(
      fullUrl,
      headers: headers,
      cookies: cookies,
      translatorsPriority: translatorsPriority,
      translatorsNonPriority: translatorsNonPriority,
    );

    // Trigger page load to catch errors early
    try {
      await api.soup;
    } catch (e) {
      rethrow;
    }
    return api;
  }

  HdRezkaSearch get searchEngine {
    final o = origin;
    if (o == null) throw StateError('origin is required for search');
    return HdRezkaSearch(origin: o, headers: headers, cookies: cookies);
  }

  Future<List<FastSearchResult>> search(String query) async {
    return searchEngine.fastSearch(query);
  }

  Future<List<AdvancedSearchResult>> searchAll(String query) async {
    return searchEngine.advancedSearchAll(query);
  }
}
