import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/domain/dialogue_text_parser.dart';
import 'package:ingrain/features/vocabulary/domain/dictionary_index.dart';

void main() {
  final dictionary = DictionaryIndex(const [
    DictionaryEntry(surface: '猫', reading: 'ねこ', meanings: ['cat']),
    DictionaryEntry(surface: 'です', reading: 'です', meanings: ['to be']),
  ]);
  const parser = DialogueTextParser();

  Dialogue parse(String text) => parser.parse(
    id: 'my-1',
    title: ' Pets ',
    text: text,
    dictionary: dictionary,
  );

  test('splits speakers on ASCII and full-width colons', () {
    final dialogue = parse('Aiko: 猫です。\n\n健：はい');

    expect(dialogue.title, 'Pets');
    expect(dialogue.kind, DialogueKind.dialogue);
    expect(dialogue.speakers, ['Aiko', '健']);
    expect(dialogue.lines.map((l) => l.speaker), ['Aiko', '健']);
    expect(dialogue.lines.map((l) => l.text), ['猫です。', 'はい']);
    expect(dialogue.lines.map((l) => l.index), [0, 1]);
  });

  test('text without speakers becomes a story', () {
    final dialogue = parse('猫です。\n猫です。');

    expect(dialogue.kind, DialogueKind.story);
    expect(dialogue.speakers, isEmpty);
    expect(dialogue.lines.every((l) => l.speaker == null), isTrue);
  });

  test('tokens carry dictionary readings only when they add something', () {
    final tokens = parse('猫です').lines.single.tokens;

    expect(tokens.map((t) => t.surface), ['猫', 'です']);
    expect(tokens.first.reading, 'ねこ');
    expect(tokens.last.reading, isNull);
  });

  test('a long prefix before a colon is not a speaker', () {
    final line = parse('This sentence is far too long to be a name: 猫')
        .lines
        .single;

    expect(line.speaker, isNull);
  });
}
