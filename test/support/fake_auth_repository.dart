import 'package:ingrain/features/auth/domain/auth_repository.dart';

/// In-memory stand-in for Firebase Auth.
///
/// The repositories under test only ever ask for a uid and a display name, so a
/// fixed identity is enough — and it keeps them off the network.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.uid = 'test-uid', this.name});

  String uid;
  String? name;

  /// When set, [ensureUid] throws instead of returning a uid, standing in for the
  /// "router let an unauthenticated call through" case.
  Object? ensureUidError;

  final List<String> setDisplayNameCalls = [];

  bool get isSignedIn => uid.isNotEmpty && ensureUidError == null;

  @override
  Future<String> ensureUid() async {
    final error = ensureUidError;
    if (error != null) throw error;
    if (uid.isEmpty) {
      throw StateError('FakeAuthRepository has no uid; sign in first.');
    }
    return uid;
  }

  @override
  Future<String?> get displayName async => name;

  @override
  Future<void> setDisplayName(String name) async {
    setDisplayNameCalls.add(name);
    this.name = name;
  }
}
