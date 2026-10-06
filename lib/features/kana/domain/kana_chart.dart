/// One kana with its romaji (Hepburn).
class Kana {
  final String kana;
  final String romaji;

  const Kana(this.kana, this.romaji);
}

/// A titled block of the chart. Rows have [columns] cells; `null` is a gap,
/// like the empty slots in the や and わ rows.
class KanaSection {
  final String title;
  final String subtitle;
  final int columns;
  final List<List<Kana?>> rows;

  const KanaSection({
    required this.title,
    required this.subtitle,
    required this.columns,
    required this.rows,
  });

  int get count => rows.expand((row) => row).whereType<Kana>().length;
}

enum KanaScript { hiragana, katakana }

/// The hiragana and katakana charts. Katakana is derived from hiragana: the
/// two blocks sit exactly 0x60 apart in Unicode, so one table drives both.
abstract final class KanaChart {
  static List<KanaSection> sections(KanaScript script) =>
      script == KanaScript.hiragana
      ? _hiragana
      : [for (final section in _hiragana) _toKatakana(section)];

  static String toKatakana(String hiragana) => String.fromCharCodes(
    hiragana.runes.map(
      (rune) => rune >= 0x3041 && rune <= 0x3096 ? rune + 0x60 : rune,
    ),
  );

  static String toHiragana(String katakana) => String.fromCharCodes(
    katakana.runes.map(
      (rune) => rune >= 0x30A1 && rune <= 0x30F6 ? rune - 0x60 : rune,
    ),
  );

  static KanaSection _toKatakana(KanaSection section) => KanaSection(
    title: section.title,
    subtitle: section.subtitle,
    columns: section.columns,
    rows: [
      for (final row in section.rows)
        [
          for (final cell in row)
            cell == null ? null : Kana(toKatakana(cell.kana), cell.romaji),
        ],
    ],
  );

  static const _hiragana = [
    KanaSection(
      title: 'Basic',
      subtitle: 'The 46 core characters',
      columns: 5,
      rows: [
        [
          Kana('あ', 'a'),
          Kana('い', 'i'),
          Kana('う', 'u'),
          Kana('え', 'e'),
          Kana('お', 'o'),
        ],
        [
          Kana('か', 'ka'),
          Kana('き', 'ki'),
          Kana('く', 'ku'),
          Kana('け', 'ke'),
          Kana('こ', 'ko'),
        ],
        [
          Kana('さ', 'sa'),
          Kana('し', 'shi'),
          Kana('す', 'su'),
          Kana('せ', 'se'),
          Kana('そ', 'so'),
        ],
        [
          Kana('た', 'ta'),
          Kana('ち', 'chi'),
          Kana('つ', 'tsu'),
          Kana('て', 'te'),
          Kana('と', 'to'),
        ],
        [
          Kana('な', 'na'),
          Kana('に', 'ni'),
          Kana('ぬ', 'nu'),
          Kana('ね', 'ne'),
          Kana('の', 'no'),
        ],
        [
          Kana('は', 'ha'),
          Kana('ひ', 'hi'),
          Kana('ふ', 'fu'),
          Kana('へ', 'he'),
          Kana('ほ', 'ho'),
        ],
        [
          Kana('ま', 'ma'),
          Kana('み', 'mi'),
          Kana('む', 'mu'),
          Kana('め', 'me'),
          Kana('も', 'mo'),
        ],
        [Kana('や', 'ya'), null, Kana('ゆ', 'yu'), null, Kana('よ', 'yo')],
        [
          Kana('ら', 'ra'),
          Kana('り', 'ri'),
          Kana('る', 'ru'),
          Kana('れ', 're'),
          Kana('ろ', 'ro'),
        ],
        [Kana('わ', 'wa'), null, null, null, Kana('を', 'wo')],
        [Kana('ん', 'n'), null, null, null, null],
      ],
    ),
    KanaSection(
      title: 'Dakuten',
      subtitle: 'Voiced sounds, marked with ゛ or ゜',
      columns: 5,
      rows: [
        [
          Kana('が', 'ga'),
          Kana('ぎ', 'gi'),
          Kana('ぐ', 'gu'),
          Kana('げ', 'ge'),
          Kana('ご', 'go'),
        ],
        [
          Kana('ざ', 'za'),
          Kana('じ', 'ji'),
          Kana('ず', 'zu'),
          Kana('ぜ', 'ze'),
          Kana('ぞ', 'zo'),
        ],
        [
          Kana('だ', 'da'),
          Kana('ぢ', 'ji'),
          Kana('づ', 'zu'),
          Kana('で', 'de'),
          Kana('ど', 'do'),
        ],
        [
          Kana('ば', 'ba'),
          Kana('び', 'bi'),
          Kana('ぶ', 'bu'),
          Kana('べ', 'be'),
          Kana('ぼ', 'bo'),
        ],
        [
          Kana('ぱ', 'pa'),
          Kana('ぴ', 'pi'),
          Kana('ぷ', 'pu'),
          Kana('ぺ', 'pe'),
          Kana('ぽ', 'po'),
        ],
      ],
    ),
    KanaSection(
      title: 'Combinations',
      subtitle: 'A kana plus a small ゃ, ゅ or ょ',
      columns: 3,
      rows: [
        [Kana('きゃ', 'kya'), Kana('きゅ', 'kyu'), Kana('きょ', 'kyo')],
        [Kana('しゃ', 'sha'), Kana('しゅ', 'shu'), Kana('しょ', 'sho')],
        [Kana('ちゃ', 'cha'), Kana('ちゅ', 'chu'), Kana('ちょ', 'cho')],
        [Kana('にゃ', 'nya'), Kana('にゅ', 'nyu'), Kana('にょ', 'nyo')],
        [Kana('ひゃ', 'hya'), Kana('ひゅ', 'hyu'), Kana('ひょ', 'hyo')],
        [Kana('みゃ', 'mya'), Kana('みゅ', 'myu'), Kana('みょ', 'myo')],
        [Kana('りゃ', 'rya'), Kana('りゅ', 'ryu'), Kana('りょ', 'ryo')],
        [Kana('ぎゃ', 'gya'), Kana('ぎゅ', 'gyu'), Kana('ぎょ', 'gyo')],
        [Kana('じゃ', 'ja'), Kana('じゅ', 'ju'), Kana('じょ', 'jo')],
        [Kana('びゃ', 'bya'), Kana('びゅ', 'byu'), Kana('びょ', 'byo')],
        [Kana('ぴゃ', 'pya'), Kana('ぴゅ', 'pyu'), Kana('ぴょ', 'pyo')],
      ],
    ),
  ];
}
