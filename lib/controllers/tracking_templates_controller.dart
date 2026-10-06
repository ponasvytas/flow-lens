import 'package:flutter/foundation.dart';
import '../models/tracking_template.dart';
import '../services/tracking_template_repository.dart';

class TrackingTemplatesController extends ChangeNotifier {
  TrackingTemplatesController(this.repository);
  final TrackingTemplateRepository repository;
  List<TrackingTemplate> _templates = [];
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool ready = false;
  String? error;
  int _sequence = 0;

  List<TrackingTemplate> forSport(String sportId) =>
      List.unmodifiable(_templates.where((t) => t.sportId == sportId));
  Future<void> get flushed => _writes;

  Future<void> load() async {
    if (ready) return;
    try {
      final loaded = await repository.load();
      if (loaded.map((t) => t.id).toSet().length != loaded.length) {
        throw const FormatException('Duplicate saved template IDs.');
      }
      _templates = loaded;
      ready = true;
      error = null;
    } catch (_) {
      error =
          'Could not load saved templates. Retry before editing your library.';
    }
    _notify();
  }

  TrackingTemplate saveCopy(TrackingTemplate template, String name) {
    _requireReady();
    final copy = template.copyWith(
      id: 'local:${DateTime.now().microsecondsSinceEpoch}:${_sequence++}',
      revision: 1,
      name: name.trim(),
      sourceTemplateId: template.id,
    );
    _templates = [..._templates, copy];
    _persist();
    return copy;
  }

  void rename(TrackingTemplate template, String name) {
    _requireReady();
    final updated = template.copyWith(
      name: name.trim(),
      revision: template.revision + 1,
    );
    _templates = _templates
        .map((t) => t.id == template.id ? updated : t)
        .toList();
    _persist();
  }

  void delete(String id) {
    _requireReady();
    _templates = _templates.where((t) => t.id != id).toList();
    _persist();
  }

  void retrySave() {
    _requireReady();
    _persist();
  }

  void _requireReady() {
    if (!ready) {
      throw StateError('Load the template library before editing it.');
    }
  }

  void _persist() {
    final snapshot = List<TrackingTemplate>.of(_templates);
    _writes = _writes.then((_) async {
      try {
        await repository.save(snapshot);
        error = null;
      } catch (_) {
        error = 'Template changes are not saved. Retry or export a copy.';
      }
      _notify();
    });
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
