import 'package:flutter/foundation.dart';

class AppLog {
  AppLog._();

  static const bool _enabled = bool.fromEnvironment(
    'FLOW_LENS_LOGS',
    defaultValue: false,
  );

  static void debug(String message) {
    if (!kDebugMode && !_enabled) return;
    debugPrint('[flow-lens] $message');
  }
}
