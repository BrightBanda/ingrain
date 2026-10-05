import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/dialogue/data/local_dialogue_cache.dart';
import 'package:ingrain/features/dialogue/data/remote_dialogue_repository.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/dialogue/domain/dialogue_repository.dart';

final dialogueRepositoryProvider = Provider<DialogueRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return RemoteDialogueRepository(
    client: client,
    cache: LocalDialogueCache(
      ref.watch(localDocumentStoreProvider),
      ref.watch(authRepositoryProvider),
    ),
  );
});

final dialogueListViewModelProvider =
    AsyncNotifierProvider<DialogueListViewModel, List<DialogueSummary>>(
      DialogueListViewModel.new,
    );

class DialogueListViewModel extends AsyncNotifier<List<DialogueSummary>> {
  late DialogueRepository _repository;

  @override
  Future<List<DialogueSummary>> build() {
    _repository = ref.watch(dialogueRepositoryProvider);
    return _repository.listSummaries();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repository.listSummaries);
  }
}

final dialogueReaderViewModelProvider =
    AsyncNotifierProvider.family<DialogueReaderViewModel, Dialogue, String>(
      (dialogueId) => DialogueReaderViewModel(dialogueId),
    );

class DialogueReaderViewModel extends AsyncNotifier<Dialogue> {
  final String dialogueId;

  DialogueReaderViewModel(this.dialogueId);

  late DialogueRepository _repository;

  @override
  Future<Dialogue> build() {
    _repository = ref.watch(dialogueRepositoryProvider);
    return _repository.getDialogue(dialogueId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getDialogue(dialogueId));
  }
}
