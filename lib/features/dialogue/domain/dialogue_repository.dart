import 'package:ingrain/features/dialogue/domain/dialogue.dart';

abstract interface class DialogueRepository {
  bool get isShowingCachedCopy;

  Future<List<DialogueSummary>> listSummaries();

  Future<Dialogue> getDialogue(String id);

  Future<Dialogue?> getCachedDialogue(String id);

  Future<void> cacheDialogue(Dialogue dialogue);
}
