import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'export_models.dart';

/// Persists the last-used [ExportConfig] so export parameters (ease-in/out,
/// slow-mo settings, labels, format, etc.) survive across exports and app
/// restarts.
class ExportConfigStore {
  static const String _key = 'export_config_v1';

  /// Load the saved config, or return defaults if none is stored or the
  /// stored value is corrupt.
  static Future<ExportConfig> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const ExportConfig();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ExportConfig.fromJson(json);
    } catch (_) {
      return const ExportConfig();
    }
  }

  /// Persist the given config.
  static Future<void> save(ExportConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }
}
