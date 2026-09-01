import 'dart:async';

import 'package:flow_lens/app/app_capabilities.dart';
import 'package:flow_lens/controllers/account_controller.dart';
import 'package:flow_lens/models/app_entitlement.dart';
import 'package:flow_lens/models/app_user.dart';
import 'package:flow_lens/services/auth_repository.dart';
import 'package:flow_lens/services/entitlements_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const user = AppUser(id: 'user-1', email: 'coach@example.com');

  test('signed-out state resolves to anonymous local capabilities', () {
    final auth = _FakeAuthRepository();
    final entitlements = _FakeEntitlementsRepository();
    final controller = AccountController(auth, entitlements);

    auth.emit(null);

    expect(controller.isInitializing, isFalse);
    expect(controller.isSignedIn, isFalse);
    expect(controller.capabilities, same(AppCapabilities.anonymousFree));
    controller.dispose();
  });

  test('active premium entitlement enables premium launch capabilities', () {
    final auth = _FakeAuthRepository();
    final entitlements = _FakeEntitlementsRepository();
    final controller = AccountController(auth, entitlements);

    auth.emit(user);
    expect(controller.capabilities, same(AppCapabilities.anonymousFree));
    expect(controller.isInitializing, isTrue);

    entitlements.emit(
      const AppEntitlement(
        tier: AccountTier.premium,
        status: EntitlementStatus.active,
      ),
    );

    expect(controller.isInitializing, isFalse);
    expect(controller.capabilities, same(AppCapabilities.premiumLaunch));
    controller.dispose();
  });

  test('expired or errored entitlement fails closed to local mode', () {
    final auth = _FakeAuthRepository();
    final entitlements = _FakeEntitlementsRepository();
    final controller = AccountController(auth, entitlements);

    auth.emit(user);
    entitlements.emit(
      AppEntitlement(
        tier: AccountTier.premium,
        status: EntitlementStatus.active,
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    expect(controller.capabilities, same(AppCapabilities.anonymousFree));

    entitlements.emitError(StateError('offline'));
    expect(controller.capabilities, same(AppCapabilities.anonymousFree));
    expect(controller.errorMessage, contains('Local mode'));
    controller.dispose();
  });
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _currentUser;

  void emit(AppUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AppUser(id: 'created', email: email);

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AppUser(id: 'signed-in', email: email);

  @override
  Future<void> signOut() async => emit(null);
}

class _FakeEntitlementsRepository implements EntitlementsRepository {
  final _controller = StreamController<AppEntitlement>.broadcast(sync: true);

  void emit(AppEntitlement entitlement) => _controller.add(entitlement);

  void emitError(Object error) => _controller.addError(error);

  @override
  Stream<AppEntitlement> watchForUser(String userId) => _controller.stream;
}
