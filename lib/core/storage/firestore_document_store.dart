import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ingrain/core/storage/document_store.dart';

/// Firestore path for one document: `users/{uid}/{collection}/{docId}`.
///
/// A pure function so the layout can be asserted in a unit test without an
/// emulator. Two levels of nesting, no more — Firestore ids cannot contain `/`,
/// so anything that looks like a subcollection has to be flattened into the id.
String documentPath(String uid, String collection, String docId) =>
    'users/$uid/$collection/$docId';

/// Firestore path for a collection query: `users/{uid}/{collection}`.
String collectionPath(String uid, String collection) =>
    'users/$uid/$collection';

class FirestoreDocumentStore implements DocumentStore {
  final FirebaseFirestore _firestore;

  FirestoreDocumentStore(this._firestore);

  @override
  Future<Map<String, dynamic>> getDoc(
    String uid,
    String collection,
    String docId,
  ) async {
    final snapshot = await _firestore
        .doc(documentPath(uid, collection, docId))
        .get();
    final data = snapshot.data();
    if (data == null) return <String, dynamic>{};
    return Map<String, dynamic>.from(data);
  }

  @override
  Future<void> setDoc(
    String uid,
    String collection,
    String docId,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    assertFirestoreSafe(data, path: documentPath(uid, collection, docId));
    await _firestore
        .doc(documentPath(uid, collection, docId))
        .set(data, SetOptions(merge: merge));
  }

  @override
  Future<void> deleteDoc(String uid, String collection, String docId) async {
    await _firestore.doc(documentPath(uid, collection, docId)).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> listDocs(
    String uid,
    String collection,
  ) async {
    final snapshot = await _firestore.collection(collectionPath(uid, collection)).get();
    return snapshot.docs
        .map((doc) => doc.data())
        .whereType<Map<String, dynamic>>()
        .toList();
  }
}

/// Rejects any value Firestore cannot store, naming the offending path.
///
/// Every map the app persists is already ISO strings and primitives today, so this
/// never fires in practice. It exists because a stray `DateTime` would otherwise
/// surface as an opaque `code: invalid-argument` from deep inside the SDK, with no
/// indication of which field or document was responsible.
void assertFirestoreSafe(Object? value, {String path = 'value'}) {
  if (value == null || value is String || value is num || value is bool) return;

  if (value is List) {
    for (var i = 0; i < value.length; i++) {
      assertFirestoreSafe(value[i], path: '$path[$i]');
    }
    return;
  }

  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          key,
          path,
          'Firestore map keys must be String, got ${key.runtimeType}',
        );
      }
      assertFirestoreSafe(entry.value, path: '$path.$key');
    }
    return;
  }

  throw ArgumentError.value(
    value,
    path,
    'Firestore cannot store ${value.runtimeType}; convert it to a primitive first',
  );
}