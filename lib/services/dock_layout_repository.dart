import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/dock_layout_state.dart';

abstract class DockLayoutRepository {
  Future<DockLayoutState> load();
  Future<void> save(DockLayoutState state);
}

class SharedPreferencesDockLayoutRepository implements DockLayoutRepository {
  static const _key = 'dock_layout_v1';

  @override
  Future<DockLayoutState> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key);
    if (encoded == null) return const DockLayoutState();
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return const DockLayoutState();
      return DockLayoutState.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return const DockLayoutState();
    }
  }

  @override
  Future<void> save(DockLayoutState state) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key, jsonEncode(state.toJson()));
  }
}
