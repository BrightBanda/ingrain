import 'package:ingrain/features/profile/domain/learner_preferences.dart';

/// Why the server picked a video for today, so the card can say so.
enum PickReason {
  curated('curated', 'Editor’s pick'),
  interest('interest', 'For your interests'),
  level('level', 'At your level'),
  nearbyLevel('nearbyLevel', 'Stretch pick'),
  rewatch('rewatch', 'Watch again');

  const PickReason(this.code, this.label);

  final String code;
  final String label;

  static PickReason? fromCode(Object? code) =>
      values.where((reason) => reason.code == code).firstOrNull;
}

/// A video from the ingrain catalogue, as curated on the server.
class CatalogVideo {
  final String id;
  final String title;
  final String description;
  final JlptLevel? level;
  final List<ContentInterest> categories;
  final String videoUrl;
  final String? youtubeId;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final String? channelTitle;

  /// Set on daily picks only.
  final PickReason? reason;

  const CatalogVideo({
    required this.id,
    required this.title,
    this.description = '',
    this.level,
    this.categories = const [],
    required this.videoUrl,
    this.youtubeId,
    this.thumbnailUrl,
    this.durationSeconds,
    this.channelTitle,
    this.reason,
  });

  /// The first category, as the card's headline category.
  ContentInterest? get primaryCategory => categories.firstOrNull;
}

/// One day's recommended videos for the learner.
class DailyPicks {
  /// The UTC calendar day these picks are for.
  final DateTime date;

  /// When a fresh set becomes available.
  final DateTime validUntil;
  final JlptLevel level;
  final List<CatalogVideo> videos;

  /// True when the server could not be reached and these came from the cache.
  final bool isCached;

  const DailyPicks({
    required this.date,
    required this.validUntil,
    required this.level,
    required this.videos,
    this.isCached = false,
  });

  bool isStale(DateTime now) => !now.toUtc().isBefore(validUntil);
}
