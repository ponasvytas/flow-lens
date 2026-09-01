import '../models/app_settings.dart';
import 'cloud_settings_store.dart';
import 'settings_repository.dart';

abstract interface class SettingsSyncDiagnostics {
  String? get syncError;
}

/// Keeps local settings available while using Firestore as premium truth.
class HybridSettingsRepository
    implements SettingsRepository, SettingsSyncDiagnostics {
  HybridSettingsRepository({
    required SettingsRepository localRepository,
    required CloudSettingsStore cloudStore,
    required String? Function() userId,
    required bool Function() canSync,
  }) : _localRepository = localRepository,
       _cloudStore = cloudStore,
       _userId = userId,
       _canSync = canSync;

  final SettingsRepository _localRepository;
  final CloudSettingsStore _cloudStore;
  final String? Function() _userId;
  final bool Function() _canSync;

  String? _syncError;

  @override
  String? get syncError => _syncError;

  @override
  Future<AppSettings> load() async {
    final local = await _localRepository.load();
    final userId = _eligibleUserId();
    if (userId == null) {
      _syncError = null;
      return local;
    }

    try {
      final cloud = await _cloudStore.loadForUser(userId);
      if (cloud == null) {
        await _cloudStore.saveForUser(userId, local);
        _syncError = null;
        return local;
      }
      await _localRepository.save(cloud);
      _syncError = null;
      return cloud;
    } catch (_) {
      _syncError = 'Cloud settings are unavailable. Using local settings.';
      return local;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _localRepository.save(settings);
    final userId = _eligibleUserId();
    if (userId == null) {
      _syncError = null;
      return;
    }

    try {
      await _cloudStore.saveForUser(userId, settings);
      _syncError = null;
    } catch (_) {
      _syncError = 'Cloud settings could not sync. Changes are saved locally.';
    }
  }

  String? _eligibleUserId() {
    if (!_canSync()) return null;
    final userId = _userId();
    return userId == null || userId.isEmpty ? null : userId;
  }
}
