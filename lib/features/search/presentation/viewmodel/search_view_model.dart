import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/content/presentation/viewmodel/content_view_model.dart';
import 'package:ingrain/features/search/domain/learning_search.dart';
import 'package:ingrain/features/sentence_mining/presentation/viewmodel/sentence_mining_view_model.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:ingrain/features/vocabulary/presentation/viewmodel/vocabulary_view_model.dart';

/// Loaded once per visit to the search screen; every keystroke then filters
/// in memory.
final searchCorpusProvider = FutureProvider.autoDispose<SearchCorpus>((
  ref,
) async {
  final (words, sentences, contents, cards) = await (
    ref.watch(vocabularyRepositoryProvider).watchAll().first,
    ref.watch(sentenceRepositoryProvider).watchAll().first,
    ref.watch(contentRepositoryProvider).watchAll().first,
    ref.watch(reviewRepositoryProvider).listAllCards(),
  ).wait;
  return SearchCorpus(
    words: words,
    sentences: sentences,
    contents: contents,
    cards: cards,
  );
});

final searchQueryProvider =
    NotifierProvider.autoDispose<SearchQueryNotifier, String>(
      SearchQueryNotifier.new,
    );

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) => state = query;
}

final searchResultsProvider = Provider.autoDispose<AsyncValue<List<SearchHit>>>(
  (ref) {
    final query = ref.watch(searchQueryProvider);
    return ref
        .watch(searchCorpusProvider)
        .whenData((corpus) => const LearningSearch().search(query, corpus));
  },
);
