import 'dart:convert';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'hdrezka_errors.dart';
import 'hdrezka_stream.dart';
import 'hdrezka_types.dart';

class HdRezkaApi {
  final String url;
  final String origin;
  final Map<String, String> headers;
  Map<String, String> cookies;
  List<int> translatorsPriority;
  List<int> translatorsNonPriority;

  // Lazy-loaded cache fields
  http.Response? _pageCache;
  dom.Document? _soupCache;
  int? _idCache;
  List<String>? _namesCache;
  String? _descriptionCache;
  String? _thumbnailCache;
  String? _thumbnailHqCache;
  int? _releaseYearCache;
  HdRezkaFormat? _typeCache;
  HdRezkaCategory? _categoryCache;
  HdRezkaRating? _ratingCache;
  Map<int, TranslatorInfo>? _translatorsCache;
  Map<String, TranslatorInfo>? _translatorsNamesCache;
  Map<int, SeriesTranslatorData>? _seriesInfoCache;
  List<SeasonInfo>? _episodesInfoCache;
  List<Map<String, String>>? _otherPartsCache;
  List<ActorInfo>? _actorsCache;
  List<String>? _tagsCache;
  List<String>? _framesCache;
  List<RelatedRelease>? _relatedReleasesCache;
  ContentMeta? _metaCache;
  List<CommentInfo>? _commentsCache;
  List<SimilarContent>? _similarCache;

  HdRezkaApi(
    String rawUrl, {
    Map<String, String>? headers,
    Map<String, String>? cookies,
    List<int>? translatorsPriority,
    List<int>? translatorsNonPriority,
  })  : url = '${rawUrl.split('.html')[0]}.html',
        origin = _extractOrigin(rawUrl),
        headers = {...defaultHeaders, ...?headers},
        cookies = {...defaultCookies, ...?cookies},
        translatorsPriority = translatorsPriority ?? defaultTranslatorsPriority,
        translatorsNonPriority = translatorsNonPriority ?? defaultTranslatorsNonPriority;

  static String _extractOrigin(String url) {
    final uri = Uri.parse(url);
    return '${uri.scheme}://${uri.host}';
  }

  String get _cookieHeader =>
      cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');

  // ---------------------------------------------------------------------------
  // HTTP helpers
  // ---------------------------------------------------------------------------

