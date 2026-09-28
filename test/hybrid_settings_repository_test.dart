import 'dart:async';

import 'package:flow_lens/controllers/account_controller.dart';
import 'package:flow_lens/controllers/settings_controller.dart';
import 'package:flow_lens/models/app_entitlement.dart';
import 'package:flow_lens/models/app_settings.dart';
import 'package:flow_lens/models/app_user.dart';
import 'package:flow_lens/services/auth_repository.dart';
import 'package:flow_lens/services/cloud_settings_store.dart';
import 'package:flow_lens/services/entitlements_repository.dart';
import 'package:flow_lens/services/hybrid_settings_repository.dart';
import 'package:flow_lens/services/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sticky touch fast play defaults off and persists through settings',
    () async {
      expect(
        AppSettings.fromMap({'fastPlaySpeed': 5}).stickyFastPlayOnTouch,
        isFalse,
      );
      final repository = _MemorySettingsRepository(const AppSettings());
      final controller = SettingsController(repository);
      addTearDown(controller.dispose);
      await controller.setStickyFastPlayOnTouch(true);
      expect(
        AppSettings.fromMap(repository.value.toMap()).stickyFastPlayOnTouch,
        isTrue,
      );
      expect(
        controller.settings.copyWith(fastPlaySpeed: 6).stickyFastPlayOnTouch,
        isTrue,
      );
      await controller.resetToDefaults();
      expect(repository.value.stickyFastPlayOnTouch, isFalse);
    },
  );

  const localSettings = AppSettings(fastPlaySpeed: 2.0);
  const cloudSettings = AppSettings(fastPlaySpeed: 6.0);

  test('free users load and save locally without cloud access', () async {
    final local = _MemorySettingsRepository(localSettings);
    final cloud = _MemoryCloudSettingsStore();
    final repository = HybridSettingsRepository(
      localRepository: local,
      cloudStore: cloud,
      userId: () => 'user-1',
      canSync: () => false,
    );

    expect(await repository.load(), localSettings);
    await repository.save(cloudSettings);

    expect(local.value, cloudSettings);
    expect(cloud.loadCount, 0);
    expect(cloud.saveCount, 0);
  });

  test('existing cloud settings win and refresh the local cache', () async {
    final local = _MemorySettingsRepository(localSettings);
    final cloud = _MemoryCloudSettingsStore()..value = cloudSettings;
    final repository = HybridSettingsRepository(
      localRepository: local,
      cloudStore: cloud,
      userId: () => 'user-1',
      canSync: () => true,
    );

    expect(await repository.load(), cloudSettings);
    expect(local.value, cloudSettings);
    expect(repository.syncError, isNull);
  });

  test('first premium sign-in seeds missing cloud settings', () async {
    final local = _MemorySettingsRepository(localSettings);
    final cloud = _MemoryCloudSettingsStore();
    final repository = HybridSettingsRepository(
      localRepository: local,
      cloudStore: cloud,
      userId: () => 'user-1',
      canSync: () => true,
    );

    expect(await repository.load(), localSettings);
    expect(cloud.value, localSettings);
    expect(cloud.saveCount, 1);
  });

  test(
    'cloud failures preserve local behavior and report sync status',
    () async {
      final local = _MemorySettingsRepository(localSettings);
      final cloud = _MemoryCloudSettingsStore()..throwOnLoad = true;
      final repository = HybridSettingsRepository(
        localRepository: local,
        cloudStore: cloud,
        userId: () => 'user-1',
        canSync: () => true,
      );

      expect(await repository.load(), localSettings);
      expect(repository.syncError, contains('Using local settings'));

      cloud
        ..throwOnLoad = false
        ..throwOnSave = true;
      await repository.save(cloudSettings);
      expect(local.value, cloudSettings);
      expect(repository.syncError, contains('saved locally'));
    },
  );

  test('settings reconcile when an account becomes premium', () async {
    final auth = _FakeAuthRepository();
    final entitlements = _FakeEntitlementsRepository();
    final account = AccountController(auth, entitlements);
    final local = _MemorySettingsRepository(localSettings);
    final cloud = _MemoryCloudSettingsStore()..value = cloudSettings;
    final repository = HybridSettingsRepository(
      localRepository: local,
      cloudStore: cloud,
      userId: () => account.user?.id,
      canSync: () => account.capabilities.canSyncSettings,
    );
    final settings = SettingsController(repository, accountController: account);
    await settings.loadSettings();

    auth.emit(const AppUser(id: 'user-1'));
    entitlements.emit(
      const AppEntitlement(
        tier: AccountTier.premium,
        status: EntitlementStatus.active,
      ),
    );
    await pumpEventQueue();

    expect(settings.settings, cloudSettings);
    settings.dispose();
    account.dispose();
  });
}

class _MemorySettingsRepository implements SettingsRepository {
  _MemorySettingsRepository(this.value);

  AppSettings value;

  @override
  Future<AppSettings> load() async => value;

  @override
  Future<void> save(AppSettings settings) async => value = settings;
}

class _MemoryCloudSettingsStore implements CloudSettingsStore {
  AppSettings? value;
  bool throwOnLoad = false;
  bool throwOnSave = false;
  int loadCount = 0;
  int saveCount = 0;

  @override
  Future<AppSettings?> loadForUser(String userId) async {
    loadCount++;
    if (throwOnLoad) throw StateError('offline');
    return value;
  }

  @override
  Future<void> saveForUser(String userId, AppSettings settings) async {
    saveCount++;
    if (throwOnSave) throw StateError('offline');
    value = settings;
  }
}

class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _user;

  void emit(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  bool get isAvailable => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  @override
  Future<AppUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AppUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() async => emit(null);
}

class _FakeEntitlementsRepository implements EntitlementsRepository {
  final _controller = StreamController<AppEntitlement>.broadcast(sync: true);

  void emit(AppEntitlement entitlement) => _controller.add(entitlement);

  @override
  Stream<AppEntitlement> watchForUser(String userId) => _controller.stream;
}
