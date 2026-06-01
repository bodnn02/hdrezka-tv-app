// Integration tests — require real network access to HDRezka.
// Run with: flutter test --tags integration
//
// By default these are SKIPPED to avoid network dependency in CI.
// To run: dart test test/core/api/hdrezka_integration_test.dart
//         (remove the skip: tags or set env RUN_INTEGRATION=1)

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hdrezka_tv/core/api/hdrezka_api_lib.dart';

const _origin = 'https://hdrezka.ag';

bool get _runIntegration => Platform.environment['RUN_INTEGRATION'] == '1';

void main() {
  group('HdRezkaSearch integration', () {
    late HdRezkaSearch search;

    setUp(() {
      search = HdRezkaSearch(origin: _origin);
    });

    test('fast search returns results for "Матрица"', () async {
      if (!_runIntegration) return;

      final results = await search.fastSearch('Матрица');
      expect(results, isNotEmpty);
      expect(results.first.title, isNotEmpty);
      expect(results.first.url, startsWith('http'));
    }, skip: !_runIntegration);

    test('advanced search page 1 returns results', () async {
      if (!_runIntegration) return;

      final page = await search.advancedSearch('Матрица');
      expect(page.items, isNotEmpty);
      for (final item in page.items) {
        expect(item.title, isNotEmpty);
        expect(item.url, startsWith('http'));
        expect(item.image, isNotEmpty);
      }
    }, skip: !_runIntegration);
  });

  group('HdRezkaApi movie integration', () {
    test('loads movie metadata', () async {
      if (!_runIntegration) return;

      // Using a well-known movie URL (update if needed)
      final search = HdRezkaSearch(origin: _origin);
      final results = await search.fastSearch('Матрица 1999');
      expect(results, isNotEmpty);

      final api = HdRezkaApi(results.first.url);

      final n = await api.name;
      expect(n, isNotEmpty);

      final t = await api.type;
      expect(t, isA<HdRezkaFormat>());

      final r = await api.rating;
      expect(r, isA<HdRezkaRating>());

      final thumb = await api.thumbnail;
      expect(thumb, startsWith('http'));

      print('Title: $n');
      print('Type: $t');
      print('Rating: $r');
      print('Thumbnail: $thumb');
    }, skip: !_runIntegration);

    test('gets stream for movie', () async {
      if (!_runIntegration) return;

      final search = HdRezkaSearch(origin: _origin);
      final results = await search.fastSearch('Матрица 1999');
      final api = HdRezkaApi(results.first.url);

      final t = await api.type;
      if (t != const Movie()) {
        print('Skipping: first result is not a movie');
        return;
      }

      final stream = await api.getStream();
      expect(stream.videos, isNotEmpty);
      final resolutions = stream.sortedResolutions;
      expect(resolutions, isNotEmpty);

      final bestLink = stream.bestUrl(resolutions.first);
      expect(bestLink, isNotNull);
      expect(bestLink!, endsWith('.mp4'));
      print('Stream resolutions: $resolutions');
      print('Best link: $bestLink');
    }, skip: !_runIntegration);
  });

  group('HdRezkaSession integration', () {
    test('search via session', () async {
      if (!_runIntegration) return;

      final session = HdRezkaSession(origin: _origin);
      final results = await session.search('Breaking Bad');
      expect(results, isNotEmpty);
      print('Session search result: ${results.first.title}');
    }, skip: !_runIntegration);
  });
}
