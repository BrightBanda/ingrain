import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/dialogue/data/local_dialogue_cache.dart';
import 'package:ingrain/features/dialogue/data/remote_dialogue_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth implements AuthRepository {
  @override
  Future<String> ensureUid() async => 'dialogue-test-user';

  @override
  Future<String?> get displayName async => null;

  @override
  Future<void> setDisplayName(String name) async {}

  @override
  Future<void> clear() async {}
}

class _FakeClient extends http.BaseClient {
  bool fail = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
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
}
