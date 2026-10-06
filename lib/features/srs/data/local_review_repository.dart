import 'dart:math';

import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/srs/data/review_card_dto.dart';
import 'package:ingrain/features/srs/data/review_event_dto.dart';
import 'package:ingrain/features/srs/domain/review_card.dart';
import 'package:ingrain/features/srs/domain/review_event.dart';
import 'package:ingrain/features/srs/domain/review_repository.dart';

class LocalReviewRepository implements ReviewRepository {
  final DocumentStore _store;
  final AuthRepository _auth;

  LocalReviewRepository(this._store, this._auth);

  static const String cardCollection = 'reviewCards';
  static const String historyCollection = 'reviewHistory';

  static String generateId(String prefix) {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFF);
    return '$prefix-${ms.toRadixString(36)}-$rand';
  }

  @override
  Future<ReviewCard> createCard({
    required CardType cardType,
    required String sourceItemId,
    required String promptText,
    String? answerText,
    DateTime? createdAt,
    DateTime? dueAt,
  }) async {
    final uid = await _auth.ensureUid();
    final created = createdAt ?? DateTime.now();
    final card = ReviewCard(
      id: generateId('card'),
      uid: uid,
      cardType: cardType,
      sourceItemId: sourceItemId,
      promptText: promptText,
      answerText: _normalize(answerText),
      createdAt: created,
      dueAt: dueAt ?? created,
    );
    await _store.setDoc(uid, cardCollection, card.id, _toMap(card));
    return card;
  }

  @override
  Future<void> saveCard(ReviewCard card) async {
    final uid = await _auth.ensureUid();
    await _store.setDoc(uid, cardCollection, card.id, _toMap(card));
  }

  @override
  Future<List<ReviewCard>> listDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final cards = await listAllCards();
    final due = cards.where((c) => c.isDueAt(at)).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return due;
  }

  @override
  Future<List<ReviewCard>> listAllCards() async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, cardCollection);
    return docs.map(ReviewCardDto.fromMapSafe).whereType<ReviewCard>().toList();
  }

  @override
  Future<ReviewEvent> recordReview({
    required String cardId,
    required CardType cardType,
    required Rating rating,
    required DateTime reviewedAt,
    required int intervalDaysAfter,
  }) async {
    final uid = await _auth.ensureUid();
    final event = ReviewEvent(
      id: generateId('review'),
      uid: uid,
      cardId: cardId,
      cardType: cardType,
      rating: rating,
      reviewedAt: reviewedAt,
      intervalDaysAfter: intervalDaysAfter,
    );
    final dto = ReviewEventDto(
      id: event.id,
      uid: event.uid,
      cardId: event.cardId,
      cardType: event.cardType,
      rating: event.rating,
      reviewedAt: event.reviewedAt,
      intervalDaysAfter: event.intervalDaysAfter,
    );
    await _store.setDoc(uid, historyCollection, event.id, dto.map);
    return event;
  }

  @override
  Future<List<ReviewEvent>> listReviewHistory({int limit = 200}) async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, historyCollection);
    final events =
        docs.map(ReviewEventDto.fromMapSafe).whereType<ReviewEvent>().toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    if (events.length > limit) {
      return events.sublist(0, limit);
    }
    return events;
  }

  @override
  Future<void> deleteCardsForSource(String sourceItemId) async {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, cardCollection);
    for (final doc in docs) {
      if (doc['sourceItemId'] == sourceItemId) {
        await _store.deleteDoc(uid, cardCollection, doc['id'] as String);
      }
    }
  }

  @override
  Future<int> countDue({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final cards = await listAllCards();
    return cards.where((c) => c.isDueAt(at)).length;
  }

  static Map<String, dynamic> _toMap(ReviewCard card) {
    return ReviewCardDto(
      id: card.id,
      uid: card.uid,
      deckId: card.deckId,
      cardType: card.cardType,
      sourceItemId: card.sourceItemId,
      promptText: card.promptText,
      answerText: card.answerText,
      createdAt: card.createdAt,
      dueAt: card.dueAt,
      intervalDays: card.intervalDays,
      repetitions: card.repetitions,
      easeFactor: card.easeFactor,
      reviewCount: card.reviewCount,
      lastReviewedAt: card.lastReviewedAt,
    ).map;
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
