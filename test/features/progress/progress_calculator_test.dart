import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';
import 'package:ingrain/features/progress/domain/progress_calculator.dart';
import 'package:ingrain/features/progress/domain/progress_summary.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';

void main() {
  const calculator = ProgressCalculator();
  final today = DateTime(2026, 3, 15, 14, 30);

  ImmersionSession session({
    required DateTime startedAt,
    int durationSeconds = 600,
    String? id,
  }) {
    return ImmersionSession(
      id: id ?? 'session-${startedAt.millisecondsSinceEpoch}',
      uid: 'uid-1',
      sourceId: 'content-1',
      startedAt: startedAt,
      durationSeconds: durationSeconds,
    );
  }

  SentenceItem sentence({required DateTime createdAt, String? id}) {
    return SentenceItem(
      id: id ?? 'sentence-${createdAt.millisecondsSinceEpoch}',
      uid: 'uid-1',
      japanese: '日本語',
      sourceType: SourceType.manual,
      sourceId: 'manual',
      createdAt: createdAt,
    );
  }

  ReviewCard card({required DateTime dueAt, String? id}) {
    return ReviewCard(
      id: id ?? 'card-${dueAt.millisecondsSinceEpoch}',
      uid: 'uid-1',
      cardType: CardType.sentence,
      sourceItemId: 'sentence-1',
      promptText: '日本語',
      createdAt: dueAt,
      dueAt: dueAt,
    );
  }

  ReviewEvent event({
    required DateTime reviewedAt,
    Rating rating = Rating.good,
    String? id,
  }) {
    return ReviewEvent(
      id: id ?? 'review-${reviewedAt.millisecondsSinceEpoch}-$rating',
      uid: 'uid-1',
      cardId: 'card-1',
      cardType: CardType.sentence,
      rating: rating,
      reviewedAt: reviewedAt,
      intervalDaysAfter: 1,
    );
  }

  VocabularyItem word({
    required String text,
    VocabState state = VocabState.encountered,
  }) {
    return VocabularyItem(
      id: 'word-$text',
      uid: 'uid-1',
      word: text,
      sourceType: SourceType.manual,
      sourceId: 'manual',
      state: state,
      createdAt: DateTime(2026, 3, 15, 9),
      updatedAt: DateTime(2026, 3, 15, 9),
    );
  }

  ProgressSummary summarize({
    List<ImmersionSession>? sessions,
    List<SentenceItem>? sentences,
    List<VocabularyItem>? vocabulary,
    List<ReviewCard>? dueCards,
    List<ReviewEvent>? reviewEvents,
    DateTime? reference,
    int dailyGoalMinutes = 30,
  }) {
    return calculator.summarize(
      sessions: sessions ?? const <ImmersionSession>[],
      sentences: sentences ?? const <SentenceItem>[],
      vocabulary: vocabulary ?? const <VocabularyItem>[],
      dueCards: dueCards ?? const <ReviewCard>[],
      reviewEvents: reviewEvents ?? const <ReviewEvent>[],
      today: reference ?? today,
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  group('ProgressCalculator empty input', () {
    test('produces a zeroed summary', () {
      final summary = summarize();

      expect(summary.todaySeconds, 0);
      expect(summary.weekSeconds, 0);
      expect(summary.lifetimeSeconds, 0);
      expect(summary.currentStreak, 0);
      expect(summary.longestStreak, 0);
      expect(summary.totalSentences, 0);
      expect(summary.sentencesThisWeek, 0);
      expect(summary.dueCount, 0);
      expect(summary.reviewedToday, 0);
      expect(summary.totalReviews, 0);
      expect(summary.totalWords, 0);
      expect(summary.wordsLearningOrBetter, 0);
      expect(summary.isEmpty, isTrue);
    });

    test('still returns seven daily entries ending today', () {
      final summary = summarize();

      expect(summary.last7Days.length, 7);
      expect(summary.last7Days.last.day, DateTime(2026, 3, 15));
      expect(summary.last7Days.first.day, DateTime(2026, 3, 9));
    });
  });

  group('ProgressCalculator immersion time', () {
    test('sums session durations into the starting local day', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 15, 9), durationSeconds: 300),
          session(startedAt: DateTime(2026, 3, 15, 20), durationSeconds: 120),
        ],
      );

      expect(summary.todaySeconds, 420);
      expect(summary.weekSeconds, 420);
      expect(summary.lifetimeSeconds, 420);
    });

    test('attributes a session crossing midnight to its start day', () {
      final summary = summarize(
        sessions: [
          session(
            startedAt: DateTime(2026, 3, 14, 23, 50),
            durationSeconds: 1800,
          ),
        ],
      );

      expect(summary.todaySeconds, 0);
      expect(summary.weekSeconds, 1800);
      expect(summary.last7Days[5].seconds, 1800);
      expect(summary.last7Days[6].seconds, 0);
    });

    test('excludes sessions older than the last seven days', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 8, 10), durationSeconds: 900),
          session(startedAt: DateTime(2026, 3, 9, 10), durationSeconds: 60),
        ],
      );

      expect(summary.lifetimeSeconds, 960);
      expect(summary.weekSeconds, 60);
    });

    test('ignores zero duration sessions', () {
      final summary = summarize(
        sessions: [session(startedAt: today, durationSeconds: 0)],
      );

      expect(summary.todaySeconds, 0);
      expect(summary.lifetimeSeconds, 0);
      expect(summary.currentStreak, 0);
    });

    test('exposes goal progress against the daily goal', () {
      final summary = summarize(
        sessions: [session(startedAt: today, durationSeconds: 900)],
        dailyGoalMinutes: 30,
      );

      expect(summary.dailyGoalSeconds, 1800);
      expect(summary.todayGoalProgress, closeTo(0.5, 0.0001));
    });

    test('clamps goal progress above one', () {
      final summary = summarize(
        sessions: [session(startedAt: today, durationSeconds: 9999)],
        dailyGoalMinutes: 1,
      );

      expect(summary.todayGoalProgress, 1.0);
    });
  });

  group('ProgressCalculator streaks', () {
    test('counts consecutive days back from today', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 15, 10)),
          session(startedAt: DateTime(2026, 3, 14, 10)),
          session(startedAt: DateTime(2026, 3, 13, 10)),
        ],
      );

      expect(summary.currentStreak, 3);
    });

    test('stays alive when today has no activity but yesterday did', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 14, 10)),
          session(startedAt: DateTime(2026, 3, 13, 10)),
        ],
      );

      expect(summary.currentStreak, 2);
    });

    test('breaks when today and yesterday are both empty', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 13, 10)),
          session(startedAt: DateTime(2026, 3, 12, 10)),
        ],
      );

      expect(summary.currentStreak, 0);
    });

    test('breaks on a gap inside the run', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 15, 10)),
          session(startedAt: DateTime(2026, 3, 14, 10)),
          session(startedAt: DateTime(2026, 3, 12, 10)),
        ],
      );

      expect(summary.currentStreak, 2);
    });

    test('longest streak finds the longest historical run', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 15, 10)),
          session(startedAt: DateTime(2026, 3, 8, 10)),
          session(startedAt: DateTime(2026, 3, 7, 10)),
          session(startedAt: DateTime(2026, 3, 6, 10)),
          session(startedAt: DateTime(2026, 3, 5, 10)),
        ],
      );

      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 4);
    });

    test('two sessions on one day count once toward the streak', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 15, 8)),
          session(startedAt: DateTime(2026, 3, 15, 19)),
        ],
      );

      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 1);
    });

    test('spans a month boundary', () {
      final summary = summarize(
        sessions: [
          session(startedAt: DateTime(2026, 3, 2, 10)),
          session(startedAt: DateTime(2026, 3, 1, 10)),
          session(startedAt: DateTime(2026, 2, 28, 10)),
        ],
        reference: DateTime(2026, 3, 2, 8),
      );

      expect(summary.currentStreak, 3);
    });
  });

  group('ProgressCalculator sentences', () {
    test('counts total and this-week sentences', () {
      final summary = summarize(
        sentences: [
          sentence(createdAt: DateTime(2026, 3, 15, 11)),
          sentence(createdAt: DateTime(2026, 3, 10, 11)),
          sentence(createdAt: DateTime(2026, 3, 1, 11)),
        ],
      );

      expect(summary.totalSentences, 3);
      expect(summary.sentencesThisWeek, 2);
    });

    test('does not double count a duplicate sentence', () {
      final shared = sentence(createdAt: DateTime(2026, 3, 15, 11));
      final summary = summarize(sentences: [shared, shared]);

      expect(summary.totalSentences, 2);
    });
  });

  group('ProgressCalculator vocabulary', () {
    test('counts every saved word and only the learned ones', () {
      final summary = summarize(
        vocabulary: [
          word(text: '猫', state: VocabState.mastered),
          word(text: '犬', state: VocabState.learning),
          word(text: '鳥', state: VocabState.known),
          word(text: '魚', state: VocabState.encountered),
          word(text: '肉', state: VocabState.unknown),
        ],
      );

      expect(summary.totalWords, 5);
      expect(summary.wordsLearningOrBetter, 3);
    });

    test('saved words alone keep the dashboard out of the empty state', () {
      final summary = summarize(vocabulary: [word(text: '猫')]);

      expect(summary.totalWords, 1);
      expect(summary.isEmpty, isFalse);
    });
  });

  group('ProgressCalculator reviews', () {
    test('counts reviews due today and total reviews', () {
      final summary = summarize(
        reviewEvents: [
          event(reviewedAt: DateTime(2026, 3, 15, 8)),
          event(reviewedAt: DateTime(2026, 3, 15, 9), rating: Rating.easy),
          event(reviewedAt: DateTime(2026, 3, 14, 9)),
        ],
      );

      expect(summary.reviewedToday, 2);
      expect(summary.totalReviews, 3);
    });

    test('counts only cards due by the end of today', () {
      final summary = summarize(
        dueCards: [
          card(dueAt: DateTime(2026, 3, 15, 23, 59)),
          card(dueAt: DateTime(2026, 3, 14, 8)),
          card(dueAt: DateTime(2026, 3, 16, 0, 1)),
        ],
      );

      expect(summary.dueCount, 2);
    });

    test('attaches daily review counts to the seven day buckets', () {
      final summary = summarize(
        reviewEvents: [
          event(reviewedAt: DateTime(2026, 3, 15, 8)),
          event(reviewedAt: DateTime(2026, 3, 15, 9)),
          event(reviewedAt: DateTime(2026, 3, 11, 9)),
        ],
      );

      expect(summary.last7Days.last.reviews, 2);
      expect(summary.last7Days[2].reviews, 1);
      expect(summary.last7Days.first.reviews, 0);
    });

    test('reviews alone do not sustain the immersion streak', () {
      final summary = summarize(
        reviewEvents: [event(reviewedAt: DateTime(2026, 3, 15, 8))],
      );

      expect(summary.reviewedToday, 1);
      expect(summary.currentStreak, 0);
      expect(summary.last7Days.last.reviews, 1);
    });

    test('an empty but reviewed dashboard is not empty', () {
      final summary = summarize(
        reviewEvents: [event(reviewedAt: DateTime(2026, 3, 15, 8))],
      );

      expect(summary.isEmpty, isFalse);
    });
  });
}
