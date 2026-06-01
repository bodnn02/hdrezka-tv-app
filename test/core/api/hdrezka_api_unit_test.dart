import 'package:flutter_test/flutter_test.dart';
import 'package:hdrezka_tv/core/api/hdrezka_api.dart';
import 'package:hdrezka_tv/core/api/hdrezka_types.dart';

void main() {
  group('HdRezkaApi.clearTrash', () {
    // 'https://example.com/video.mp4'
    // base64 without padding: aHR0cHM6Ly9leGFtcGxlLmNvbS92aWRlby5tcDQ
    const cleanB64 = 'aHR0cHM6Ly9leGFtcGxlLmNvbS92aWRlby5tcDQ';

    test('decodes clean base64 without padding', () {
      final result = HdRezkaApi.clearTrash(cleanB64);
      expect(result, 'https://example.com/video.mp4');
    });

    test('strips #h prefix before decoding', () {
      final result = HdRezkaApi.clearTrash('#h$cleanB64');
      expect(result, 'https://example.com/video.mp4');
    });

    test('joins //_// segments before decoding', () {
      // Split the b64 string at an arbitrary point
      const part1 = 'aHR0cHM6Ly9leGFt';
      const part2 = 'cGxlLmNvbS92aWRlby5tcDQ';
      final result = HdRezkaApi.clearTrash('$part1//_//$part2');
      expect(result, 'https://example.com/video.mp4');
    });
  });

  group('HdRezkaApi URL normalization', () {
    test('strips extra path after .html', () {
      final api = HdRezkaApi('https://hdrezka.ag/films/drama/123-title.html?foo=bar');
      expect(api.url, 'https://hdrezka.ag/films/drama/123-title.html');
    });

    test('extracts origin correctly', () {
      final api = HdRezkaApi('https://hdrezka.ag/films/drama/123-title.html');
      expect(api.origin, 'https://hdrezka.ag');
    });
  });

  group('HdRezkaApi.sortTranslators', () {
    final api = HdRezkaApi('https://hdrezka.ag/films/drama/1-title.html');

    final translators = {
      238: const TranslatorInfo(id: 238, name: 'Оригинал', premium: false),
      105: const TranslatorInfo(id: 105, name: 'StudioBand', premium: false),
      56: const TranslatorInfo(id: 56, name: 'Дубляж', premium: false),
      999: const TranslatorInfo(id: 999, name: 'Unknown', premium: false),
    };

    test('priority list puts 56 first', () {
      final sorted = api.sortTranslators(translators, priority: [56, 105]);
      expect(sorted.keys.first, 56);
      expect(sorted.keys.elementAt(1), 105);
    });

    test('non_priority puts 238 last among known', () {
      final sorted = api.sortTranslators(translators,
          priority: [56, 105], nonPriority: [238]);
      final keys = sorted.keys.toList();
      expect(keys.first, 56);
      // 238 should come after 56 and 105
      expect(keys.indexOf(238), greaterThan(keys.indexOf(105)));
    });

    test('unknown translators go to middle (not priority, not non-priority)', () {
      final sorted = api.sortTranslators(translators,
          priority: [56], nonPriority: [238]);
      final keys = sorted.keys.toList();
      // 999 is neither priority nor non-priority
      // it should come between 56 and 238
      expect(keys.indexOf(999), lessThan(keys.indexOf(238)));
    });
  });
}
