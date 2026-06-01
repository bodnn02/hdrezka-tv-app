import 'package:flutter_test/flutter_test.dart';
import 'package:hdrezka_tv/core/api/hdrezka_types.dart';

void main() {
  group('HdRezkaType equality', () {
    test('TVSeries equals itself', () {
      expect(const TVSeries() == const TVSeries(), isTrue);
    });

    test('Movie equals itself', () {
      expect(const Movie() == const Movie(), isTrue);
    });

    test('TVSeries does not equal Movie', () {
      expect(const TVSeries() == const Movie(), isFalse);
    });

    test('equality by name string', () {
      expect(const TVSeries() == 'tv_series', isTrue);
      expect(const Movie() == 'movie', isTrue);
    });

    test('Film category', () {
      expect(const Film() == const Film(), isTrue);
      expect(const Film() == 'film', isTrue);
      expect(const Film() == const Series(), isFalse);
    });
  });

  group('HdRezkaRating', () {
    const r1 = HdRezkaRating(value: 8.5, votes: 1000);
    const r2 = HdRezkaRating(value: 7.0, votes: 500);
    const empty = HdRezkaEmptyRating();

    test('toString', () {
      expect(r1.toString(), '8.5 (1000)');
    });

    test('comparisons', () {
      expect(r1 > r2, isTrue);
      expect(r2 < r1, isTrue);
      expect(r1 >= r1, isTrue);
    });

    test('equality with double', () {
      expect(r1 == 8.5, isTrue);
    });

    test('empty rating is zero', () {
      expect(empty.value, 0);
      expect(empty.isEmpty, isTrue);
    });
  });
}
