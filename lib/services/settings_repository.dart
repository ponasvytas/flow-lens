import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class SharedPreferencesSettingsRepository implements SettingsRepository {
  static const String _keySchemaVersion = 'settings_schemaVersion';
  static const String _keyFastPlaySpeed = 'settings_fastPlaySpeed';
  static const String _keySlowPlaybackSpeed = 'settings_slowPlaybackSpeed';
  static const String _keyDefaultPlaybackSpeed = 'settings_defaultPlaybackSpeed';
  static const String _keyLeadInSeconds = 'settings_leadInSeconds';
  static const String _keyLeadOutSeconds = 'settings_leadOutSeconds';

  @override
  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    final schemaVersion = prefs.getInt(_keySchemaVersion);
    final fastPlaySpeed = prefs.getDouble(_keyFastPlaySpeed);
    final slowPlaybackSpeed = prefs.getDouble(_keySlowPlaybackSpeed);
    final defaultPlaybackSpeed = prefs.getDouble(_keyDefaultPlaybackSpeed);
    final leadInSeconds = prefs.getInt(_keyLeadInSeconds);
    final leadOutSeconds = prefs.getInt(_keyLeadOutSeconds);

    if (schemaVersion == null) {
      return AppSettings.defaults();
    }

    return AppSettings(
      schemaVersion: schemaVersion,
      fastPlaySpeed: fastPlaySpeed ?? AppSettings.defaultFastPlaySpeed,
      slowPlaybackSpeed: slowPlaybackSpeed ?? AppSettings.defaultSlowPlaybackSpeed,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? AppSettings.defaultDefaultPlaybackSpeed,
      leadIn: Duration(seconds: leadInSeconds ?? AppSettings.defaultLeadIn.inSeconds),
      leadOut: Duration(seconds: leadOutSeconds ?? AppSettings.defaultLeadOut.inSeconds),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt(_keySchemaVersion, settings.schemaVersion);
    await prefs.setDouble(_keyFastPlaySpeed, settings.fastPlaySpeed);
    await prefs.setDouble(_keySlowPlaybackSpeed, settings.slowPlaybackSpeed);
    await prefs.setDouble(_keyDefaultPlaybackSpeed, settings.defaultPlaybackSpeed);
    await prefs.setInt(_keyLeadInSeconds, settings.leadIn.inSeconds);
    await prefs.setInt(_keyLeadOutSeconds, settings.leadOut.inSeconds);
  }
}
