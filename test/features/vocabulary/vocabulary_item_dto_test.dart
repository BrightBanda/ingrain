import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/vocabulary/data/vocabulary_item_dto.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

void main() {
  final createdAt = DateTime(2026, 3, 15, 9, 30);

  VocabularyItem sample() => VocabularyItem(
    id: 'word-1',
    uid: 'uid-1',
    word: '猫',
    reading: 'ねこ',
    meaning: 'cat (animal)',
    pos: 'noun',
    sourceType: SourceType.youtube,
    sourceId: 'content-1',
    sourceTitle: 'My Video',
    timestampSeconds: 42,
    contextSentence: '猫が好きです。',
    sessionId: 'session-1',
    state: VocabState.learning,
    createdAt: createdAt,
    updatedAt: createdAt,
    encounterCount: 3,
  );

  group('VocabularyItemDto', () {
    test('round trips every field', () {
      final original = sample();

      final restored = VocabularyItemDto.fromMap(
        VocabularyItemDto(
          id: original.id,
          uid: original.uid,
          word: original.word,
          reading: original.reading,
          meaning: original.meaning,
          pos: original.pos,
          sourceType: original.sourceType,
          sourceId: original.sourceId,
          sourceTitle: original.sourceTitle,
          timestampSeconds: original.timestampSeconds,
          contextSentence: original.contextSentence,
          sessionId: original.sessionId,
          state: original.state,
          createdAt: original.createdAt,
          updatedAt: original.updatedAt,
          encounterCount: original.encounterCount,
        ).map,
      ).toDomain();

      expect(restored.id, original.id);
      expect(restored.uid, original.uid);
      expect(restored.word, '猫');
      expect(restored.reading, 'ねこ');
      expect(restored.meaning, 'cat (animal)');
      expect(restored.pos, 'noun');
      expect(restored.sourceType, SourceType.youtube);
      expect(restored.sourceId, 'content-1');
      expect(restored.sourceTitle, 'My Video');
      expect(restored.timestampSeconds, 42);
      expect(restored.contextSentence, '猫が好きです。');
      expect(restored.sessionId, 'session-1');
      expect(restored.state, VocabState.learning);
      expect(restored.createdAt, createdAt);
      expect(restored.updatedAt, createdAt);
      expect(restored.encounterCount, 3);
    });

    test('stores dates as ISO8601 and the state as its enum name', () {
      final map = VocabularyItemDto(
        id: 'word-1',
        uid: 'uid-1',
        word: '猫',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        state: VocabState.mastered,
        createdAt: createdAt,
        updatedAt: createdAt,
      ).map;

      expect(map['createdAt'], '2026-03-15T09:30:00.000');
      expect(map['state'], 'mastered');
      expect(map['sourceType'], 'manual');
    });

    test('defaults a missing state and encounter count', () {
      final item = VocabularyItemDto.fromMap({
        'id': 'word-1',
        'uid': 'uid-1',
        'word': '猫',
        'sourceType': 'youtube',
        'sourceId': 'content-1',
        'createdAt': createdAt.toIso8601String(),
      }).toDomain();

      expect(item.state, VocabState.encountered);
      expect(item.encounterCount, 1);
      expect(item.updatedAt, createdAt);
    });

    test('falls back to manual for an unknown source type', () {
      final item = VocabularyItemDto.fromMap({
        'id': 'word-1',
        'uid': 'uid-1',
        'word': '猫',
        'sourceType': 'podcast-ish',
        'sourceId': 'content-1',
        'createdAt': createdAt.toIso8601String(),
      }).toDomain();

      expect(item.sourceType, SourceType.manual);
    });

    test('rejects documents that are missing required keys', () {
      expect(
        VocabularyItemDto.fromMapSafe(const {'uid': 'uid-1', 'word': '猫'}),
        isNull,
      );
      expect(VocabularyItemDto.fromMapSafe(const {}), isNull);
    });
  });

  group('VocabularyItem', () {
    test('formats the headword with its reading only when it differs', () {
      expect(sample().displayWithReading, '猫 (ねこ)');

      final noReading = sample().copyWith(reading: () => null);
      expect(noReading.displayWithReading, '猫');
      expect(noReading.hasReading, isFalse);
      expect(noReading.hasMeaning, isTrue);
    });

    test('orders states along the intended progression', () {
      expect(VocabState.mastered.isAtLeast(VocabState.learning), isTrue);
      expect(VocabState.learning.isAtLeast(VocabState.known), isFalse);
      expect(VocabState.fromName('known'), VocabState.known);
      expect(VocabState.fromName('nonsense'), VocabState.encountered);
      expect(VocabState.fromName(null), VocabState.encountered);
    });
  });
}
