import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class QuickEventsRepository {
  Future<Map<String, dynamic>> load();
  Future<void> save(Map<String, dynamic> data);
}

class LocalQuickEventsRepository implements QuickEventsRepository {
  static const key = 'flow_lens.quick_events.v1';

  @override
  Future<Map<String, dynamic>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(key);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  @override
  Future<void> save(Map<String, dynamic> data) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      key,
      jsonEncode(data),
    );
    if (!saved) throw StateError('Quick menu could not be saved');
  }
}
