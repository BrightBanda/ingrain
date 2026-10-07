import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/kana/data/local_kana_progress_repository.dart';
import 'package:ingrain/features/kana/domain/kana_knowledge.dart';

final kanaProgressRepositoryProvider = Provider<KanaProgressRepository>(
  (ref) => LocalKanaProgressRepository(
    ref.watch(documentStoreProvider),
    ref.watch(authRepositoryProvider),
  ),
);

/// The learner's kana marks: kana → knowledge. Unmarked kana are absent.
class KanaProgressViewModel extends AsyncNotifier<Map<String, KanaKnowledge>> {
  @override
  Future<Map<String, KanaKnowledge>> build() =>
      ref.watch(kanaProgressRepositoryProvider).load();

  KanaKnowledge? of(String kana) => state.value?[kana];

  /// Marks [kana] (null clears the mark). The board updates at once; if saving
  /// fails, the previous mark comes back and the error is rethrown.
  Future<void> mark(String kana, KanaKnowledge? knowledge) async {
    final previous = state.value ?? const <String, KanaKnowledge>{};
    final next = Map<String, KanaKnowledge>.from(previous);
    if (knowledge == null) {
      next.remove(kana);
    } else {
      next[kana] = knowledge;
    }
    state = AsyncData(next);
    try {
      await ref.read(kanaProgressRepositoryProvider).set(kana, knowledge);
    } catch (_) {
      if (ref.mounted) state = AsyncData(previous);
      rethrow;
    }
  }

  /// Steps a mark forward for the long-press shortcut: none → somewhat →
  /// known → none.
  Future<void> cycle(String kana) => mark(kana, switch (of(kana)) {
    null => KanaKnowledge.somewhat,
    KanaKnowledge.somewhat => KanaKnowledge.known,
    KanaKnowledge.known => null,
  });
}

final kanaProgressViewModelProvider =
    AsyncNotifierProvider<KanaProgressViewModel, Map<String, KanaKnowledge>>(
      KanaProgressViewModel.new,
    );

/// Known kana across both scripts, for the profile's statistics.
final kanaKnownCountProvider = Provider<int>((ref) {
  final marks = ref.watch(kanaProgressViewModelProvider).value ?? const {};
  return marks.values.where((k) => k == KanaKnowledge.known).length;
});
