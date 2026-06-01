const Map<String, String> defaultHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/81.0.4044.138 Safari/537.36',
};

const Map<String, String> defaultCookies = {
  'hdmbbs': '1',
};

// Default translator priority IDs
// 56  = Дубляж
// 105 = StudioBand
// 111 = HDrezka Studio
const List<int> defaultTranslatorsPriority = [56, 105, 111];

// 238 = Оригинал + субтитры
const List<int> defaultTranslatorsNonPriority = [238];

// ---------------------------------------------------------------------------
// Base type system
// ---------------------------------------------------------------------------

abstract class HdRezkaType {
  final String name;
  final String type;

  const HdRezkaType(this.name, this.type);

  @override
  String toString() => '$type.$name';

  @override
  bool operator ==(Object other) {
    if (other is HdRezkaType) return runtimeType == other.runtimeType || name == other.name;
    if (other is Type) return runtimeType == other;
    if (other is String) return name == other;
    return false;
  }

  @override
  int get hashCode => name.hashCode;
}

abstract class HdRezkaFormat extends HdRezkaType {
  const HdRezkaFormat(String name) : super(name, 'format');
}

abstract class HdRezkaCategory extends HdRezkaType {
  const HdRezkaCategory(String name) : super(name, 'category');
}

// ---------------------------------------------------------------------------
// Concrete format types
// ---------------------------------------------------------------------------

class TVSeries extends HdRezkaFormat {
  const TVSeries() : super('tv_series');
}

class Movie extends HdRezkaFormat {
  const Movie() : super('movie');
}

class UnknownFormat extends HdRezkaFormat {
  const UnknownFormat(String name) : super(name);
}

// ---------------------------------------------------------------------------
// Concrete category types
// ---------------------------------------------------------------------------

class Film extends HdRezkaCategory {
  const Film() : super('film');
}

class Series extends HdRezkaCategory {
  const Series() : super('series');
}

class Cartoon extends HdRezkaCategory {
  const Cartoon() : super('cartoon');
}

class Anime extends HdRezkaCategory {
  const Anime() : super('anime');
}

class UnknownCategory extends HdRezkaCategory {
  const UnknownCategory(String name) : super(name);
}

// ---------------------------------------------------------------------------
// Rating
// ---------------------------------------------------------------------------

class HdRezkaRating implements Comparable<HdRezkaRating> {
  final double value;
  final int votes;

  const HdRezkaRating({required this.value, required this.votes});

  bool get isEmpty => false;

  @override
  String toString() => '$value ($votes)';

  @override
  int compareTo(HdRezkaRating other) => value.compareTo(other.value);

  bool operator >(HdRezkaRating other) => value > other.value;
  bool operator <(HdRezkaRating other) => value < other.value;
  bool operator >=(HdRezkaRating other) => value >= other.value;
  bool operator <=(HdRezkaRating other) => value <= other.value;

  @override
  bool operator ==(Object other) {
    if (other is HdRezkaRating) return value == other.value;
    if (other is double) return value == other;
    if (other is int) return value == other.toDouble();
    return false;
  }

  @override
  int get hashCode => value.hashCode;
}

class HdRezkaEmptyRating extends HdRezkaRating {
  const HdRezkaEmptyRating() : super(value: 0, votes: 0);

  @override
  bool get isEmpty => true;

  @override
  String toString() => 'HdRezkaRating(Empty)';
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class TranslatorInfo {
  final int id;
  final String name;
  final bool premium;

  const TranslatorInfo({required this.id, required this.name, required this.premium});
}

class EpisodeInfo {
  final int episode;
  final String episodeText;
  final List<TranslatorInfo> translations;

  const EpisodeInfo({
    required this.episode,
    required this.episodeText,
    required this.translations,
  });
}

class SeasonInfo {
  final int season;
  final String seasonText;
  final List<EpisodeInfo> episodes;

  const SeasonInfo({
    required this.season,
    required this.seasonText,
    required this.episodes,
  });
}

class ActorInfo {
  final String name;
  final String? url;
  final String? photo;

  const ActorInfo({required this.name, this.url, this.photo});
}

class RelatedRelease {
  final String title;
  final String url;
  final String image;

  const RelatedRelease({required this.title, required this.url, required this.image});
}

class RatingInfo {
  final String source;
  final double value;
  final int votes;

  const RatingInfo({required this.source, required this.value, required this.votes});

  @override
  String toString() => '$source: $value (${_formatVotes(votes)})';

  static String _formatVotes(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
    return '$v';
  }
}

class ContentMeta {
  final String? slogan;
  final String? releaseDate;
  final List<String> countries;
  final List<String> directors;
  final List<String> genres;
  final String? quality;
  final String? translation;
  final String? ageRating;
  final String? duration;
  final List<String> collections;
  final List<RatingInfo> ratings;
  final String? status;
  final String? origTitle;

  const ContentMeta({
    this.slogan,
    this.releaseDate,
    this.countries = const [],
    this.directors = const [],
    this.genres = const [],
    this.quality,
    this.translation,
    this.ageRating,
    this.duration,
    this.collections = const [],
    this.ratings = const [],
    this.status,
    this.origTitle,
  });
}

class CommentInfo {
  final int id;
  final String author;
  final String? authorPhoto;
  final String text;
  final String date;
  final int likes;
  final int dislikes;

  const CommentInfo({
    required this.id,
    required this.author,
    this.authorPhoto,
    required this.text,
    required this.date,
    this.likes = 0,
    this.dislikes = 0,
  });
}

class SimilarContent {
  final String title;
  final String url;
  final String? poster;
  final String? year;
  final String? rating;

  const SimilarContent({
    required this.title,
    required this.url,
    this.poster,
    this.year,
    this.rating,
  });
}

class SeriesTranslatorData {
  final String translatorName;
  final bool premium;
  final Map<int, String> seasons;
  final Map<int, Map<int, String>> episodes;

  const SeriesTranslatorData({
    required this.translatorName,
    required this.premium,
    required this.seasons,
    required this.episodes,
  });
}
