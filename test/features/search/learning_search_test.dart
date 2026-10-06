import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/features/content/domain/content_item.dart';
import 'package:ingrain/features/search/domain/learning_search.dart';
import 'package:ingrain/features/sentence_mining/domain/sentence_item.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/vocabulary/domain/vocabulary_item.dart';

final _date = DateTime(2026, 10, 1);

VocabularyItem word(
  String id,
  String text, {
  String? reading,
  String? meaning,
}) => VocabularyItem(
  id: id,
  uid: 'u',
  word: text,
  reading: reading,
  meaning: meaning,
  sourceType: SourceType.youtube,
  sourceId: 'video-1',
  sourceTitle: 'Cooking vlog',
  createdAt: _date,
  updatedAt: _date,
);

SentenceItem sentence(String id, String japanese, {String? translation}) =>
    SentenceItem(
      id: id,
      uid: 'u',
      japanese: japanese,
      translation: translation,
      sourceType: SourceType.youtube,
      sourceId: 'video-1',
      createdAt: _date,
    );

ReviewCard card(String id, String prompt, CardType type, {String? source}) =>
    ReviewCard(
      id: id,
      uid: 'u',
      cardType: type,
      sourceItemId: source ?? id,
      promptText: prompt,
      createdAt: _date,
      dueAt: _date,
      reviewCount: 2,
    );

void main() {
  const search = LearningSearch();

  final corpus = SearchCorpus(
    words: [
      word('w-neko', '猫', reading: 'ねこ', meaning: 'cat'),
      word('w-koneko', '子猫', reading: 'こねこ', meaning: 'kitten'),
    ],
    sentences: [sentence('s-1', '猫が好きです。', translation: 'I like cats.')],
    contents: [
      ContentItem(
        id: 'video-1',
        sourceType: SourceType.youtube,
        sourceUrl: 'https://youtu.be/video-1',
        title: 'Cooking vlog',
        lastOpenedAt: _date,
      ),
    ],
    cards: [
      card('c-word', '猫', CardType.vocabulary, source: 'w-neko'),
      card('c-basic', '食べる', CardType.basic),
    ],
  );

  test('an empty query finds nothing', () {
    expect(search.search('  ', corpus), isEmpty);
  });

  test('exact beats prefix beats substring, main text beats notes', () {
    final hits = search.search('猫', corpus);

    expect(hits.first, isA<WordHit>());
    expect((hits.first as WordHit).word.word, '猫');
    expect(hits.whereType<SentenceHit>(), hasLength(1));
    expect(hits.whereType<WordHit>().map((h) => h.word.word), ['猫', '子猫']);
  });

  test('katakana and hiragana match each other, case is ignored', () {
    expect(search.search('ネコ', corpus).whereType<WordHit>(), hasLength(2));
    expect(search.search('KITTEN', corpus).single, isA<WordHit>());
  });

  test('finds sentences by translation and videos by title', () {
    expect(search.search('like cats', corpus).single, isA<SentenceHit>());
    expect(
      search.search('cooking', corpus).whereType<ContentHit>(),
      hasLength(1),
    );
  });

  test('mined cards attach to their item instead of showing twice', () {
    final hits = search.search('猫', corpus);

    expect(hits.whereType<CardHit>(), isEmpty);
    expect((hits.first as WordHit).card?.id, 'c-word');
    expect(search.search('食べる', corpus).single, isA<CardHit>());
  });
}
