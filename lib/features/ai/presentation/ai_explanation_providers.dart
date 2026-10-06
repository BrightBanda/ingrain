import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/ai/data/remote_ai_explanation_repository.dart';
import 'package:ingrain/features/ai/domain/ai_explanation.dart';

final aiExplanationRepositoryProvider = Provider<AiExplanationRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  final auth = ref.watch(firebaseAuthProvider);
  return RemoteAiExplanationRepository(
    client: client,
    idToken: () async => auth.currentUser?.getIdToken(),
  );
});

/// One explanation per distinct request. A successful answer is kept for the
/// rest of the session so reopening the same word costs nothing; a failure is
/// dropped so "Try again" really retries.
///
/// Riverpod's automatic retry is off: every attempt spends provider quota, and
/// a rate-limited or unconfigured server would otherwise be hammered. Retrying
/// is the learner's choice.
final aiExplanationProvider = FutureProvider.autoDispose
    .family<AiExplanation, ExplainRequest>((ref, request) async {
      final explanation = await ref
          .watch(aiExplanationRepositoryProvider)
          .explain(request);
      ref.keepAlive();
      return explanation;
    }, retry: (_, _) => null);
