import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalDocumentStore {
  final SharedPreferences _prefs;

  LocalDocumentStore(this._prefs);

  static const _prefix = 'local_store_';
  static const _usersKey = '${_prefix}users';

  String _collectionKey(String uid, String collection) =>
      '$_prefix$uid/$collection';

  Future<Map<String, dynamic>> _loadCollection(
    String uid,
    String collection,
  ) async {
    final raw = _prefs.getString(_collectionKey(uid, collection));
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveCollection(
    String uid,
    String collection,
    Map<String, dynamic> data,
  ) async {
    final raw = jsonEncode(data);
    await _prefs.setString(_collectionKey(uid, collection), raw);
  }

  Future<Map<String, dynamic>> getDoc(
    String uid,
    String collection,
    String docId,
  ) async {
    final coll = await _loadCollection(uid, collection);
    return Map<String, dynamic>.from(
      (coll[docId] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }

  Future<void> setDoc(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    final coll = await _loadCollection(uid, collection);
    if (merge && coll.containsKey(docId)) {
      final existing = Map<String, dynamic>.from(
        (coll[docId] as Map).cast<String, dynamic>(),
      );
      existing.addAll(data);
      coll[docId] = existing;
    } else {
      coll[docId] = data;
    }
    await _saveCollection(uid, collection, coll);
  }

  Future<void> deleteDoc(String uid, String collection, String docId) async {
    final coll = await _loadCollection(uid, collection);
    coll.remove(docId);
    await _saveCollection(uid, collection, coll);
  }

  Future<List<Map<String, dynamic>>> listDocs(
    String uid,
    String collection,
  ) async {
    final coll = await _loadCollection(uid, collection);
    return coll.values
        .map(
          (v) => Map<String, dynamic>.from((v as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> deleteCollection(String uid, String collection) async {
    await _prefs.remove(_collectionKey(uid, collection));
  }

  Future<List<String>> listCollectionIds(String uid) async {
    final userMap = await _loadUserMap();
    final collections = userMap[uid];
    if (collections is Map) {
      return collections.keys.toList().cast<String>();
    }
    return [];
  }

  Future<Map<String, dynamic>> _loadUserMap() async {
    final raw = _prefs.getString(_usersKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> registerCollection(String uid, String collection) async {
    final userMap = await _loadUserMap();
    final existing = Map<String, dynamic>.from(
      (userMap[uid] as Map?)?.cast<String, dynamic>() ?? {},
    );
    existing[collection] = true;
    userMap[uid] = existing;
    await _prefs.setString(_usersKey, jsonEncode(userMap));
  }

  Future<void> clearAllForUid(String uid) async {
    final collectionIds = await listCollectionIds(uid);
    for (final coll in collectionIds) {
      await _prefs.remove(_collectionKey(uid, coll));
    }
    final userMap = await _loadUserMap();
    userMap.remove(uid);
    await _prefs.setString(_usersKey, jsonEncode(userMap));
  }
}
