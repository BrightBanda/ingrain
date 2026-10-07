import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/srs/data/anki/anki_template.dart';

void main() {
  String render(
    String template,
    Map<String, String> fields, {
    bool question = true,
    int cloze = 1,
  }) => AnkiTemplate.render(
    template,
    fields,
    question: question,
    clozeNumber: cloze,
  );

  test('fields, front side and the answer divider', () {
    expect(render('{{Front}}', {'Front': '猫'}), '猫');
    expect(
      render('{{FrontSide}}<hr id=answer>{{Back}}', {'Back': 'cat'}),
      'cat',
      reason: 'the back alone, without the repeated front',
    );
  });

  test('conditional sections', () {
    const template =
        '{{Word}}{{#Notes}}<br>{{Notes}}{{/Notes}}{{^Notes}}!{{/Notes}}';

    expect(render(template, {'Word': '猫', 'Notes': 'pet'}), '猫\npet');
    expect(render(template, {'Word': '猫', 'Notes': ''}), '猫!');
  });

  test('cloze hides only this card\'s deletion on the question', () {
    const text = '{{c1::東京::place}}に{{c2::行きます}}';

    expect(render('{{cloze:Text}}', {'Text': text}), '[place]に行きます');
    expect(render('{{cloze:Text}}', {'Text': text}, cloze: 2), '東京に[...]');
    expect(
      render('{{cloze:Text}}', {'Text': text}, question: false),
      '東京に行きます',
    );
  });

  test('furigana filters', () {
    const reading = {'R': '日本[にほん]語[ご]'};

    expect(render('{{furigana:R}}', reading), '日本(にほん)語(ご)');
    expect(render('{{kanji:R}}', reading), '日本語');
    expect(render('{{kana:R}}', reading), 'にほんご');
  });

  test('typing, audio and unknown fields disappear', () {
    expect(
      render('{{Front}}{{type:Back}}{{Nope}}', {'Front': 'a', 'Back': 'b'}),
      'a',
    );
    expect(
      render('{{Front}}', {'Front': 'a[sound:a.mp3]<img src="x.png">'}),
      'a',
    );
  });

  test('HTML becomes readable text', () {
    expect(
      AnkiTemplate.htmlToText(
        '<div>one&nbsp;&amp; two</div><style>p{}</style><b>three</b>&#26085;',
      ),
      'one & two\nthree日',
    );
  });
}
