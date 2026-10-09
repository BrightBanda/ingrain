import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ingrain/core/config/api_config.dart';
import 'package:ingrain/core/error/app_error.dart';
import 'package:ingrain/features/ai/domain/ai_explanation.dart';

/// Asks the ingrain API's `POST /ai/explain`. The AI provider key lives on the
/// server; this side only proves who the learner is with a Firebase ID token.
class RemoteAiExplanationRepository implements AiExplanationRepository {
  final http.Client _client;
  final Future<String?> Function() _idToken;
  final Uri _endpoint;
  final Duration _timeout;

  RemoteAiExplanationRepository({
    required this._client,
    required this._idToken,
    String baseUrl = apiBaseUrl,
    this._timeout = const Duration(seconds: 30),
  }) : _endpoint = Uri.parse(baseUrl).resolve('/ai/explain');

  @override
  Future<AiExplanation> explain(ExplainRequest request) async {
    final token = await _idToken();
    if (token == null) {
      throw const AiExplanationException(
        AppError(type: AppErrorType.auth, message: 'Sign in to use AI help.'),
      );
    }

    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'text': request.text,
              'kind': request.kind.name,
              if (request.context != null) 'context': request.context,
            }),
          )
          .timeout(_timeout);
    } on TimeoutException catch (error) {
      throw AiExplanationException(
        AppError(
          type: AppErrorType.network,
          message: 'The AI took too long to answer. Try again.',
          exception: error,
        ),
      );
    } catch (error) {
      throw AiExplanationException(
        AppError(
          type: AppErrorType.network,
          message: 'Could not reach the HitaruJP server.',
          exception: error,
        ),
      );
    }

    if (response.statusCode != 200) throw _errorFor(response.statusCode);
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (error) {
      throw AiExplanationException(
        AppError.unknown(error, message: 'The AI sent an unreadable answer.'),
      );
    }
  }

  static AiExplanationException _errorFor(int status) {
    final (type, message) = switch (status) {
      401 || 403 => (AppErrorType.auth, 'Sign in again to use AI help.'),
      429 => (AppErrorType.rateLimited, 'The AI is busy. Try again shortly.'),
      503 => (AppErrorType.unknown, 'AI help is not set up on the server yet.'),
      422 => (AppErrorType.validation, 'That text is too long to explain.'),
      _ => (AppErrorType.unknown, 'The AI could not answer. Try again.'),
    };
    return AiExplanationException(AppError(type: type, message: message));
  }

  /// Maps the camelCase response body. Public for tests.
  static AiExplanation parse(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objects(Object? value) => [
      for (final item in value as List? ?? const [])
        Map<String, dynamic>.from(item as Map),
    ];

    return AiExplanation(
      translation: json['translation'] as String,
      reading: json['reading'] as String?,
      meaning: json['meaning'] as String,
      partOfSpeech: json['partOfSpeech'] as String?,
      nuance: json['nuance'] as String? ?? '',
      formality: json['formality'] as String? ?? '',
      grammar: [
        for (final point in objects(json['grammar']))
          GrammarPoint(
            point: point['point'] as String,
            explanation: point['explanation'] as String,
          ),
      ],
      alternatives: [
        for (final alternative in objects(json['alternatives']))
          NaturalAlternative(
            japanese: alternative['japanese'] as String,
            note: alternative['note'] as String,
          ),
      ],
    );
  }
}
