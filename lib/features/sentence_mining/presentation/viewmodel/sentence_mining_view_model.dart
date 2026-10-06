import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/providers.dart';
import 'package:ingrain/core/utils/clock.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/content/domain/transcript_sentence.dart';
import 'package:ingrain/features/dialogue/domain/dialogue.dart';
import 'package:ingrain/features/immersion/presentation/viewmodel/immersion_session_view_model.dart';
import 'package:ingrain/features/sentence_mining/data/local_sentence_repository.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_repository.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';

final sentenceRepositoryProvider = Provider<SentenceRepository>((ref) {
  final store = ref.watch(documentStoreProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  return LocalSentenceRepository(store, authRepo);
});

final sentenceMiningViewModelProvider =
    AsyncNotifierProvider<SentenceMiningViewModel, List<SentenceItem>>(
      SentenceMiningViewModel.new,
    );

class SentenceMiningViewModel extends AsyncNotifier<List<SentenceItem>> {
  late SentenceRepository _repository;
  late ReviewRepository _reviewRepository;
  late Clock _clock;

  @override
  FutureOr<List<SentenceItem>> build() async {
    _repository = ref.watch(sentenceRepositoryProvider);
    _reviewRepository = ref.watch(reviewRepositoryProvider);
    _clock = ref.watch(clockProvider);
    return _repository.watchAll().first;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _repository.watchAll().first);
  }

  /// Saves a sentence and immediately queues it for review so the mine ->
  /// review loop is a single tap.
  Future<SentenceItem?> saveSentence({
    required String japanese,
    String? translation,
    String? explanation,
    required SourceType sourceType,
    required String sourceId,
    String? sourceTitle,
    int? timestampSeconds,
    String? contextSentence,
    String? sessionId,
  }) async {
    final trimmed = japanese.trim();
    if (trimmed.isEmpty) return null;

    try {
      final sentence = await _repository.save(
        japanese: trimmed,
        translation: translation,
        explanation: explanation,
        sourceType: sourceType,
        sourceId: sourceId,
        sourceTitle: sourceTitle,
        timestampSeconds: timestampSeconds,
        contextSentence: contextSentence,
        sessionId: sessionId,
        createdAt: _clock.now,
      );
      await _createReviewCard(sentence);
      ref.invalidate(dueCountProvider);
      await refresh();
      return sentence;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Saves a transcript line, carrying the source title and the surrounding
  /// context so the mined sentence keeps its immersion memory.
  Future<SentenceItem?> saveFromTranscript({
    required String contentId,
    required TranscriptSentence sentence,
    required List<TranscriptSentence> transcript,
    String? contentTitle,
    String? sessionId,
    String? translation,
    String? explanation,
  }) async {
    return saveSentence(
      japanese: sentence.text,
      translation: translation,
      explanation: explanation,
      sourceType: SourceType.youtube,
      sourceId: contentId,
      sourceTitle: contentTitle,
      timestampSeconds: sentence.startSeconds,
      contextSentence: contextForTranscript(transcript, sentence.index),
      sessionId: sessionId,
    );
  }

  Future<SentenceItem?> saveFromDialogue({
    required String dialogueId,
    required String dialogueTitle,
    required DialogueLine line,
    required List<DialogueLine> lines,
    String? translation,
    String? explanation,
  }) {
    return saveSentence(
      japanese: line.text,
      translation: translation,
      explanation: explanation,
      sourceType: SourceType.dialogue,
      sourceId: dialogueId,
      sourceTitle: dialogueTitle,
      contextSentence: contextForDialogue(lines, line.index),
    );
  }

  Future<void> deleteSentence(String id) async {
    await _repository.delete(id);
    await _reviewRepository.deleteCardsForSource(id);
    await refresh();
  }

  Future<void> _createReviewCard(SentenceItem sentence) async {
    final answer = sentence.hasTranslation
        ? sentence.translation
        : sentence.contextSentence;
    await _reviewRepository.createCard(
      cardType: CardType.sentence,
      sourceItemId: sentence.id,
      promptText: sentence.japanese,
      answerText: answer,
      createdAt: sentence.createdAt,
    );
  }

  /// Joins the neighbouring transcript lines so a review prompt keeps enough
  /// surrounding context to be understood out of context.
  static String? contextForTranscript(
    List<TranscriptSentence> transcript,
    int index,
  ) {
    return _contextAt(transcript.map((line) => line.text).toList(), index);
  }

  static String? contextForDialogue(List<DialogueLine> lines, int index) {
    return _contextAt(lines.map((line) => line.text).toList(), index);
  }

  static String? _contextAt(List<String> lines, int index) {
    if (lines.isEmpty) return null;
    final context = [
      if (index > 0 && index - 1 < lines.length) lines[index - 1],
      if (index >= 0 && index < lines.length) lines[index],
      if (index + 1 < lines.length) lines[index + 1],
    ].where((text) => text.isNotEmpty).join(' ').trim();
    return context.isEmpty ? null : context;
  }
}
