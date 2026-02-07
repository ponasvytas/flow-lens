import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  final SettingsRepository _repository;
  AppSettings _settings = AppSettings.defaults();

  SettingsController(this._repository);

  AppSettings get settings => _settings;

  Future<void> loadSettings() async {
    _settings = await _repository.load();
    notifyListeners();
  }

  Future<void> setFastPlaySpeed(double speed) async {
    if (speed < 1.5 || speed > 10.0) {
      throw ArgumentError('Fast play speed must be between 1.5 and 10.0');
    }
    _settings = _settings.copyWith(fastPlaySpeed: speed);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> setDefaultPlaybackSpeed(double speed) async {
    if (speed < 0.5 || speed > 3.0) {
      throw ArgumentError('Default playback speed must be between 0.5 and 3.0');
    }
    _settings = _settings.copyWith(defaultPlaybackSpeed: speed);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> setSlowPlaybackSpeed(double speed) async {
    if (speed < 0.25 || speed > 2.0) {
      throw ArgumentError('Slow playback speed must be between 0.25 and 2.0');
    }
    _settings = _settings.copyWith(slowPlaybackSpeed: speed);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> setLeadIn(Duration duration) async {
    if (duration.isNegative || duration.inSeconds > 30) {
      throw ArgumentError('Lead-in must be between 0 and 30 seconds');
    }
    _settings = _settings.copyWith(leadIn: duration);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> setLeadOut(Duration duration) async {
    if (duration.isNegative || duration.inSeconds > 30) {
      throw ArgumentError('Lead-out must be between 0 and 30 seconds');
    }
    _settings = _settings.copyWith(leadOut: duration);
    await _repository.save(_settings);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults();
    await _repository.save(_settings);
    notifyListeners();
  }
}
