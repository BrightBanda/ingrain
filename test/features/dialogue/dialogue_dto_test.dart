import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/dialogue/data/dialogue_dto.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';

void main() {
  test('round-trips dialogue and preserves per-token fields', () {
    final dialogue = DialogueDto.fromMap({
      'id': 'lesson-1',
      'title': 'At the station',
      'level': 'N5',
      'kind': 'dialogue',
      'speakers': ['ミカ', 'ケン'],
      'attribution': 'NHK WORLD-JAPAN',
      'sourceUrl': 'https://example.com/lesson-1',
      'updatedAt': '2026-10-01T00:00:00Z',
      'lines': [
        {
          'index': 0,
          'speaker': 'ミカ',
          'tokens': [
            {'surface': '駅', 'reading': 'えき', 'romaji': 'eki'},
            {'surface': 'は'},
          ],
        },
      ],
    }).toDomain();

    final restored = DialogueDto.fromMap(dialogueToMap(dialogue)).toDomain();

    expect(restored.lines.single.text, '駅は');
    expect(restored.lines.single.tokens.first.reading, 'えき');
    expect(restored.lines.single.tokens.first.romaji, 'eki');
    expect(restored.lines.single.tokens.last.reading, isNull);
    expect(restored.lines.single.tokens.last.romaji, isNull);
    expect(restored.source.url, 'https://example.com/lesson-1');
    expect(restored.updatedAt, DateTime.utc(2026, 10, 1));
  });

  test('accepts absent optional speaker, token metadata, and source URL', () {
    final dialogue = DialogueDto.fromMap({
      'id': 'story-1',
      'title': 'A short story',
      'kind': 'story',
      'lines': [
        {
          'index': 0,
          'tokens': [
            {'surface': '春'},
          ],
        },
      ],
    }).toDomain();

    expect(dialogue.kind, DialogueKind.story);
    expect(dialogue.lines.single.speaker, isNull);
    expect(dialogue.lines.single.tokens.single.reading, isNull);
    expect(dialogue.lines.single.tokens.single.romaji, isNull);
    expect(dialogue.source.url, isNull);
  });
}
