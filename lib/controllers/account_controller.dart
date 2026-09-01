import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app/app_capabilities.dart';
import '../app/capability_resolver.dart';
import '../models/app_entitlement.dart';
import '../models/app_user.dart';
import '../services/auth_repository.dart';
import '../services/entitlements_repository.dart';

class AccountController extends ChangeNotifier {
  AccountController(this._authRepository, this._entitlementsRepository) {
    _authSubscription = _authRepository.authStateChanges().listen(
      _onAuthChanged,
      onError: _onAuthError,
    );
  }

  final AuthRepository _authRepository;
  final EntitlementsRepository _entitlementsRepository;

  StreamSubscription<AppUser?>? _authSubscription;
  StreamSubscription<AppEntitlement>? _entitlementSubscription;
  int _authGeneration = 0;
  AppUser? _user;
  AppEntitlement _entitlement = AppEntitlement.unknown;
  AppCapabilities _capabilities = AppCapabilities.anonymousFree;
  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;

  bool get canAuthenticate => _authRepository.isAvailable;
  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  AppUser? get user => _user;
  bool get isSignedIn => _user != null;
  AppEntitlement get entitlement => _entitlement;
  AppCapabilities get capabilities => _capabilities;
  String? get errorMessage => _errorMessage;

  Future<bool> signIn({required String email, required String password}) =>
      _runAuthAction(
        () => _authRepository.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  Future<bool> createAccount({
    required String email,
    required String password,
  }) => _runAuthAction(
    () => _authRepository.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    ),
  );

  Future<bool> sendPasswordReset(String email) async {
    _setBusy();
    try {
      await _authRepository.sendPasswordResetEmail(email.trim());
      _clearBusy();
      return true;
    } catch (error) {
      _setActionError(error);
      return false;
    }
  }

  Future<void> signOut() async {
    _setBusy();
    try {
      await _authRepository.signOut();
      _clearBusy();
    } catch (error) {
      _setActionError(error);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _runAuthAction(Future<AppUser> Function() action) async {
    _setBusy();
    try {
      await action();
      _clearBusy();
      return true;
    } catch (error) {
      _setActionError(error);
      return false;
    }
  }

  void _setBusy() {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearBusy() {
    _isBusy = false;
    notifyListeners();
  }

  void _setActionError(Object error) {
    _isBusy = false;
    _errorMessage = _messageFor(error);
    notifyListeners();
  }

  void _onAuthChanged(AppUser? user) {
    final generation = ++_authGeneration;
    unawaited(_entitlementSubscription?.cancel());
    _entitlementSubscription = null;
    _user = user;
    _errorMessage = null;

    if (user == null) {
      _entitlement = AppEntitlement.free;
      _capabilities = AppCapabilities.anonymousFree;
      _isInitializing = false;
      notifyListeners();
      return;
    }

    _entitlement = AppEntitlement.unknown;
    _capabilities = AppCapabilities.anonymousFree;
    _isInitializing = true;
    notifyListeners();

    _entitlementSubscription = _entitlementsRepository
        .watchForUser(user.id)
        .listen(
          (entitlement) {
            if (generation != _authGeneration) return;
            _entitlement = entitlement;
            _capabilities = CapabilityResolver.resolve(
              user: _user,
              entitlement: entitlement,
            );
            _isInitializing = false;
            _errorMessage = null;
            notifyListeners();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (generation != _authGeneration) return;
            _entitlement = AppEntitlement.unknown;
            _capabilities = AppCapabilities.anonymousFree;
            _isInitializing = false;
            _errorMessage =
                'Premium status is unavailable. Local mode is active.';
            notifyListeners();
          },
        );
  }

  void _onAuthError(Object error, StackTrace stackTrace) {
    _user = null;
    _entitlement = AppEntitlement.unknown;
    _capabilities = AppCapabilities.anonymousFree;
    _isInitializing = false;
    _errorMessage = 'Sign-in status is unavailable. Local mode is active.';
    notifyListeners();
  }

  String _messageFor(Object error) {
    final message = error.toString();
    return message.replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_entitlementSubscription?.cancel());
    super.dispose();
  }
}
