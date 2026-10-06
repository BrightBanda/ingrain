import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/kana/domain/kana_chart.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

/// Everything the learner has saved, as one searchable snapshot.
class SearchCorpus {
  final List<VocabularyItem> words;
  final List<SentenceItem> sentences;
  final List<ContentItem> contents;
  final List<ReviewCard> cards;

  const SearchCorpus({
    this.words = const [],
    this.sentences = const [],
    this.contents = const [],
    this.cards = const [],
  });

  int get size => words.length + sentences.length + contents.length;
}

/// One match. Lower [score] ranks higher.
sealed class SearchHit {
  final int score;

  const SearchHit(this.score);
}

class WordHit extends SearchHit {
  final VocabularyItem word;

  /// The word's flashcard, when it has one, for its review history.
  final ReviewCard? card;

  const WordHit(super.score, this.word, this.card);
}

class SentenceHit extends SearchHit {
  final SentenceItem sentence;
  final ReviewCard? card;

  const SentenceHit(super.score, this.sentence, this.card);
}

class ContentHit extends SearchHit {
  final ContentItem content;

  const ContentHit(super.score, this.content);
}

/// A hand-written flashcard. Mined cards are found through their word or
/// sentence instead, so nothing shows up twice.
class CardHit extends SearchHit {
  final ReviewCard card;

  const CardHit(super.score, this.card);
}

/// Searches the learner's saved words, sentences, sources and cards.
///
/// Matching ignores case and the hiragana/katakana difference, so ねこ finds
/// ネコ. A hit in an item's main text (the word, the sentence, the title)
/// ranks above a hit in supporting text (meaning, translation, source), and
/// within each, exact beats prefix beats substring.
class LearningSearch {
  const LearningSearch();

  static const _secondaryPenalty = 3;

  List<SearchHit> search(String query, SearchCorpus corpus) {
    final needle = normalize(query);
    if (needle.isEmpty) return const [];

    final cardsBySource = <String, ReviewCard>{
      for (final card in corpus.cards)
        if (card.cardType != CardType.basic) card.sourceItemId: card,
    };

    final hits = <SearchHit>[
      for (final word in corpus.words)
        if (_score(
              needle,
              primary: [word.word, word.reading],
              secondary: [word.meaning, word.contextSentence, word.sourceTitle],
            )
            case final score?)
          WordHit(score, word, cardsBySource[word.id]),
      for (final sentence in corpus.sentences)
        if (_score(
              needle,
              primary: [sentence.japanese],
              secondary: [
                sentence.translation,
                sentence.explanation,
                sentence.sourceTitle,
              ],
            )
            case final score?)
          SentenceHit(score, sentence, cardsBySource[sentence.id]),
      for (final content in corpus.contents)
        if (_score(
              needle,
              primary: [content.title],
              secondary: [content.channelTitle],
            )
            case final score?)
          ContentHit(score, content),
      for (final card in corpus.cards)
        if (card.cardType == CardType.basic)
          if (_score(
                needle,
                primary: [card.promptText],
                secondary: [card.answerText],
              )
              case final score?)
            CardHit(score, card),
    ];

    return hits..sort((a, b) => a.score.compareTo(b.score));
  }

  /// Lower-case, trimmed, katakana folded into hiragana.
  static String normalize(String text) =>
      KanaChart.toHiragana(text.trim().toLowerCase());

  static int? _score(
    String needle, {
    required List<String?> primary,
    required List<String?> secondary,
  }) {
    int? best;
    void consider(String? field, int penalty) {
      if (field == null || field.isEmpty) return;
      final haystack = normalize(field);
      final int rank;
      if (haystack == needle) {
        rank = 0;
      } else if (haystack.startsWith(needle)) {
        rank = 1;
      } else if (haystack.contains(needle)) {
        rank = 2;
      } else {
        return;
      }
      final score = rank + penalty;
      if (best == null || score < best!) best = score;
    }

    for (final field in primary) {
      consider(field, 0);
    }
    for (final field in secondary) {
      consider(field, _secondaryPenalty);
    }
    return best;
  }
}
