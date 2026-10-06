import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/core/storage/document_store.dart';
import 'package:ingrain/core/storage/firestore_document_store.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'Initialize SharedPreferences before runApp by overriding '
    'sharedPreferencesProvider.',
  );
});

final firebaseAppProvider = Provider<FirebaseApp>((ref) {
  throw StateError(
    'Initialize Firebase before runApp by overriding firebaseAppProvider.',
  );
});

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instanceFor(app: ref.watch(firebaseAppProvider)),
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instanceFor(app: ref.watch(firebaseAppProvider)),
);

/// Where all user learning data lives. Overridden in tests with the local store so
/// nothing reaches the network.
final documentStoreProvider = Provider<DocumentStore>(
  (ref) => FirestoreDocumentStore(ref.watch(firestoreProvider)),
);

/// Still needed for the offline dialogue cache, which uses key shapes Firestore
/// cannot represent. Not for user data.
final localDocumentStoreProvider = Provider<LocalDocumentStore>((ref) {
  return LocalDocumentStore(ref.watch(sharedPreferencesProvider));
});
