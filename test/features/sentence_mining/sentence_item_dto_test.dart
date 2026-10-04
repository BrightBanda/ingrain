import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/sentence_mining/data/sentence_item_dto.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';

void main() {
  final createdAt = DateTime(2026, 3, 15, 9, 30);

  group('SentenceItemDto round trip', () {
    test('preserves every field', () {
      final original = SentenceItem(
        id: 'sentence-1',
        uid: 'uid-1',
        japanese: 'これはテストです。',
        translation: 'This is a test.',
        explanation: 'A simple declarative sentence.',
        sourceType: SourceType.youtube,
        sourceId: 'content-1',
        sourceTitle: 'My Video',
        timestampSeconds: 42,
        contextSentence: 'Adjacent line.',
        sessionId: 'session-1',
        createdAt: createdAt,
      );

      final dto = SentenceItemDto(
        id: original.id,
        uid: original.uid,
        japanese: original.japanese,
        translation: original.translation,
        explanation: original.explanation,
        sourceType: original.sourceType,
        sourceId: original.sourceId,
        sourceTitle: original.sourceTitle,
        timestampSeconds: original.timestampSeconds,
        contextSentence: original.contextSentence,
        sessionId: original.sessionId,
        createdAt: original.createdAt,
      );

      final restored = SentenceItemDto.fromMap(dto.map).toDomain();

      expect(restored.id, original.id);
      expect(restored.uid, original.uid);
      expect(restored.japanese, original.japanese);
      expect(restored.translation, original.translation);
      expect(restored.explanation, original.explanation);
      expect(restored.sourceType, original.sourceType);
      expect(restored.sourceId, original.sourceId);
      expect(restored.sourceTitle, original.sourceTitle);
      expect(restored.timestampSeconds, original.timestampSeconds);
      expect(restored.contextSentence, original.contextSentence);
      expect(restored.sessionId, original.sessionId);
      expect(restored.createdAt, original.createdAt);
    });

    test('keeps nullable fields null when omitted', () {
      final dto = SentenceItemDto(
        id: 'sentence-2',
        uid: 'uid-1',
        japanese: '文',
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: createdAt,
      );

      final restored = dto.toDomain();

      expect(restored.translation, isNull);
      expect(restored.explanation, isNull);
      expect(restored.sourceTitle, isNull);
      expect(restored.timestampSeconds, isNull);
      expect(restored.contextSentence, isNull);
      expect(restored.sessionId, isNull);
    });

    test('stores dates as ISO8601 and enums as names', () {
      final dto = SentenceItemDto(
        id: 'sentence-3',
        uid: 'uid-1',
        japanese: '文',
        sourceType: SourceType.podcast,
        sourceId: 'content-3',
        createdAt: createdAt,
      );

      expect(dto.map['createdAt'], createdAt.toIso8601String());
      expect(dto.map['sourceType'], 'podcast');
    });

    test('unknown sourceType falls back to manual', () {
      final restored = SentenceItemDto.fromMap({
        'id': 'sentence-4',
        'uid': 'uid-1',
        'japanese': '文',
        'sourceType': 'hologram',
        'sourceId': 'content-4',
        'createdAt': createdAt.toIso8601String(),
      }).toDomain();

      expect(restored.sourceType, SourceType.manual);
    });

    test('fromMapSafe rejects documents missing any required field', () {
      expect(SentenceItemDto.fromMapSafe(const {}), isNull);
      expect(SentenceItemDto.fromMapSafe({'id': 'x'}), isNull);
      expect(
        SentenceItemDto.fromMapSafe({
          'id': 'x',
          'uid': 'uid-1',
          'japanese': '文',
          'createdAt': createdAt.toIso8601String(),
        }),
        isNull,
        reason: 'sourceId is required',
      );
      expect(
        SentenceItemDto.fromMapSafe({
          'id': 'x',
          'uid': 'uid-1',
          'japanese': '文',
          'sourceId': 'manual',
          'createdAt': createdAt.toIso8601String(),
        }),
        isNotNull,
      );
    });
  });

  group('SentenceItem', () {
    SentenceItem build({String? translation}) {
      return SentenceItem(
        id: 'sentence-1',
        uid: 'uid-1',
        japanese: 'これはテストです。',
        translation: translation,
        sourceType: SourceType.manual,
        sourceId: 'manual',
        createdAt: createdAt,
      );
    }

    test('hasTranslation ignores blank strings', () {
      expect(build().hasTranslation, isFalse);
      expect(build(translation: '   ').hasTranslation, isFalse);
      expect(build(translation: 'This is a test.').hasTranslation, isTrue);
    });

    test('copyWith can clear a nullable field', () {
      final updated = build(translation: 'This is a test.')
          .copyWith(translation: () => null);

      expect(updated.translation, isNull);
    });

    test('copyWith leaves untouched fields intact', () {
      final original = build(translation: 'This is a test.');
      final updated = original.copyWith(japanese: '別の文');

      expect(updated.japanese, '別の文');
      expect(updated.translation, 'This is a test.');
      expect(updated.id, original.id);
      expect(updated.createdAt, original.createdAt);
    });
  });
}
