/// Builds small but real Anki packages (legacy and modern) for tests: two
/// notes in deck `Japanese::Core` covering review, new, learning, suspended
/// and cloze cards, plus one image-only card that must be skipped.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:sqlite3/sqlite3.dart';

const crt = 1700000000;
const deckAnkiId = 1700000000000;
const basicId = 111;
const clozeId = 222;

const cardColumns =
    'id integer, nid integer, did integer, ord integer, mod integer, '
    'usn integer, type integer, queue integer, due integer, ivl integer, '
    'factor integer, reps integer, lapses integer, left integer, '
    'odue integer, odid integer, flags integer, data text';

/// Notes and cards shared by both package formats.
void fillNotesAndCards(Database db) {
  db.execute(
    'create table notes (id integer, mid integer, flds text, tags text)',
  );
  db.execute('create table cards ($cardColumns)');
  void note(int id, int mid, List<String> fields) => db.execute(
    'insert into notes values (?, ?, ?, ?)',
    [id, mid, fields.join('\x1f'), ''],
  );
  void card(
    int id,
    int nid,
    int ord, {
    required int type,
    required int queue,
    required int due,
    int ivl = 0,
    int factor = 0,
    int reps = 0,
    int lapses = 0,
    int left = 0,
  }) => db.execute(
    "insert into cards values (?, ?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, '')",
    [
      id,
      nid,
      deckAnkiId,
      ord,
      type,
      queue,
      due,
      ivl,
      factor,
      reps,
      lapses,
      left,
    ],
  );

  note(1, basicId, ['猫', 'cat<br><b>neko</b>']);
  note(2, clozeId, ['{{c1::東京}}に{{c2::行きます}}', 'Tokyo']);
  note(3, basicId, ['<img src="x.png">', 'picture']);

  // Basic and reversed: the forward card is a mature review, the reverse new.
  card(
    10,
    1,
    0,
    type: 2,
    queue: 2,
    due: 10,
    ivl: 10,
    factor: 2300,
    reps: 5,
    lapses: 1,
  );
  card(11, 1, 1, type: 0, queue: 0, due: 3);
  // Cloze: deletion 1 is mid-learning, deletion 2 is a suspended review.
  card(20, 2, 0, type: 1, queue: 1, due: crt + 600, left: 1001);
  card(21, 2, 1, type: 2, queue: -1, due: 5, ivl: 3, factor: 2500);
  // Image only: nothing readable on the front, so it is skipped.
  card(30, 3, 0, type: 0, queue: 0, due: 4);
}

const basicTemplates = [
  ('{{Front}}', '{{FrontSide}}<hr id=answer>{{Back}}'),
  ('{{Back}}', '{{FrontSide}}<hr id=answer>{{Front}}'),
];
const clozeTemplate = ('{{cloze:Text}}', '{{cloze:Text}}<br>{{Back Extra}}');

Uint8List legacyCollection(String path) {
  final db = sqlite3.open(path);
  Map<String, dynamic> model(
    int id,
    int type,
    List<String> fields,
    List<(String, String)> templates,
  ) => {
    'id': id,
    'type': type,
    'flds': [
      for (final (i, name) in fields.indexed) {'name': name, 'ord': i},
    ],
    'tmpls': [
      for (final (i, t) in templates.indexed)
        {'ord': i, 'qfmt': t.$1, 'afmt': t.$2},
    ],
  };
  db.execute('create table col (crt integer, models text, decks text)');
  db.execute('insert into col values (?, ?, ?)', [
    crt,
    jsonEncode({
      '$basicId': model(basicId, 0, ['Front', 'Back'], basicTemplates),
      '$clozeId': model(clozeId, 1, ['Text', 'Back Extra'], [clozeTemplate]),
    }),
    jsonEncode({
      '1': {'name': 'Default'},
      '$deckAnkiId': {'name': 'Japanese::Core'},
    }),
  ]);
  fillNotesAndCards(db);
  db.close();
  return File(path).readAsBytesSync();
}

List<int> protoString(int field, String value) {
  final bytes = utf8.encode(value);
  return [(field << 3) | 2, ...varint(bytes.length), ...bytes];
}

List<int> varint(int value) {
  final out = <int>[];
  do {
    var byte = value & 0x7f;
    value >>= 7;
    if (value != 0) byte |= 0x80;
    out.add(byte);
  } while (value != 0);
  return out;
}

Uint8List modernCollection(String path) {
  final db = sqlite3.open(path);
  db.execute('create table col (crt integer)');
  db.execute('insert into col values (?)', [crt]);
  db.execute('create table notetypes (id integer, name text, config blob)');
  db.execute(
    'create table fields (ntid integer, ord integer, name text, config blob)',
  );
  db.execute(
    'create table templates (ntid integer, ord integer, name text, config blob)',
  );
  db.execute('create table decks (id integer, name text)');
  db.execute('insert into notetypes values (?, ?, ?)', [
    basicId,
    'Basic',
    Uint8List(0),
  ]);
  db.execute('insert into notetypes values (?, ?, ?)', [
    clozeId,
    'Cloze',
    Uint8List.fromList([0x08, 0x01]), // kind = cloze
  ]);
  for (final (ntid, names) in [
    (basicId, ['Front', 'Back']),
    (clozeId, ['Text', 'Back Extra']),
  ]) {
    for (final (i, name) in names.indexed) {
      db.execute('insert into fields values (?, ?, ?, ?)', [
        ntid,
        i,
        name,
        Uint8List(0),
      ]);
    }
  }
  for (final (ntid, templates) in [
    (basicId, basicTemplates),
    (clozeId, [clozeTemplate]),
  ]) {
    for (final (i, t) in templates.indexed) {
      db.execute('insert into templates values (?, ?, ?, ?)', [
        ntid,
        i,
        'Card ${i + 1}',
        Uint8List.fromList([...protoString(1, t.$1), ...protoString(2, t.$2)]),
      ]);
    }
  }
  db.execute('insert into decks values (1, ?)', ['Default']);
  db.execute('insert into decks values (?, ?)', [
    deckAnkiId,
    'Japanese\x1fCore',
  ]);
  fillNotesAndCards(db);
  db.close();
  return File(path).readAsBytesSync();
}

String buildApkg(Directory dir, String name, Map<String, List<int>> entries) {
  final archive = Archive();
  for (final MapEntry(:key, :value) in entries.entries) {
    archive.addFile(ArchiveFile.bytes(key, value));
  }
  final file = File('${dir.path}/$name')
    ..writeAsBytesSync(ZipEncoder().encode(archive));
  return file.path;
}
