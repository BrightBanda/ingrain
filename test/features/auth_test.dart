import 'package:flutter_test/flutter_test.dart';
import 'package:ingrain/core/storage/local_document_store.dart';
import 'package:ingrain/features/auth/data/local_auth_repository.dart';
import 'package:ingrain/features/auth/data/user_profile_dto.dart';
import 'package:ingrain/features/auth/domain/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalDocumentStore', () {
    late LocalDocumentStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = LocalDocumentStore(prefs);
    });

    test('setDoc and getDoc round-trip', () async {
      await store.setDoc('uid1', 'items', 'doc1', {
        'name': 'test',
        'count': 42,
      });
      final doc = await store.getDoc('uid1', 'items', 'doc1');
      expect(doc['name'], 'test');
      expect(doc['count'], 42);
    });

    test('merge updates existing data without losing other fields', () async {
      await store.setDoc('uid1', 'items', 'doc1', {
        'name': 'test',
        'count': 42,
      });
      await store.setDoc('uid1', 'items', 'doc1', {'count': 99}, merge: true);
      final doc = await store.getDoc('uid1', 'items', 'doc1');
      expect(doc['name'], 'test');
      expect(doc['count'], 99);
    });

    test('deleteDoc removes the document', () async {
      await store.setDoc('uid1', 'items', 'doc1', {'name': 'test'});
      await store.deleteDoc('uid1', 'items', 'doc1');
      final doc = await store.getDoc('uid1', 'items', 'doc1');
      expect(doc, isEmpty);
    });

    test('listDocs returns all documents', () async {
      await store.setDoc('uid1', 'items', 'doc1', {'name': 'a'});
      await store.setDoc('uid1', 'items', 'doc2', {'name': 'b'});
      final docs = await store.listDocs('uid1', 'items');
      expect(docs.length, 2);
    });

    test('user-scoping prevents cross-user access', () async {
      await store.setDoc('uid1', 'items', 'doc1', {'name': 'a'});
      await store.setDoc('uid2', 'items', 'doc1', {'name': 'b'});
      final doc1 = await store.getDoc('uid1', 'items', 'doc1');
      final doc2 = await store.getDoc('uid2', 'items', 'doc1');
      expect(doc1['name'], 'a');
      expect(doc2['name'], 'b');
    });

    test('getDoc returns empty map for non-existent document', () async {
      final doc = await store.getDoc('uid1', 'items', 'nonexistent');
      expect(doc, isEmpty);
    });

    test('collection data is stable across read/write cycles', () async {
      await store.setDoc('uid1', 'items', 'doc1', {'name': 'test'});
      final doc1 = await store.getDoc('uid1', 'items', 'doc1');
      expect(doc1['name'], 'test');

      await store.setDoc('uid1', 'items', 'doc1', {'name': 'updated'});
      final doc2 = await store.getDoc('uid1', 'items', 'doc1');
      expect(doc2['name'], 'updated');
    });
  });

  group('LocalAuthRepository', () {
    late LocalDocumentStore store;
    late LocalAuthRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = LocalDocumentStore(prefs);
      repo = LocalAuthRepository(store);
    });

    test('ensureUid generates and persists a stable uid', () async {
      final uid1 = await repo.ensureUid();
      final uid2 = await repo.ensureUid();
      expect(uid1, isNotEmpty);
      expect(uid1, uid2);
    });

    test('uid is stored in meta collection for later retrieval', () async {
      final uid = await repo.ensureUid();
      final uidAgain = await repo.ensureUid();
      expect(uidAgain, uid);
    });

    test('displayName is null initially', () async {
      await repo.ensureUid();
      expect(await repo.displayName, isNull);
    });

    test('setDisplayName persists displayName', () async {
      final uid = await repo.ensureUid();
      await repo.setDisplayName('Alice');
      final doc = await store.getDoc(uid, 'profile', 'self');
      expect(doc['displayName'], 'Alice');
      expect(await repo.displayName, 'Alice');
    });

    test('clear removes displayName', () async {
      await repo.ensureUid();
      await repo.setDisplayName('Bob');
      await repo.clear();
      expect(await repo.displayName, isNull);
    });

    test('clear removes displayName but keeps uid stable', () async {
      final uid1 = await repo.ensureUid();
      await repo.setDisplayName('Alice');

      await repo.clear();
      final uid2 = await repo.ensureUid();
      expect(uid1, uid2);
      expect(await repo.displayName, isNull);
    });
  });

  group('UserProfileDto', () {
    test('toDomain maps correctly', () {
      final dto = UserProfileDto(
        uid: 'test-uid',
        displayName: 'Test User',
        createdAt: DateTime(2024, 1, 1),
      );
      final profile = dto.toDomain();
      expect(profile.uid, 'test-uid');
      expect(profile.displayName, 'Test User');
      expect(profile.createdAt, DateTime(2024, 1, 1));
    });

    test('fromMapSafe returns null for empty map', () {
      expect(UserProfileDto.fromMapSafe({}), isNull);
    });

    test('fromMapSafe returns null when uid is null', () {
      expect(UserProfileDto.fromMapSafe({'displayName': 'Test'}), isNull);
    });

    test('fromMapSafe parses valid map', () {
      final profile = UserProfileDto.fromMapSafe({
        'uid': 'uid123',
        'displayName': 'Alice',
        'createdAt': '2024-01-01T00:00:00.000',
      });
      expect(profile?.uid, 'uid123');
      expect(profile?.displayName, 'Alice');
    });
  });

  group('AuthState', () {
    test('loading state is not onboarded', () {
      const state = AuthState.loading();
      expect(state.isLoading, isTrue);
      expect(state.isOnboarded, isFalse);
    });

    test('ready state without displayName is not onboarded', () {
      const state = AuthState.ready(uid: 'uid');
      expect(state.isOnboarded, isFalse);
    });

    test('ready state with displayName is onboarded', () {
      const state = AuthState.ready(uid: 'uid', displayName: 'Alice');
      expect(state.isOnboarded, isTrue);
    });
  });
}
