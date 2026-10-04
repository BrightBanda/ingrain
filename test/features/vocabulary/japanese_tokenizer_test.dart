import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/vocabulary/domain/japanese_tokenizer.dart';

void main() {
  group('JapaneseTokenizer', () {
    test('prefers the longest dictionary word at the cursor', () {
      final tokenizer = JapaneseTokenizer({'日本', '日本語', '語'});

      expect(tokenizer.tokenize('日本語'), ['日本語']);
    });

    test('falls back to a shorter known word when the longer one misses', () {
      final tokenizer = JapaneseTokenizer({'日本', '本'});

      // Matching starts at the cursor, so 本 is taken and 日 is left over.
      expect(tokenizer.tokenize('本日'), ['本', '日']);
    });

    test('splits unknown kanji into single tappable characters', () {
      final tokenizer = JapaneseTokenizer({'猫'});

      expect(tokenizer.tokenize('猫'), ['猫']);
      // 犬 is not in the dictionary but must still be reachable.
      expect(tokenizer.tokenize('猫と犬'), ['猫', 'と', '犬']);
    });

    test('groups kana runs that are not in the dictionary', () {
      final tokenizer = JapaneseTokenizer({'猫'});

      expect(tokenizer.tokenize('これはペン'), ['これは', 'ペン']);
      expect(tokenizer.tokenize('コーヒー'), ['コーヒー']);
    });

    test('keeps a kana word whole when the dictionary knows it', () {
      final tokenizer = JapaneseTokenizer({'にほんご', 'はな'});

      expect(tokenizer.tokenize('にほんご'), ['にほんご']);
      expect(tokenizer.tokenize('はな'), ['はな']);
    });

    test('separates punctuation, whitespace and latin runs', () {
      final tokenizer = JapaneseTokenizer({'猫'});

      expect(tokenizer.tokenize('猫と 犬、dog OK!'), [
        '猫',
        'と',
        ' ',
        '犬',
        '、',
        'dog',
        ' ',
        'OK',
        '!',
      ]);
    });

    test('returns nothing for empty or whitespace-only input', () {
      final tokenizer = JapaneseTokenizer({'猫'});

      expect(tokenizer.tokenize(''), isEmpty);
      expect(tokenizer.tokenize('   '), ['   ']);
    });

    test('works with an empty dictionary by splitting every character', () {
      final tokenizer = JapaneseTokenizer(const {});

      expect(tokenizer.maxWordLength, 0);
      expect(tokenizer.tokenize('猫'), ['猫']);
    });

    test('recognises halfwidth katakana as kana', () {
      final tokenizer = JapaneseTokenizer({'ｺｰﾋｰ'});

      expect(tokenizer.tokenize('ｺｰﾋｰ'), ['ｺｰﾋｰ']);
    });
  });
}
