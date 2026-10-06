import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/dialogue/data/local_dialogue_cache.dart';
import 'package:ingrain/features/dialogue/data/remote_dialogue_repository.dart';
import 'package:ingrain/features/dialogue/data/sample_dialogue_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  @override
  Future<String> ensureUid() async => 'dialogue-test-user';

  @override
  Future<String?> get displayName async => null;

  @override
  Future<void> setDisplayName(String name) async {}
}

class _FakeClient extends http.BaseClient {
  bool fail = false;

  /// Like an unreachable host: the request never completes.
  bool hang = false;

  final List<Uri> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request.url);
    if (hang) return Completer<http.StreamedResponse>().future;
    if (fail) throw http.ClientException('offline');
    final body = request.url.path == '/dialogues'
        ? jsonEncode({
            'dialogues': [
              {
                'id': 'lesson-1',
                'title': 'Greetings',
                'level': 'N5',
                'lineCount': 1,
                'updatedAt': '2026-10-01T00:00:00Z',
              },
            ],
          })
        : jsonEncode({
            'id': 'lesson-1',
            'title': 'Greetings',
            'level': 'N5',
            'lines': [
              {
                'index': 0,
                'tokens': [
                  {'surface': 'こんにちは', 'reading': 'こんにちは'},
                ],
              },
            ],
          });
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeClient client;
  late RemoteDialogueRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    client = _FakeClient();
    repository = RemoteDialogueRepository(
      client: client,
      cache: LocalDialogueCache(LocalDocumentStore(preferences), _Auth()),
      baseUrl: 'https://api.example.test',
    );
  });

  test(
    'fetches and caches summaries, then serves them offline as stale',
    () async {
      final online = await repository.listSummaries();
      expect(online.single.id, 'lesson-1');
      expect(repository.isShowingCachedCopy, isFalse);

      client.fail = true;
      final cached = await repository.listSummaries();
      expect(cached.single.title, 'Greetings');
      expect(repository.isShowingCachedCopy, isTrue);
    },
  );

  test('fetches and caches dialogue details for offline reading', () async {
    final online = await repository.getDialogue('lesson-1');
    expect(online.lines.single.text, 'こんにちは');

    client.fail = true;
    final cached = await repository.getDialogue('lesson-1');
    expect(cached.lines.single.tokens.single.reading, 'こんにちは');
    expect(repository.isShowingCachedCopy, isTrue);
  });

  test('falls back to bundled samples when offline with no cache', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    client.fail = true;
    final offline = RemoteDialogueRepository(
      client: client,
      cache: LocalDialogueCache(LocalDocumentStore(preferences), _Auth()),
      samples: SampleDialogueLoader(),
      baseUrl: 'https://api.example.test',
    );

    final summaries = await offline.listSummaries();
    expect(summaries, isNotEmpty);
    expect(offline.isShowingCachedCopy, isTrue);

    final first = await offline.getDialogue(summaries.first.id);
    expect(first.lines, isNotEmpty);
  });

  test('still throws offline when there are no samples either', () async {
    client.fail = true;
    expect(repository.listSummaries(), throwsA(isA<http.ClientException>()));
  });

  test('every bundled sample parses with lines and speakers', () async {
    final samples = await SampleDialogueLoader().load();
    expect(samples.length, greaterThanOrEqualTo(4));
    expect(samples.map((d) => d.id).toSet(), hasLength(samples.length));
    for (final dialogue in samples) {
      expect(dialogue.lines, isNotEmpty, reason: dialogue.id);
      for (final line in dialogue.lines) {
        expect(line.text, isNotEmpty, reason: '${dialogue.id}#${line.index}');
      }
    }
  });

  group('with bundled samples', () {
    late RemoteDialogueRepository withSamples;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      withSamples = RemoteDialogueRepository(
        client: client,
        cache: LocalDialogueCache(LocalDocumentStore(preferences), _Auth()),
        samples: SampleDialogueLoader(),
        baseUrl: 'https://api.example.test',
        timeout: const Duration(milliseconds: 200),
      );
    });

    test('lists the server dialogues first, then the samples', () async {
      final summaries = await withSamples.listSummaries();

      expect(summaries.first.id, 'lesson-1');
      expect(summaries.map((s) => s.id), contains('sample-cafe-01'));
      expect(withSamples.isShowingCachedCopy, isFalse);
    });

    test('opens a sample without touching the network', () async {
      client.hang = true;

      final dialogue = await withSamples.getDialogue('sample-cafe-01');

      expect(dialogue.title, 'Ordering at a Café');
      expect(client.requests, isEmpty);
    });

    test(
      'an unreachable server times out instead of loading forever',
      () async {
        client.hang = true;

        final summaries = await withSamples.listSummaries().timeout(
          const Duration(seconds: 2),
        );

        expect(summaries.map((s) => s.id), contains('sample-cafe-01'));
        expect(withSamples.isShowingCachedCopy, isTrue);
        await expectLater(
          withSamples.getDialogue('lesson-1'),
          throwsA(isA<http.ClientException>()),
        );
      },
    );
  });
}
