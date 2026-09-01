import 'dart:async';

import 'package:flutter/foundation.dart';
import 'account_controller.dart';
import '../models/app_settings.dart';
import '../services/hybrid_settings_repository.dart';
import '../services/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository _repository;
  final AccountController? _accountController;
  AppSettings _settings = AppSettings.defaults();
  int _loadGeneration = 0;
  String? _accountKey;

  SettingsController(this._repository, {AccountController? accountController})
    : _accountController = accountController {
    _accountKey = _currentAccountKey;
    _accountController?.addListener(_onAccountChanged);
  }

  AppSettings get settings => _settings;
  String? get syncError => switch (_repository) {
    SettingsSyncDiagnostics diagnostics => diagnostics.syncError,
    _ => null,
  };

  Future<void> loadSettings() => _reloadSettings();

  Future<void> _reloadSettings() async {
    final generation = ++_loadGeneration;
    final settings = await _repository.load();
    if (generation != _loadGeneration) return;
    _settings = settings;
    notifyListeners();
  }

  Future<void> setFastPlaySpeed(double speed) async {
    if (speed < 1.5 || speed > 10.0) {
      throw ArgumentError('Fast play speed must be between 1.5 and 10.0');
    }
    await _saveSettings(_settings.copyWith(fastPlaySpeed: speed));
  }

  Future<void> setDefaultPlaybackSpeed(double speed) async {
    if (speed < 0.5 || speed > 3.0) {
      throw ArgumentError('Default playback speed must be between 0.5 and 3.0');
    }
    await _saveSettings(_settings.copyWith(defaultPlaybackSpeed: speed));
  }

  Future<void> setSlowPlaybackSpeed(double speed) async {
    if (speed < 0.25 || speed > 2.0) {
      throw ArgumentError('Slow playback speed must be between 0.25 and 2.0');
    }
    await _saveSettings(_settings.copyWith(slowPlaybackSpeed: speed));
  }

  Future<void> setLeadIn(Duration duration) async {
    if (duration.isNegative || duration.inSeconds > 30) {
      throw ArgumentError('Lead-in must be between 0 and 30 seconds');
    }
    await _saveSettings(_settings.copyWith(leadIn: duration));
  }

  Future<void> setLeadOut(Duration duration) async {
    if (duration.isNegative || duration.inSeconds > 30) {
      throw ArgumentError('Lead-out must be between 0 and 30 seconds');
    }
    await _saveSettings(_settings.copyWith(leadOut: duration));
  }

  Future<void> resetToDefaults() async {
    await _saveSettings(AppSettings.defaults());
  }

  Future<void> _saveSettings(AppSettings settings) async {
    _loadGeneration++;
    _settings = settings;
    await _repository.save(settings);
    notifyListeners();
  }

  String get _currentAccountKey {
    final account = _accountController;
    if (account == null || !account.capabilities.canSyncSettings) {
      return 'local';
    }
    return 'premium:${account.user?.id ?? ''}';
  }

  void _onAccountChanged() {
    final nextKey = _currentAccountKey;
    if (_accountKey == nextKey) return;
    _accountKey = nextKey;
    unawaited(_reloadSettings());
  }

  @override
  void dispose() {
    _accountController?.removeListener(_onAccountChanged);
    super.dispose();
  }
}
