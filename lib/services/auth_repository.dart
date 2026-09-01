import '../models/app_user.dart';

abstract interface class AuthRepository {
  bool get isAvailable;

  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

class AnonymousAuthRepository implements AuthRepository {
  @override
  bool get isAvailable => false;

  @override
  AppUser? get currentUser => null;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(null);

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnsupportedError('Authentication is unavailable.');

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnsupportedError('Authentication is unavailable.');

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnsupportedError('Authentication is unavailable.');

  @override
  Future<void> signOut() async {}
}
