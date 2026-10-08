import 'dart:math';

import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_repository.dart';
import 'package:ingrain/features/immersion/domain/immersion_session.dart';

class LocalImmersionRepository implements ImmersionRepository {
  final DocumentStore _store;
  final AuthRepository _auth;

  LocalImmersionRepository(this._store, this._auth);

  static const String collection = 'sessions';

  static String generateSessionId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure().nextInt(0xFFFFFF);
    return '${ms.toRadixString(36)}-$rand';
  }

  @override
  Future<ImmersionSession> startSession({
    required String sourceId,
    String? sourceTitle,
    required ActivityType activityType,
    required DateTime startedAt,
  }) async {
    final uid = await _auth.ensureUid();
    final id = generateSessionId();
    final session = ImmersionSession(
      id: id,
      uid: uid,
      sourceId: sourceId,
      sourceTitle: sourceTitle,
      activityType: activityType,
      startedAt: startedAt,
    );
    await _store.setDoc(uid, collection, id, {
      'id': id,
      'uid': uid,
      'sourceId': sourceId,
      if (sourceTitle != null) 'sourceTitle': sourceTitle,
      'activityType': activityType.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': null,
      'durationSeconds': 0,
      'lastPositionSeconds': 0,
    });
    return session;
  }

  @override
  Future<void> updateDuration(String sessionId, int durationSeconds) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return;
    doc['durationSeconds'] = durationSeconds;
    await _store.setDoc(uid, collection, sessionId, doc);
  }

  @override
  Future<void> updatePosition(String sessionId, int lastPositionSeconds) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return;
    doc['lastPositionSeconds'] = lastPositionSeconds;
    await _store.setDoc(uid, collection, sessionId, doc);
  }

  @override
  Future<void> pauseSession(String sessionId, DateTime pausedAt) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return;
    doc['pausedAt'] = pausedAt.toIso8601String();
    doc['isPaused'] = true;
    await _store.setDoc(uid, collection, sessionId, doc);
  }

  @override
  Future<void> resumeSession(String sessionId, DateTime resumedAt) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return;
    doc.remove('pausedAt');
    doc['isPaused'] = false;
    doc['resumedAt'] = resumedAt.toIso8601String();
    await _store.setDoc(uid, collection, sessionId, doc);
  }

  @override
  Future<void> stopSession(String sessionId, DateTime endedAt) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return;
    doc['endedAt'] = endedAt.toIso8601String();
    await _store.setDoc(uid, collection, sessionId, doc);
  }

  @override
  Future<ImmersionSession?> getSession(String sessionId) async {
    final uid = await _auth.ensureUid();
    final doc = await _store.getDoc(uid, collection, sessionId);
    if (doc.isEmpty) return null;
    return _docToDomain(doc);
  }

  @override
  Stream<List<ImmersionSession>> watchRecentSessions() async* {
    final uid = await _auth.ensureUid();
    final docs = await _store.listDocs(uid, collection);
    final sessions =
        docs.map((d) => _docToDomain(d)).whereType<ImmersionSession>().toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    yield sessions;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final uid = await _auth.ensureUid();
    await _store.deleteDoc(uid, collection, sessionId);
  }

  ImmersionSession _docToDomain(Map<String, dynamic> doc) {
    final endedAtStr = doc['endedAt'] as String?;
    return ImmersionSession(
      id: doc['id'] as String,
      uid: doc['uid'] as String,
      sourceId: doc['sourceId'] as String,
      sourceTitle: doc['sourceTitle'] as String?,
      activityType: ActivityType.values.firstWhere(
        (e) => e.name == doc['activityType'],
        orElse: () => ActivityType.watching,
      ),
      startedAt: DateTime.parse(doc['startedAt'] as String),
      endedAt: endedAtStr != null ? DateTime.parse(endedAtStr) : null,
      durationSeconds: (doc['durationSeconds'] as num?)?.toInt() ?? 0,
      lastPositionSeconds: (doc['lastPositionSeconds'] as num?)?.toInt() ?? 0,
    );
  }
}
