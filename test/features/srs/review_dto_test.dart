import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/data/review_card_dto.dart';
import 'package:ingrain/features/srs/data/review_event_dto.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';

void main() {
  final createdAt = DateTime(2026, 3, 15, 9, 30);
  final dueAt = DateTime(2026, 3, 16, 9, 30);

  group('ReviewCardDto round trip', () {
    test('preserves every field', () {
      final dto = ReviewCardDto(
        id: 'card-1',
        uid: 'uid-1',
        cardType: CardType.sentence,
        sourceItemId: 'sentence-1',
        promptText: 'これはテストです。',
        answerText: 'This is a test.',
        createdAt: createdAt,
        dueAt: dueAt,
        intervalDays: 6,
        repetitions: 2,
        easeFactor: 2.35,
        reviewCount: 3,
        lastReviewedAt: DateTime(2026, 3, 15, 12),
      );

      final restored = ReviewCardDto.fromMap(dto.map).toDomain();

      expect(restored.id, 'card-1');
      expect(restored.uid, 'uid-1');
      expect(restored.cardType, CardType.sentence);
      expect(restored.sourceItemId, 'sentence-1');
      expect(restored.promptText, 'これはテストです。');
      expect(restored.answerText, 'This is a test.');
      expect(restored.createdAt, createdAt);
      expect(restored.dueAt, dueAt);
      expect(restored.intervalDays, 6);
      expect(restored.repetitions, 2);
      expect(restored.easeFactor, closeTo(2.35, 0.0001));
      expect(restored.reviewCount, 3);
      expect(restored.lastReviewedAt, DateTime(2026, 3, 15, 12));
    });

    test('applies SM-2 defaults to a minimal document', () {
      final restored = ReviewCardDto.fromMap({
        'id': 'card-2',
        'uid': 'uid-1',
        'cardType': 'sentence',
        'sourceItemId': 'sentence-2',
        'promptText': '文',
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
      }).toDomain();

      expect(restored.answerText, isNull);
      expect(restored.lastReviewedAt, isNull);
      expect(restored.intervalDays, 0);
      expect(restored.repetitions, 0);
      expect(restored.easeFactor, 2.5);
      expect(restored.reviewCount, 0);
    });

    test('unknown enums fall back instead of throwing', () {
      final restored = ReviewCardDto.fromMap({
        'id': 'card-3',
        'uid': 'uid-1',
        'cardType': 'kanji',
        'sourceItemId': 'sentence-3',
        'promptText': '文',
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
      }).toDomain();

      expect(restored.cardType, CardType.sentence);
    });

    test('reads an ease factor stored as an int', () {
      final restored = ReviewCardDto.fromMap({
        'id': 'card-4',
        'uid': 'uid-1',
        'cardType': 'sentence',
        'sourceItemId': 'sentence-4',
        'promptText': '文',
        'createdAt': createdAt.toIso8601String(),
        'dueAt': dueAt.toIso8601String(),
        'easeFactor': 3,
      }).toDomain();

      expect(restored.easeFactor, 3.0);
    });

    test('fromMapSafe rejects documents missing any required field', () {
      expect(ReviewCardDto.fromMapSafe(const {}), isNull);
      expect(ReviewCardDto.fromMapSafe({'id': 'card'}), isNull);
      expect(
        ReviewCardDto.fromMapSafe({
          'id': 'card',
          'createdAt': createdAt.toIso8601String(),
          'dueAt': dueAt.toIso8601String(),
        }),
        isNull,
        reason: 'uid, sourceItemId and promptText are required',
      );
      expect(
        ReviewCardDto.fromMapSafe({
          'id': 'card',
          'uid': 'uid-1',
          'sourceItemId': 'sentence-1',
          'promptText': '文',
          'createdAt': createdAt.toIso8601String(),
          'dueAt': dueAt.toIso8601String(),
        }),
        isNotNull,
      );
    });

    test('copyWith can clear lastReviewedAt', () {
      final card = ReviewCard(
        id: 'card-5',
        uid: 'uid-1',
        cardType: CardType.sentence,
        sourceItemId: 'sentence-5',
        promptText: '文',
        createdAt: createdAt,
        dueAt: dueAt,
        lastReviewedAt: createdAt,
      );

      expect(card.copyWith(lastReviewedAt: () => null).lastReviewedAt, isNull);
    });
  });

  group('ReviewEventDto round trip', () {
    test('preserves every field', () {
      final dto = ReviewEventDto(
        id: 'review-1',
        uid: 'uid-1',
        cardId: 'card-1',
        cardType: CardType.sentence,
        rating: Rating.easy,
        reviewedAt: createdAt,
        intervalDaysAfter: 15,
      );

      final restored = ReviewEventDto.fromMap(dto.map).toDomain();

      expect(restored.id, 'review-1');
      expect(restored.uid, 'uid-1');
      expect(restored.cardId, 'card-1');
      expect(restored.cardType, CardType.sentence);
      expect(restored.rating, Rating.easy);
      expect(restored.reviewedAt, createdAt);
      expect(restored.intervalDaysAfter, 15);
    });

    test('stores enums as names', () {
      final dto = ReviewEventDto(
        id: 'review-2',
        uid: 'uid-1',
        cardId: 'card-1',
        cardType: CardType.vocabulary,
        rating: Rating.again,
        reviewedAt: createdAt,
        intervalDaysAfter: 0,
      );

      expect(dto.map['rating'], 'again');
      expect(dto.map['cardType'], 'vocabulary');
      expect(dto.map['reviewedAt'], createdAt.toIso8601String());
    });

    test('unknown enums fall back instead of throwing', () {
      final restored = ReviewEventDto.fromMap({
        'id': 'review-3',
        'uid': 'uid-1',
        'cardId': 'card-1',
        'cardType': 'kanji',
        'rating': 'perfect',
        'reviewedAt': createdAt.toIso8601String(),
        'intervalDaysAfter': 0,
      }).toDomain();

      expect(restored.cardType, CardType.sentence);
      expect(restored.rating, Rating.good);
    });

    test('fromMapSafe rejects documents missing any required field', () {
      expect(ReviewEventDto.fromMapSafe(const {}), isNull);
      expect(ReviewEventDto.fromMapSafe({'id': 'review'}), isNull);
      expect(
        ReviewEventDto.fromMapSafe({
          'id': 'review',
          'reviewedAt': createdAt.toIso8601String(),
        }),
        isNull,
        reason: 'uid and cardId are required',
      );
      expect(
        ReviewEventDto.fromMapSafe({
          'id': 'review',
          'uid': 'uid-1',
          'cardId': 'card-1',
          'reviewedAt': createdAt.toIso8601String(),
        }),
        isNotNull,
      );
    });
  });
}
