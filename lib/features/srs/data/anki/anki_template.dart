/// Renders Anki card templates to plain text.
///
/// Covers what real decks use: `{{Field}}`, filters (`text:`, `cloze:`,
/// `furigana:`, `kana:`, `kanji:`, `hint:`; `type:` and `tts:` are dropped),
/// `{{#Field}}…{{/Field}}` and `{{^Field}}…{{/Field}}` sections, and
/// `{{FrontSide}}`. Output is plain text: the app shows cards as text, so
/// HTML is flattened, and images and sounds are left out.
abstract final class AnkiTemplate {
  static final _section = RegExp(
    r'\{\{([#^])\s*([^}]+?)\s*\}\}(.*?)\{\{/\s*\2\s*\}\}',
    dotAll: true,
  );
  static final _tag = RegExp(r'\{\{\s*([^}]+?)\s*\}\}');
  static final _cloze = RegExp(
    r'\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}',
    dotAll: true,
  );
  static final _furigana = RegExp(r' ?([^ >\[]+?)\[(.+?)\]');

  /// Renders [template] against [fields].
  ///
  /// [clozeNumber] is the cloze this card asks for (Anki card ord + 1);
  /// [question] decides whether that cloze is hidden. [frontSide] fills
  /// `{{FrontSide}}` on answer templates; pass '' to get only the back.
  static String render(
    String template,
    Map<String, String> fields, {
    required bool question,
    int clozeNumber = 1,
    String frontSide = '',
  }) {
    var text = template;
    // Sections can nest, so resolve until nothing changes.
    for (var i = 0; i < 10; i++) {
      final next = text.replaceAllMapped(_section, (m) {
        final present = _hasContent(fields[m.group(2)!]);
        final show = m.group(1) == '#' ? present : !present;
        return show ? m.group(3)! : '';
      });
      if (next == text) break;
      text = next;
    }

    text = text.replaceAllMapped(_tag, (m) {
      final expression = m.group(1)!;
      if (expression == 'FrontSide') return frontSide;
      final parts = expression.split(':');
      final fieldName = parts.last.trim();
      final filters = parts.sublist(0, parts.length - 1).map((f) => f.trim());
      var value = fields[fieldName];
      if (value == null) return '';
      for (final filter in filters.toList().reversed) {
        value = _applyFilter(
          filter,
          value!,
          question: question,
          clozeNumber: clozeNumber,
        );
        if (value == null) return '';
      }
      return value!;
    });

    return htmlToText(text);
  }

  static String? _applyFilter(
    String filter,
    String value, {
    required bool question,
    required int clozeNumber,
  }) {
    return switch (filter) {
      'text' => htmlToText(value),
      'cloze' => cloze(value, clozeNumber, question: question),
      'furigana' => value.replaceAllMapped(
        _furigana,
        (m) => '${m.group(1)}(${m.group(2)})',
      ),
      'kanji' => value.replaceAllMapped(_furigana, (m) => m.group(1)!),
      'kana' => value.replaceAllMapped(_furigana, (m) => m.group(2)!),
      'hint' => value,
      'type' || 'tts' => null,
      _ when filter.startsWith('type') || filter.startsWith('tts') => null,
      _ => value,
    };
  }

  /// The cloze text for card [number]: that deletion hidden as `[...]` (or
  /// `[hint]`) on the question, every other deletion shown as plain text.
  static String cloze(String text, int number, {required bool question}) {
    return text.replaceAllMapped(_cloze, (m) {
      final isTarget = int.parse(m.group(1)!) == number;
      if (!isTarget || !question) return m.group(2)!;
      final hint = m.group(3);
      return hint == null || hint.isEmpty ? '[...]' : '[$hint]';
    });
  }

  /// The cloze numbers used in [text], e.g. {1, 2} for `{{c1::…}} {{c2::…}}`.
  static Set<int> clozeNumbers(String text) => {
    for (final m in _cloze.allMatches(text)) int.parse(m.group(1)!),
  };

  static bool _hasContent(String? value) =>
      value != null && htmlToText(value).isNotEmpty;

  static final _blocks = RegExp(
    r'<(style|script)[^>]*>.*?</\1>',
    caseSensitive: false,
    dotAll: true,
  );
  static final _lineBreaks = RegExp(
    r'<br\s*/?>|</?(div|p|li|tr|h\d)[^>]*>|<hr[^>]*>',
    caseSensitive: false,
  );
  static final _tags = RegExp(r'<[^>]+>');
  static final _sounds = RegExp(r'\[sound:[^\]]*\]');
  static final _numericEntity = RegExp(r'&#(x?)([0-9a-fA-F]+);');

  /// Flattens card HTML to readable text: line breaks kept, tags, images,
  /// sounds and scripts removed, entities decoded, blank runs collapsed.
  static String htmlToText(String html) {
    var text = html
        .replaceAll(_blocks, '')
        .replaceAll(_sounds, '')
        .replaceAll(_lineBreaks, '\n')
        .replaceAll(_tags, '');
    text = text.replaceAllMapped(_numericEntity, (m) {
      final code = int.tryParse(
        m.group(2)!,
        radix: m.group(1)!.isEmpty ? 10 : 16,
      );
      return code == null ? m.group(0)! : String.fromCharCode(code);
    });
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    final lines = text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'[ \t ]+'), ' ').trim())
        .where((line) => line.isNotEmpty);
    return lines.join('\n');
  }
}
