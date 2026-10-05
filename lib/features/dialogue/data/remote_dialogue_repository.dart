import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ingrain/features/dialogue/data/dialogue_dto.dart';
import 'package:ingrain/features/dialogue/data/local_dialogue_cache.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/domain/dialogue_repository.dart';

const dialogueApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

class RemoteDialogueRepository implements DialogueRepository {
  final http.Client _client;
  final LocalDialogueCache _cache;
  final Uri _baseUri;

  @override
  bool isShowingCachedCopy = false;

  RemoteDialogueRepository({
    required this._client,
    required this._cache,
    String baseUrl = dialogueApiBaseUrl,
  }) : _baseUri = Uri.parse(baseUrl);

  @override
  Future<List<DialogueSummary>> listSummaries() async {
    try {
      final response = await _client.get(_baseUri.resolve('/dialogues'));
      _checkResponse(response);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final raw = decoded['dialogues'] as List;
      final summaries = raw
          .map(
            (value) => DialogueDto.summaryFromMap(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
      await _cache.cacheSummaries(summaries);
      isShowingCachedCopy = false;
      return summaries;
    } catch (_) {
      final cached = await _cache.getSummaries();
      if (cached.isEmpty) rethrow;
      isShowingCachedCopy = true;
      return cached;
    }
  }

  @override
  Future<Dialogue> getDialogue(String id) async {
    try {
      final response = await _client.get(_baseUri.resolve('/dialogues/$id'));
      _checkResponse(response);
      final dialogue = DialogueDto.fromMap(
        jsonDecode(response.body) as Map<String, dynamic>,
      ).toDomain();
      await _cache.cacheDialogue(dialogue);
      isShowingCachedCopy = false;
      return dialogue;
    } catch (_) {
      final cached = await getCachedDialogue(id);
      if (cached == null) rethrow;
      isShowingCachedCopy = true;
      return cached;
    }
  }

  @override
  Future<Dialogue?> getCachedDialogue(String id) => _cache.getDialogue(id);

  @override
  Future<void> cacheDialogue(Dialogue dialogue) =>
      _cache.cacheDialogue(dialogue);

  static void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException(
        'Dialogue API returned ${response.statusCode}',
        response.request?.url,
      );
    }
  }
}
