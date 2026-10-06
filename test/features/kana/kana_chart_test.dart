import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/kana/domain/kana_chart.dart';

void main() {
  test('hiragana has the 46 basic, 25 dakuten and 33 combination kana', () {
    final sections = KanaChart.sections(KanaScript.hiragana);

    expect(sections.map((s) => s.count), [46, 25, 33]);
    for (final section in sections) {
      for (final row in section.rows) {
        expect(row, hasLength(section.columns), reason: section.title);
      }
    }
  });

  test('katakana mirrors hiragana with the same romaji', () {
    final hiragana = KanaChart.sections(KanaScript.hiragana);
    final katakana = KanaChart.sections(KanaScript.katakana);

    final first = katakana.first.rows.first.first!;
    expect((first.kana, first.romaji), ('ア', 'a'));
    expect(katakana[2].rows[1][0]!.kana, 'シャ');
    expect(katakana.map((s) => s.count), hiragana.map((s) => s.count));
  });

  test('converts between the scripts and leaves other text alone', () {
    expect(KanaChart.toKatakana('ねこ'), 'ネコ');
    expect(KanaChart.toHiragana('ネコ'), 'ねこ');
    expect(KanaChart.toKatakana('猫 cat'), '猫 cat');
  });
}
