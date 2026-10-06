import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/tracking_template.dart';

abstract interface class TrackingTemplateRepository {
  Future<List<TrackingTemplate>> load();
  Future<void> save(List<TrackingTemplate> templates);
}

class LocalTrackingTemplateRepository implements TrackingTemplateRepository {
  static const storageKey = 'flow_lens.tracking_templates.v1';

  @override
  Future<List<TrackingTemplate>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return [];
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported template library.');
    }
    return (json['templates'] as List)
        .map(
          (item) =>
              TrackingTemplate.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  @override
  Future<void> save(List<TrackingTemplate> templates) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode({
        'schemaVersion': 1,
        'templates': templates.map((t) => t.toJson()).toList(),
      }),
    );
    if (!saved) throw StateError('Templates could not be saved.');
  }
}