  Future<http.Response> _get(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {...headers, 'Cookie': _cookieHeader},
    );
    if (response.statusCode == 200) return response;
    throw HttpError(response.statusCode, response.reasonPhrase ?? '');
  }

  Future<http.Response> _post(String url, Map<String, String> body) async {
    final response = await http.post(
      Uri.parse(url),
      headers: {...headers, 'Cookie': _cookieHeader},
      body: body,
    );
    return response;
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  Future<bool> login(String email, String password, {bool raiseException = true}) async {
    final response = await _post('$origin/ajax/login/', {
      'login_name': email,
      'login_password': password,
    });
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (data['success'] == true) {
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        _parseCookies(setCookie);
      }
      return true;
    }
    if (raiseException) throw LoginFailed(data['message']?.toString() ?? 'Unknown error');
    return false;
  }

  void _parseCookies(String setCookieHeader) {
    for (final part in setCookieHeader.split(',')) {
      final cookiePart = part.split(';').first.trim();
      final eqIdx = cookiePart.indexOf('=');
      if (eqIdx != -1) {
        final key = cookiePart.substring(0, eqIdx).trim();
        final value = cookiePart.substring(eqIdx + 1).trim();
        cookies[key] = value;
      }
    }
  }

  static Map<String, String> makeCookies(String userId, String passwordHash) =>
      {'dle_user_id': userId, 'dle_password': passwordHash};

  // ---------------------------------------------------------------------------
  // Page / soup
  // ---------------------------------------------------------------------------

  Future<http.Response> get page async {
    _pageCache ??= await _get(url);
    return _pageCache!;
  }

  Future<dom.Document> get soup async {
    if (_soupCache != null) return _soupCache!;
    final p = await page;
    final doc = html_parser.parse(utf8.decode(p.bodyBytes));
    final title = doc.querySelector('title')?.text ?? '';
    if (title == 'Sign In') throw LoginRequiredError();
    if (title == 'Verify') throw CaptchaError();
    _soupCache = doc;
    return _soupCache!;
  }

  // ---------------------------------------------------------------------------
  // Content properties
  // ---------------------------------------------------------------------------

  Future<int> get id async {
    if (_idCache != null) return _idCache!;
    final s = await soup;

    String? val;
    val ??= s.querySelector('#post_id')?.attributes['value'];
    val ??= s.querySelector('#send-video-issue')?.attributes['data-id'];
    val ??= s.querySelector('#user-favorites-holder')?.attributes['data-post_id'];
    val ??= url.split('/').last.split('-').first;

    _idCache = int.parse(val!);
    return _idCache!;
  }

  Future<List<String>> get names async {
    if (_namesCache != null) return _namesCache!;
    final s = await soup;
    final text = s.querySelector('.b-post__title')?.text ?? '';
    _namesCache = text.split('/').map((e) => e.trim()).toList();
    return _namesCache!;
  }

  Future<String> get name async => (await names).first;

  Future<String?> get origName async {
    final list = await origNames;
    return list.isNotEmpty ? list.last : null;
  }

  Future<List<String>> get origNames async {
    final s = await soup;
    final el = s.querySelector('.b-post__origtitle');
    if (el == null) return [];
    return el.text.split('/').map((e) => e.trim()).toList();
  }

  Future<String> get description async {
    if (_descriptionCache != null) return _descriptionCache!;
    final s = await soup;
    _descriptionCache =
        s.querySelector('.b-post__description_text')?.text.trim() ?? '';
    return _descriptionCache!;
  }

  Future<String> get thumbnail async {
    if (_thumbnailCache != null) return _thumbnailCache!;
    final s = await soup;
    _thumbnailCache =
        s.querySelector('.b-sidecover img')?.attributes['src'] ?? '';
    return _thumbnailCache!;
  }

  Future<String> get thumbnailHQ async {
    if (_thumbnailHqCache != null) return _thumbnailHqCache!;
    final s = await soup;
    _thumbnailHqCache =
        s.querySelector('.b-sidecover a')?.attributes['href'] ?? '';
    return _thumbnailHqCache!;
  }

  Future<int?> get releaseYear async {
    if (_releaseYearCache != null) return _releaseYearCache;
    final s = await soup;
    final el = s.querySelector('.b-content__main .b-post__info a[href*="/year/"]');
    if (el != null) {
      final href = el.attributes['href'] ?? '';
      final match = RegExp(r'\d{4}').firstMatch(href);
      if (match != null) {
        _releaseYearCache = int.parse(match.group(0)!);
        return _releaseYearCache;
      }
    }
    return null;
  }

  Future<HdRezkaFormat> get type async {
    if (_typeCache != null) return _typeCache!;
    final s = await soup;
    final content =
        s.querySelector('meta[property="og:type"]')?.attributes['content'] ?? '';
    if (content == 'video.tv_series') {
      _typeCache = const TVSeries();
    } else if (content == 'video.movie') {
      _typeCache = const Movie();
    } else {
      _typeCache = UnknownFormat(content);
    }
    return _typeCache!;
  }

  Future<HdRezkaCategory> get category async {
    if (_categoryCache != null) return _categoryCache!;
    final uri = Uri.parse(url);
    final cat = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
    if (cat == 'films') _categoryCache = const Film();
    else if (cat == 'series') _categoryCache = const Series();
    else if (cat == 'cartoons') _categoryCache = const Cartoon();
    else if (cat == 'animation') _categoryCache = const Anime();
    else _categoryCache = UnknownCategory(cat);
    return _categoryCache!;
  }

  Future<HdRezkaRating> get rating async {
    if (_ratingCache != null) return _ratingCache!;
    final s = await soup;
    final wrapper = s.querySelector('.b-post__rating');
    if (wrapper != null) {
      final ratingText = wrapper.querySelector('.num')?.text.trim() ?? '';
      final votesText = wrapper.querySelector('.votes')?.text.trim()
          .replaceAll('(', '').replaceAll(')', '') ?? '0';
      _ratingCache = HdRezkaRating(
        value: double.tryParse(ratingText) ?? 0,
        votes: int.tryParse(votesText) ?? 0,
      );
    } else {
      _ratingCache = const HdRezkaEmptyRating();
    }
    return _ratingCache!;
  }

  Future<Map<int, TranslatorInfo>> get translators async {
    if (_translatorsCache != null) return _translatorsCache!;
    final s = await soup;
    final p = await page;
    final arr = <int, TranslatorInfo>{};

    final translatorsList = s.querySelector('#translators-list');
    if (translatorsList != null) {
      for (final child in translatorsList.children) {
        final idStr = child.attributes['data-translator_id'];
        if (idStr == null) continue;
        final id = int.tryParse(idStr);
        if (id == null) continue;
        var name = child.text.trim();
        final premium = child.classes.contains('b-prem_translator');
        final img = child.querySelector('img');
        if (img != null) {
          final lang = img.attributes['title'];
          if (lang != null && !name.contains(lang)) {
            name += ' ($lang)';
          }
        }
        arr[id] = TranslatorInfo(id: id, name: name, premium: premium);
      }
    }

    if (arr.isEmpty) {
      // auto-detect from page JS
      final translatorId = _autoDetectTranslatorId(utf8.decode(p.bodyBytes), await type);
      final translatorName = _autoDetectTranslatorName(s);
      if (translatorId != null) {
        arr[translatorId] = TranslatorInfo(
          id: translatorId,
          name: translatorName ?? 'Unknown',
          premium: false,
        );
      }
    }

    _translatorsCache = arr;
    return arr;
  }

  static int? _autoDetectTranslatorId(String pageText, HdRezkaFormat contentType) {
    final eventName = contentType == const TVSeries()
        ? 'initCDNSeriesEvents'
        : 'initCDNMoviesEvents';
    final marker = 'sof.tv.$eventName';
    final idx = pageText.indexOf(marker);
    if (idx == -1) return null;
    final after = pageText.substring(idx);
    final braceIdx = after.indexOf('{');
    if (braceIdx == -1) return null;
    final segment = after.substring(0, braceIdx);
    final parts = segment.split(',');
    if (parts.length >= 2) {
      return int.tryParse(parts[1].trim());
    }
    return null;
  }

  static String? _autoDetectTranslatorName(dom.Document s) {
    final table = s.querySelector('.b-post__info');
    if (table == null) return null;
    for (final tr in table.querySelectorAll('tr')) {
      if (tr.text.contains('переводе')) {
        final tds = tr.querySelectorAll('td');
        return tds.isNotEmpty ? tds.last.text.trim() : null;
      }
    }
    return null;
  }

  Future<Map<String, TranslatorInfo>> get translatorsNames async {
    if (_translatorsNamesCache != null) return _translatorsNamesCache!;
    final t = await translators;
    _translatorsNamesCache = {for (final e in t.entries) e.value.name: e.value};
    return _translatorsNamesCache!;
  }

  Map<int, TranslatorInfo> sortTranslators(
    Map<int, TranslatorInfo> input, {
    List<int>? priority,
    List<int>? nonPriority,
  }) {
    final effectivePriority = priority ?? translatorsPriority;
    final effectiveNonPriority = nonPriority ?? translatorsNonPriority;

    final priorMap = <int, int>{};
    for (var i = 0; i < effectivePriority.length; i++) {
      priorMap[effectivePriority[i]] = i + 1;
    }
    final maxIdx = priorMap.length + 1;
    for (var i = 0; i < effectiveNonPriority.length; i++) {
      final id = effectiveNonPriority[i];
      if (!priorMap.containsKey(id)) {
        priorMap[id] = maxIdx + i + 1;
      }
    }

    final entries = input.entries.toList()
      ..sort((a, b) =>
          (priorMap[a.key] ?? maxIdx).compareTo(priorMap[b.key] ?? maxIdx));
    return Map.fromEntries(entries);
  }

  Future<List<Map<String, String>>> get otherParts async {
    if (_otherPartsCache != null) return _otherPartsCache!;
    final s = await soup;
    final parts = s.querySelector('.b-post__partcontent');
    final other = <Map<String, String>>[];
    if (parts != null) {
      for (final item in parts.querySelectorAll('.b-post__partcontent_item')) {
        final title = item.querySelector('.title')?.text ?? '';
        if (item.classes.contains('current')) {
          other.add({title: url});
        } else {
          other.add({title: item.attributes['data-url'] ?? ''});
        }
      }
    }
    _otherPartsCache = other;
    return other;
  }

  Future<List<ActorInfo>> get actors async {
    if (_actorsCache != null) return _actorsCache!;
    final s = await soup;
    final result = <ActorInfo>[];
    for (final el in s.querySelectorAll('.b-post__info .persons-list-holder .b-persons__actor')) {
      final name = el.querySelector('.b-persons__actor_name')?.text.trim() ?? '';
      if (name.isEmpty) continue;
      final link = el.querySelector('a');
      final photo = el.querySelector('img')?.attributes['src'];
      result.add(ActorInfo(name: name, url: link?.attributes['href'], photo: photo));
    }
    _actorsCache = result;
    return result;
  }

  Future<List<String>> get tags async {
    if (_tagsCache != null) return _tagsCache!;
    final s = await soup;
    final result = <String>[];
    for (final el in s.querySelectorAll('.b-post__info .b-post__tags a')) {
      final text = el.text.trim();
      if (text.isNotEmpty) result.add(text);
    }
    _tagsCache = result;
    return result;
  }

  Future<List<String>> get frames async {
    if (_framesCache != null) return _framesCache!;
    final s = await soup;
    final result = <String>[];
    for (final el in s.querySelectorAll('.b-post__images a')) {
      final href = el.attributes['href'] ?? '';
      if (href.isNotEmpty) result.add(href);
    }
    _framesCache = result;
    return result;
  }

  Future<ContentMeta> get meta async {
    if (_metaCache != null) return _metaCache!;
    final s = await soup;
    final table = s.querySelector('.b-post__info');

    String? slogan;
    String? releaseDate;
    final countries = <String>[];
    final directors = <String>[];
    final genres = <String>[];
    String? quality;
    String? translation;
    String? ageRating;
    String? duration;
    final collections = <String>[];
    final ratings = <RatingInfo>[];
    String? status;
    String? origTitle;

    // original title from dedicated element
    origTitle = s.querySelector('.b-post__origtitle')?.text.trim();

    // status badge (e.g. "Завершен (все серии)")
    status = s.querySelector('.b-post__info_rates .b-post__episodesbadge')?.text.trim();
    status ??= s.querySelector('.b-post__episodesbadge')?.text.trim();

    if (table != null) {
      for (final tr in table.querySelectorAll('tr')) {
        final cells = tr.querySelectorAll('td');
        if (cells.length < 2) continue;
        final label = cells[0].text.toLowerCase();
        final valueCell = cells[1];

        if (label.contains('слоган')) {
          slogan = valueCell.text.trim().replaceAll(RegExp(r'^«|»$'), '').trim();
        } else if (label.contains('дата выхода') || label.contains('год')) {
          releaseDate = valueCell.text.trim();
        } else if (label.contains('страна')) {
          for (final a in valueCell.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty) countries.add(t);
          }
        } else if (label.contains('режиссер') || label.contains('режиссёр')) {
          for (final a in valueCell.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty) directors.add(t);
          }
          if (directors.isEmpty) {
            final t = valueCell.text.trim();
            if (t.isNotEmpty) directors.add(t);
          }
        } else if (label.contains('жанр')) {
          for (final a in valueCell.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty) genres.add(t);
          }
        } else if (label.contains('качеств')) {
          quality = valueCell.text.trim();
        } else if (label.contains('перевод')) {
          translation = valueCell.text.trim();
        } else if (label.contains('возраст')) {
          ageRating = valueCell.text.trim();
        } else if (label.contains('время') || label.contains('длительность')) {
          duration = valueCell.text.trim();
        } else if (label.contains('из серии') || label.contains('серии')) {
          for (final a in valueCell.querySelectorAll('a')) {
            final t = a.text.trim();
            if (t.isNotEmpty) collections.add(t);
          }
        }
      }
    }

    // Ratings block (IMDb, КиноПоиск etc.)
    for (final ratingEl in s.querySelectorAll('.b-post__info_rates .b-post__info_rates_item')) {
      final sourceEl = ratingEl.querySelector('.source');
      final numEl = ratingEl.querySelector('.num');
      final votesEl = ratingEl.querySelector('.votes');
      if (sourceEl == null || numEl == null) continue;
      final src = sourceEl.text.trim();
      final val = double.tryParse(numEl.text.trim()) ?? 0;
      final votesStr = votesEl?.text.trim().replaceAll(RegExp(r'[^\d]'), '') ?? '0';
      final votes = int.tryParse(votesStr) ?? 0;
      ratings.add(RatingInfo(source: src, value: val, votes: votes));
    }

    _metaCache = ContentMeta(
      slogan: slogan?.isEmpty == true ? null : slogan,
      releaseDate: releaseDate,
      countries: countries,
      directors: directors,
      genres: genres,
      quality: quality,
      translation: translation,
      ageRating: ageRating,
      duration: duration,
      collections: collections,
      ratings: ratings,
      status: status,
      origTitle: origTitle?.isEmpty == true ? null : origTitle,
    );
    return _metaCache!;
  }

  Future<bool> voteRating(bool isLike) async {
    final contentId = await id;
    final response = await _post('$origin/ajax/add_vote/', {
      'news_id': contentId.toString(),
      'vote': isLike ? '1' : '0',
    });
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<List<CommentInfo>> get comments async {
    if (_commentsCache != null) return _commentsCache!;
    final contentId = await id;
    final response = await _post('$origin/ajax/get_comments/', {
      'news_id': contentId.toString(),
      'cstart': '1',
      'type': '0',
      'comment_id': '0',
      'skin': 'hdrezka',
    });
    final decoded = json.decode(utf8.decode(response.bodyBytes));
    final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    final result = <CommentInfo>[];
    if (data['success'] == true) {
      final html = data['comments']?.toString() ?? '';
      if (html.isNotEmpty) {
        final doc = html_parser.parse(html);
        for (final el in doc.querySelectorAll('.b-comment__item')) {
          final idStr = el.attributes['data-id'] ?? el.attributes['id']?.replaceAll(RegExp(r'\D'), '');
          final commentId = int.tryParse(idStr ?? '') ?? 0;
          final author = el.querySelector('.b-comment__author_name')?.text.trim() ?? '';
          final photo = el.querySelector('.b-comment__author_userpic img')?.attributes['src'];
          final textEl = el.querySelector('.b-comment__text');
          final text = textEl?.text.trim() ?? '';
          final date = el.querySelector('.b-comment__date')?.text.trim() ?? '';
          final likesStr = el.querySelector('.b-comment__like_counter')?.text.trim() ?? '0';
          final dislikesStr = el.querySelector('.b-comment__dislike_counter')?.text.trim() ?? '0';
          if (author.isEmpty && text.isEmpty) continue;
          result.add(CommentInfo(
            id: commentId,
            author: author,
            authorPhoto: photo,
            text: text,
            date: date,
            likes: int.tryParse(likesStr) ?? 0,
            dislikes: int.tryParse(dislikesStr) ?? 0,
          ));
        }
      }
    }
    _commentsCache = result;
    return result;
  }

  Future<List<SimilarContent>> get similar async {
    if (_similarCache != null) return _similarCache!;
    final s = await soup;
    final result = <SimilarContent>[];
    for (final el in s.querySelectorAll('.b-sidelist__item, .b-post__recommended .b-content__inline_item')) {
      final a = el.querySelector('a') ?? el.querySelector('.b-content__inline_item-link a');
      final img = el.querySelector('img');
      final title = el.querySelector('.b-content__inline_item-link a')?.text.trim()
          ?? el.querySelector('.title')?.text.trim()
          ?? a?.text.trim()
          ?? '';
      final href = a?.attributes['href'] ?? '';
      final poster = img?.attributes['src'];
      final year = el.querySelector('.b-content__inline_item-meta')?.text.trim();
      if (title.isEmpty || href.isEmpty) continue;
      result.add(SimilarContent(title: title, url: href, poster: poster, year: year));
    }
    _similarCache = result;
    return result;
  }

  Future<List<RelatedRelease>> get relatedReleases async {
    if (_relatedReleasesCache != null) return _relatedReleasesCache!;
    final s = await soup;
    final result = <RelatedRelease>[];
    for (final el in s.querySelectorAll('.b-post__partcontent .b-post__partcontent_item')) {
      final link = el.querySelector('a') ?? el.querySelector('.title');
      final img = el.querySelector('img');
      final title = el.querySelector('.title')?.text.trim() ?? '';
      final href = el.attributes['data-url'] ?? link?.attributes['href'] ?? '';
      final image = img?.attributes['src'] ?? '';
      if (title.isEmpty) continue;
      result.add(RelatedRelease(title: title, url: href, image: image));
    }
    _relatedReleasesCache = result;
    return result;
  }

  // ---------------------------------------------------------------------------
  // Trash removal (port of Python clearTrash)
  // ---------------------------------------------------------------------------

  static String clearTrash(String data) {
    const trashList = ['@', '#', '!', '^', '\$'];

    final trashCodes = <String>{};

    // generate all 2-char and 3-char combinations
    for (int len = 2; len <= 3; len++) {
      _combinations(trashList, len, (combo) {
        final bytes = utf8.encode(combo.join(''));
        final b64 = base64.encode(bytes);
        trashCodes.add(b64);
      });
    }

    String result = data.replaceAll('#h', '').split('//_//').join('');

    for (final code in trashCodes) {
      result = result.replaceAll(code, '');
    }

    try {
      // Pad to multiple of 4 (same as Python's base64.b64decode(s + "=="))
      final remainder = result.length % 4;
      final padded = remainder == 0
          ? result
          : result + '=' * (4 - remainder);
      final decoded = utf8.decode(base64.decode(padded));
      return decoded;
    } catch (_) {
      return result;
    }
  }

  static void _combinations(
      List<String> elements, int length, void Function(List<String>) callback) {
    final result = List<String>.filled(length, '');
    void helper(int depth) {
      if (depth == length) {
        callback(List.from(result));
        return;
      }
      for (final e in elements) {
        result[depth] = e;
        helper(depth + 1);
      }
    }
    helper(0);
  }

  // ---------------------------------------------------------------------------
  // Series info
  // ---------------------------------------------------------------------------

  static Map<int, String> _parseSeasons(String html) {
    final doc = html_parser.parse(html);
    final seasons = <int, String>{};
    for (final el in doc.querySelectorAll('.b-simple_season__item')) {
      final id = int.tryParse(el.attributes['data-tab_id'] ?? '');
      if (id != null) seasons[id] = el.text.trim();
    }
    return seasons;
  }

  static Map<int, Map<int, String>> _parseEpisodes(String html) {
    final doc = html_parser.parse(html);
    final episodes = <int, Map<int, String>>{};
    for (final el in doc.querySelectorAll('.b-simple_episode__item')) {
      final seasonId = int.tryParse(el.attributes['data-season_id'] ?? '');
      final epId = int.tryParse(el.attributes['data-episode_id'] ?? '');
      if (seasonId == null || epId == null) continue;
      episodes.putIfAbsent(seasonId, () => {})[epId] = el.text.trim();
    }
    return episodes;
  }

  Future<Map<int, SeriesTranslatorData>> get seriesInfo async {
    if (_seriesInfoCache != null) return _seriesInfoCache!;

    final contentType = await type;
    if (contentType != const TVSeries()) {
      throw StateError('seriesInfo is only available for TVSeries');
    }

    final contentId = await id;
    final t = await translators;
    final result = <int, SeriesTranslatorData>{};

    for (final entry in t.entries) {
      final response = await _post('$origin/ajax/get_cdn_series/', {
        'id': contentId.toString(),
        'translator_id': entry.key.toString(),
        'action': 'get_episodes',
      });

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      final data = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (data['success'] == true) {
        final seasons = _parseSeasons(data['seasons']?.toString() ?? '');
        final episodes = _parseEpisodes(data['episodes']?.toString() ?? '');
        result[entry.key] = SeriesTranslatorData(
          translatorName: entry.value.name,
          premium: entry.value.premium,
          seasons: seasons,
          episodes: episodes,
        );
      }
    }

    _seriesInfoCache = result;
    return result;
  }

  Future<List<SeasonInfo>> get episodesInfo async {
    if (_episodesInfoCache != null) return _episodesInfoCache!;

    final contentType = await type;
    if (contentType != const TVSeries()) {
      throw StateError('episodesInfo is only available for TVSeries');
    }

    final si = await seriesInfo;
    final output = <SeasonInfo>[];

    for (final trEntry in si.entries) {
      final trId = trEntry.key;
      final trData = trEntry.value;

      for (final seasonEntry in trData.seasons.entries) {
        final seasonId = seasonEntry.key;
        final seasonText = seasonEntry.value;

        SeasonInfo? seasonObj;
        final idx = output.indexWhere((s) => s.season == seasonId);
        if (idx == -1) {
          seasonObj = SeasonInfo(season: seasonId, seasonText: seasonText, episodes: []);
          output.add(seasonObj);
        } else {
          seasonObj = output[idx];
        }

        final episodesMap = trData.episodes[seasonId] ?? {};
        for (final epEntry in episodesMap.entries) {
          final epId = epEntry.key;
          final epText = epEntry.value;

          final epIdx = seasonObj.episodes.indexWhere((e) => e.episode == epId);
          if (epIdx == -1) {
            seasonObj.episodes.add(EpisodeInfo(
              episode: epId,
              episodeText: epText,
              translations: [
                TranslatorInfo(id: trId, name: trData.translatorName, premium: trData.premium)
              ],
            ));
          } else {
            seasonObj.episodes[epIdx].translations.add(
              TranslatorInfo(id: trId, name: trData.translatorName, premium: trData.premium),
            );
          }
        }
      }
    }

    _episodesInfoCache = output;
    return output;
  }

  // ---------------------------------------------------------------------------
  // Stream fetching
  // ---------------------------------------------------------------------------

  Future<HdRezkaStream> _makeStreamRequest(Map<String, String> data) async {
    final season = data['season'] != null ? int.tryParse(data['season']!) : null;
    final episode = data['episode'] != null ? int.tryParse(data['episode']!) : null;
    final contentName = await name;

    final response = await _post('$origin/ajax/get_cdn_series/', data);
    final decoded_ = json.decode(utf8.decode(response.bodyBytes));
    final json_ = decoded_ is Map<String, dynamic> ? decoded_ : <String, dynamic>{};

    if (json_['success'] == true && json_['url'] != null) {
      final rawUrl = json_['url'].toString();
      final cleanedUrl = clearTrash(rawUrl);
      // subtitle and subtitle_lns can be false (bool) when no subtitles
      final subtitleRaw = json_['subtitle'];
      final subtitleData = (subtitleRaw is String && subtitleRaw.isNotEmpty)
          ? subtitleRaw : null;
      final subtitleLns = json_['subtitle_lns'];
      final subtitleCodes = (subtitleLns is Map)
          ? subtitleLns.map((k, v) => MapEntry(k.toString(), v.toString()))
          : <String, String>{};

      final stream = HdRezkaStream(
        season: season,
        episode: episode,
        name: contentName,
        translatorId: int.parse(data['translator_id']!),
        subtitles: HdRezkaStreamSubtitles.parse(subtitleData, subtitleCodes),
      );

      for (final chunk in cleanedUrl.split(',')) {
        final bracketStart = chunk.indexOf('[');
        final bracketEnd = chunk.indexOf(']');
        if (bracketStart == -1 || bracketEnd == -1) continue;
        final qualityRaw = chunk.substring(bracketStart + 1, bracketEnd);
        // strip any html tags from quality string
        final quality = qualityRaw.replaceAll(RegExp(r'<[^>]*>'), '');
        final linksRaw = chunk.substring(bracketEnd + 1);
        for (final link in linksRaw.split(' or ')) {
          if (link.endsWith('.mp4')) {
            stream.append(quality, link.trim());
          }
        }
      }
      return stream;
    }
    throw FetchFailed();
  }

  int _resolveTranslatorId(
    List<TranslatorInfo> translators, {
    dynamic translation,
    List<int>? priority,
    List<int>? nonPriority,
  }) {
    if (translation != null) {
      final s = translation.toString();
      if (int.tryParse(s) != null) {
        final id = int.parse(s);
        if (translators.any((t) => t.id == id)) return id;
        throw ArgumentError('Translation with code "$translation" is not defined');
      }
      final found = translators.firstWhere(
        (t) => t.name == s,
        orElse: () => throw ArgumentError('Translation "$translation" is not defined'),
      );
      return found.id;
    }
    // use priority sort
    final map = {for (final t in translators) t.id: t};
    final sorted = sortTranslators(map, priority: priority, nonPriority: nonPriority);
    return sorted.keys.first;
  }

  Future<HdRezkaStream> getStream({
    int? season,
    int? episode,
    dynamic translation,
    List<int>? priority,
    List<int>? nonPriority,
  }) async {
    final contentType = await type;
    final contentId = await id;

    if (contentType == const TVSeries()) {
      if (season == null || episode == null) {
        throw ArgumentError('For TVSeries, both season and episode are required');
      }
      final eps = await episodesInfo;
      final seasonObj = eps.firstWhere(
        (s) => s.season == season,
        orElse: () => throw ArgumentError('Season "$season" not found'),
      );
      final epObj = seasonObj.episodes.firstWhere(
        (e) => e.episode == episode,
        orElse: () => throw ArgumentError('Episode "$episode" in season "$season" not found'),
      );
      final trId = _resolveTranslatorId(
        epObj.translations,
        translation: translation,
        priority: priority,
        nonPriority: nonPriority,
      );
      return _makeStreamRequest({
        'id': contentId.toString(),
        'translator_id': trId.toString(),
        'season': season.toString(),
        'episode': episode.toString(),
        'action': 'get_stream',
      });
    } else if (contentType == const Movie()) {
      final t = await translators;
      final trList = t.values.toList();
      final trId = _resolveTranslatorId(
        trList,
        translation: translation,
        priority: priority,
        nonPriority: nonPriority,
      );
      return _makeStreamRequest({
        'id': contentId.toString(),
        'translator_id': trId.toString(),
        'action': 'get_movie',
      });
    }
    throw StateError('Undefined content type');
  }

  /// Yields (episodeNumber, stream?) for each episode in the season.
  /// [ignore] = true — continue on error (stream will be null for failed episodes).
  Stream<(int, HdRezkaStream?)> getSeasonStreams(
    int season, {
    dynamic translation,
    List<int>? priority,
    List<int>? nonPriority,
    bool ignore = false,
    void Function(int current, int total)? onProgress,
  }) async* {
    final eps = await episodesInfo;
    final seasonObj = eps.firstWhere(
      (s) => s.season == season,
      orElse: () => throw ArgumentError('Season "$season" not found'),
    );

    // Build translator→episodes map
    final trEpisodes = <int, List<int>>{};
    for (final ep in seasonObj.episodes) {
      for (final tr in ep.translations) {
        trEpisodes.putIfAbsent(tr.id, () => []).add(ep.episode);
      }
    }

    final trMap = {
      for (final ep in seasonObj.episodes)
        for (final tr in ep.translations)
          tr.id: TranslatorInfo(id: tr.id, name: tr.name, premium: tr.premium)
    };

    final trId = _resolveTranslatorId(
      trMap.values.toList(),
      translation: translation,
      priority: priority,
      nonPriority: nonPriority,
    );

    final episodes = trEpisodes[trId] ?? [];
    final total = episodes.length;
    int done = 0;

    onProgress?.call(0, total);

    for (final ep in episodes) {
      HdRezkaStream? stream;
      try {
        stream = await getStream(
          season: season,
          episode: ep,
          translation: trId,
        );
      } catch (e) {
        if (!ignore) {
          // one retry after brief delay
          await Future.delayed(const Duration(seconds: 1));
          try {
            stream = await getStream(
              season: season,
              episode: ep,
              translation: trId,
            );
          } catch (_) {
            stream = null;
          }
        }
      }
      done++;
      onProgress?.call(done, total);
      yield (ep, stream);
    }
  }
}
