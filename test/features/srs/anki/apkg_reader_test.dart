import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/data/anki/apkg_reader.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:libcompress/libcompress.dart';

import '../../../support/anki_fixture.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('apkg-test'));
  tearDown(() => dir.deleteSync(recursive: true));

  AnkiImportPlan read(String path) =>
      ApkgReader.readFile(path, tempDirectory: dir.path, learningStepCount: 2);

  void expectFixture(AnkiImportPlan plan) {
    expect(
      plan.decks,
      hasLength(1),
      reason: 'the empty Default deck is left out',
    );
    final deck = plan.decks.single;
    expect(deck.name, 'Japanese › Core');
    expect(ApkgReader.deckId(deck.ankiId), 'anki-$deckAnkiId');
    expect(plan.skipped, 1);
    expect(plan.cardCount, 4);

    final cards = {for (final c in deck.cards) c.id: c};
    final forward = cards['anki-10']!;
    expect(forward.promptText, '猫');
    expect(forward.answerText, 'cat\nneko');
    expect(forward.state, CardState.review);
    expect(forward.intervalDays, 10);
    expect(forward.easeFactor, 2.3);
    expect(forward.lapses, 1);
    expect(forward.reviewCount, 5);
    expect(
      forward.dueAt,
      DateTime.fromMillisecondsSinceEpoch((crt + 10 * 86400) * 1000),
    );
    expect(forward.deckId, 'anki-$deckAnkiId');

    final reverse = cards['anki-11']!;
    expect(reverse.promptText, 'cat\nneko');
    expect(reverse.answerText, '猫');
    expect(reverse.state, CardState.newCard);

    final cloze1 = cards['anki-20']!;
    expect(cloze1.promptText, '[...]に行きます');
    expect(cloze1.answerText, '東京に行きます\nTokyo');
    expect(cloze1.state, CardState.learning);
    expect(cloze1.step, 1, reason: 'one of two steps left');
    expect(
      cloze1.dueAt,
      DateTime.fromMillisecondsSinceEpoch((crt + 600) * 1000),
    );

    final cloze2 = cards['anki-21']!;
    expect(cloze2.promptText, '東京に[...]');
    expect(cloze2.suspended, isTrue);
  }

  test('reads a legacy package (collection.anki2)', () {
    final db = legacyCollection('${dir.path}/legacy.db');
    expectFixture(
      read(
        buildApkg(dir, 'legacy.apkg', {
          'collection.anki2': db,
          'media': utf8.encode('{}'),
        }),
      ),
    );
  });

  test('reads a modern zstd package (collection.anki21b)', () {
    final db = modernCollection('${dir.path}/modern.db');
    final path = buildApkg(dir, 'modern.apkg', {
      'collection.anki21b': ZstdCodec().compress(db),
      // Modern exports also carry a stub legacy collection; it must be ignored.
      'collection.anki2': utf8.encode('please update Anki'),
    });
    expectFixture(read(path));
  });

  test('decompresses output of the real zstd tool', () {
    // Made with `zstd -19`, the same library Anki uses: guards against a
    // decoder that only understands its own encoder.
    final compressed = File('test/fixtures/zstd_sample.txt.zst')
        .readAsBytesSync();
    final expected = File('test/fixtures/zstd_sample.txt').readAsBytesSync();

    expect(ApkgReader.decompressZstd(compressed), expected);
  });

  test('a file that is not a package is rejected clearly', () {
    final path = '${dir.path}/notes.apkg';
    File(path).writeAsStringSync('hello');

    expect(() => read(path), throwsA(isA<AnkiFormatException>()));
  });

  test('a zip without a collection is rejected clearly', () {
    final path = buildApkg(dir, 'empty.apkg', {'media': utf8.encode('{}')});

    expect(
      () => read(path),
      throwsA(
        isA<AnkiFormatException>().having(
          (e) => e.message,
          'message',
          contains('No Anki collection'),
        ),
      ),
    );
  });
}
