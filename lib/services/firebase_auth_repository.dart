import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(
    (user) => user == null ? null : _toAppUser(user),
  );

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireUser(credential);
  }

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requireUser(credential);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();

  AppUser _requireUser(UserCredential credential) {
    final user = credential.user;
    if (user == null) {
      throw StateError('Firebase did not return a signed-in user.');
    }
    return _toAppUser(user);
  }

  AppUser _toAppUser(User user) => AppUser(
    id: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );
}
