import 'package:flutter/foundation.dart';
import '../models/quick_event.dart';
import '../models/sport_taxonomy.dart';
import '../models/game_event.dart';
import '../services/quick_events_repository.dart';

class QuickEventsController extends ChangeNotifier {
  QuickEventsController(this.repository);
  final QuickEventsRepository repository;
  final Map<String, List<QuickEvent>> _menus = {};
  final List<QuickEventPreset> _presets = [];
  String? _gameKey;
  String? _sportId;
  SportTaxonomy? _taxonomy;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool ready = false;
  String? error;
  int _sequence = 0;

  List<QuickEvent> get items => List.unmodifiable(_menus[_gameKey] ?? const []);
  List<QuickEventPreset> get presets =>
      List.unmodifiable(_presets.where((p) => p.sportId == _sportId));

  Future<void> load() async {
    try {
      final data = await repository.load();
      final menus = data['menus'] as Map? ?? {};
      final parsed = <String, List<QuickEvent>>{};
      for (final entry in menus.entries) {
        parsed[entry.key as String] = (entry.value as List)
            .map(
              (e) => QuickEvent.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
      }
      final presets = (data['presets'] as List? ?? [])
          .map(
            (e) =>
                QuickEventPreset.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      _menus.addAll(parsed);
      _presets.addAll(presets);
      ready = true;
      error = null;
    } catch (_) {
      error = 'Could not load quick menus. Retry before editing.';
    }
    _notify();
  }

  void selectGame(String identity, SportTaxonomy taxonomy) {
    _sportId = taxonomy.sportId;
    _taxonomy = taxonomy;
    _gameKey = '${taxonomy.sportId}:$identity';
    _menus.putIfAbsent(_gameKey!, () => []);
    _notify();
  }

  List<QuickEventPreset> get suggestedPresets {
    final taxonomy = _taxonomy;
    if (taxonomy == null) return [];
    return taxonomy.quickPresets
        .map(
          (preset) => QuickEventPreset(
            id: 'suggested:${preset.name}',
            sportId: taxonomy.sportId,
            name: preset.name,
            items: preset.eventTypeIds.map((id) {
              final category = taxonomy.categoryForType(id)!;
              final type = category.getEventTypeById(id)!;
              return QuickEvent(
                categoryId: category.categoryId,
                eventTypeId: id,
                grade: type.defaultImpact,
                slotId: 'suggested:${preset.name}:$id',
                taxonomyRevision: taxonomy.revision,
                categoryLabel: category.name,
                eventLabel: type.name,
                definition: type.definition,
                context: type.contextDefaults,
              );
            }),
          ),
        )
        .toList();
  }

  void add(QuickEvent item) {
    if (!ready || _gameKey == null || items.any((e) => e.id == item.id)) return;
    _replace([...items, item]);
  }

  void remove(String id) => _replace(items.where((e) => e.id != id));

  void move(int from, int to) {
    if (from < 0 ||
        from >= items.length ||
        to < 0 ||
        to >= items.length ||
        from == to) {
      return;
    }
    final next = items.toList();
    next.insert(to, next.removeAt(from));
    _replace(next);
  }

  // Bare keys only; reserved keys belong to playback or staged event entry.
  static const reservedKeys = {'a', 's', 'd', 'f', 'm', 'p', 'g', 'c'};
  String? hotkeyError(String key, String itemId) {
    if (key.isEmpty) return null;
    if (!RegExp(r'^[a-z]$').hasMatch(key)) return 'Choose a single letter.';
    if (reservedKeys.contains(key)) {
      return 'This key is used by an existing shortcut.';
    }
    if (items.any((e) => e.id != itemId && e.hotkey == key)) {
      return 'This key is already assigned in this menu.';
    }
    return null;
  }

  bool update(QuickEvent item) {
    if (hotkeyError(item.hotkey ?? '', item.id) != null) return false;
    _replace(items.map((e) => e.id == item.id ? item : e));
    return true;
  }

  void applyPreset(QuickEventPreset preset) {
    if (preset.sportId == _sportId) _replace(preset.items);
  }

  void savePreset(String name, {String? replaceId}) {
    if (!ready || _sportId == null || name.trim().isEmpty) return;
    final preset = QuickEventPreset(
      id:
          replaceId ??
          '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      sportId: _sportId!,
      name: name.trim(),
      items: items,
    );
    _presets.removeWhere((p) => p.id == preset.id);
    _presets.add(preset);
    _persist();
  }

  void renamePreset(QuickEventPreset preset, String name) {
    if (name.trim().isEmpty) return;
    final index = _presets.indexWhere((p) => p.id == preset.id);
    if (index < 0) return;
    _presets[index] = QuickEventPreset(
      id: preset.id,
      sportId: preset.sportId,
      name: name.trim(),
      items: preset.items,
    );
    _persist();
  }

  void deletePreset(String id) {
    _presets.removeWhere((p) => p.id == id);
    _persist();
  }

  void duplicatePreset(QuickEventPreset preset, String name) {
    if (name.trim().isEmpty) return;
    _presets.add(
      QuickEventPreset(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
        sportId: preset.sportId,
        name: name.trim(),
        items: preset.items,
      ),
    );
    _persist();
  }

  void restoreItems(Iterable<QuickEvent> values) => _replace(values);

  GameEvent? createEvent(
    QuickEvent item,
    SportTaxonomy taxonomy,
    Duration timestamp,
  ) {
    final category = taxonomy.getCategoryById(item.categoryId);
    final type = category?.eventTypes
        .where((t) => t.eventTypeId == item.eventTypeId)
        .firstOrNull;
    if (category == null || type == null) return null;
    return GameEvent(
      id: '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      sportId: taxonomy.sportId,
      timestamp: timestamp,
      categoryId: category.categoryId,
      eventTypeId: type.eventTypeId,
      label: item.categoryLabel ?? category.name,
      detail: item.eventLabel ?? type.name,
      taxonomyRevision: item.taxonomyRevision ?? taxonomy.revision,
      definition: item.definition ?? type.definition,
      context: {...type.contextDefaults, ...item.context},
      grade: item.grade,
    );
  }

  void _replace(Iterable<QuickEvent> next) {
    if (!ready || _gameKey == null) return;
    _menus[_gameKey!] = List.of(next);
    _persist();
  }

  void retrySave() => _persist();

  void _persist() {
    final snapshot = <String, dynamic>{
      'version': 2,
      'menus': _menus.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      ),
      'presets': _presets.map((p) => p.toJson()).toList(),
    };
    _writes = _writes.then((_) async {
      try {
        await repository.save(snapshot);
        error = null;
      } catch (_) {
        error = 'Quick menu changes are not saved. Retry.';
      }
      _notify();
    });
    _notify();
  }

  Future<void> get flushed => _writes;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
