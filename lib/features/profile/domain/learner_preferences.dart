// What a learner tells us during onboarding. Each value's `code` is what gets
// stored and sent to the API, so codes never change once shipped; labels can.

/// JLPT levels, easiest first.
enum JlptLevel {
  n5(
    'N5',
    'Beginner',
    'Can understand basic Japanese words, phrases, and simple sentences.',
  ),
  n4(
    'N4',
    'Elementary',
    'Can understand basic everyday Japanese and simple conversations.',
  ),
  n3(
    'N3',
    'Intermediate',
    'Can understand everyday Japanese and follow moderately difficult '
        'conversations.',
  ),
  n2(
    'N2',
    'Upper Intermediate',
    'Can understand more complex conversations, articles, and everyday media.',
  ),
  n1(
    'N1',
    'Advanced',
    'Can understand complex Japanese used in a wide range of situations.',
  );

  const JlptLevel(this.code, this.title, this.description);

  final String code;
  final String title;
  final String description;

  /// Where someone who does not know their level starts.
  static const fallback = JlptLevel.n5;

  /// 1 for N5 up to 5 for N1: how many bars a level indicator fills.
  int get step => index + 1;

  static JlptLevel? fromCode(Object? code) =>
      values.where((level) => level.code == code).firstOrNull;
}

/// Why someone is learning Japanese.
enum LearningReason {
  travel('travel', 'Travel'),
  animeManga('anime_manga', 'Anime & Manga'),
  career('career', 'Work / Career'),
  school('school', 'School / Education'),
  livingInJapan('living_in_japan', 'Living in Japan'),
  friends('friends', 'Making Japanese friends'),
  hobby('hobby', 'Hobby / Personal interest'),
  media('media', 'Understanding Japanese media'),
  other('other', 'Other');

  const LearningReason(this.code, this.label);

  final String code;
  final String label;

  static LearningReason? fromCode(Object? code) =>
      values.where((reason) => reason.code == code).firstOrNull;
}

/// Kinds of Japanese content. The codes match the API's content categories, so
/// interests steer which videos are recommended.
enum ContentInterest {
  anime('anime', 'Anime'),
  youtube('youtube', 'YouTube'),
  podcasts('podcasts', 'Podcasts'),
  music('music', 'Music'),
  news('news', 'News'),
  conversations('conversations', 'Conversations'),
  travel('travel', 'Travel'),
  reading('reading', 'Reading'),
  gaming('gaming', 'Gaming'),
  culture('culture', 'Japanese culture');

  const ContentInterest(this.code, this.label);

  final String code;
  final String label;

  static ContentInterest? fromCode(Object? code) =>
      values.where((interest) => interest.code == code).firstOrNull;
}
