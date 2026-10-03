import 'dart:math';

import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/domain/auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  final LocalDocumentStore _store;

  LocalAuthRepository(this._store);

  static const String collection = 'profile';
  static const String docId = 'self';
  static const String uidKey = 'uid';
  static const String createdAtKey = 'createdAt';

  final Random _random = Random.secure();

  String _generateUid() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(0xFFFFFF);
    return '${ms.toRadixString(36)}-$rand';
  }

  @override
  Future<String> ensureUid() async {
    final existing = await _store.getDoc('self_uid', 'meta', 'uid');
    if (existing.isNotEmpty && existing[uidKey] != null) {
      return existing[uidKey] as String;
    }
    final uid = _generateUid();
    await _store.setDoc('self_uid', 'meta', 'uid', {uidKey: uid});
    return uid;
  }

  @override
  Future<String?> get displayName async {
    final uid = await ensureUid();
    final doc = await _store.getDoc(uid, collection, docId);
    if (doc.isEmpty) return null;
    return doc['displayName'] as String?;
  }

  @override
  Future<void> setDisplayName(String name) async {
    final uid = await ensureUid();
    await _store.setDoc(uid, collection, docId, {
      uidKey: uid,
      'displayName': name,
      createdAtKey: DateTime.now().toIso8601String(),
    }, merge: true);
  }

  @override
  Future<void> clear() async {
    final uid = await ensureUid();
    await _store.deleteDoc(uid, collection, docId);
  }
}
