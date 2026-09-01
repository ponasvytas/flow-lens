import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/events_filter.dart';
import '../models/game_event.dart';
import '../utils/perf.dart';

class EventsController extends ChangeNotifier {
  final List<GameEvent> _allEvents = <GameEvent>[];
  final Map<String, int> _eventIndices = <String, int>{};
  final Set<String> _selectedEventIds = <String>{};
  late final UnmodifiableListView<GameEvent> _allEventsView =
      UnmodifiableListView<GameEvent>(_allEvents);
  late final UnmodifiableSetView<String> _selectionView =
      UnmodifiableSetView<String>(_selectedEventIds);

  GameEvent? _activeEvent;
  EventsFilter _filter = EventsFilter();
  UnmodifiableListView<GameEvent>? _filteredEventsCache;
  UnmodifiableListView<GameEvent>? _chronologicalCache;

  final ValueNotifier<int> dataRevision = ValueNotifier<int>(0);
  final ValueNotifier<int> selectionRevision = ValueNotifier<int>(0);

  UnmodifiableListView<GameEvent> get allEvents => _allEventsView;
  UnmodifiableSetView<String> get selectedEventIds => _selectionView;
  GameEvent? get activeEvent => _activeEvent;
  EventsFilter get filter => _filter;

  UnmodifiableListView<GameEvent> get filteredEvents {
    return _filteredEventsCache ??= UnmodifiableListView<GameEvent>(
      _filter.isActive
          ? Perf.time(
              'filterEvents',
              () => _allEvents.where(_filter.matches).toList(),
            )
          : _allEvents,
    );
  }

  /// Filtered events sorted by timestamp. The same view is returned until
  /// event data or the filter changes; selection does not invalidate it.
  UnmodifiableListView<GameEvent> get chronologicalFilteredEvents {
    return _chronologicalCache ??= UnmodifiableListView<GameEvent>(
      Perf.time(
        'sortChronologicalEvents',
        () =>
            filteredEvents.toList()
              ..sort((a, b) => a.timestamp.compareTo(b.timestamp)),
      ),
    );
  }

  int get totalEventCount => _allEvents.length;
  int get filteredEventCount => filteredEvents.length;
  bool containsEvent(String eventId) => _eventIndices.containsKey(eventId);
  bool isSelected(String eventId) => _selectedEventIds.contains(eventId);

  void _dataChanged() {
    _filteredEventsCache = null;
    _chronologicalCache = null;
    dataRevision.value++;
    notifyListeners();
  }

  void _selectionChanged() {
    selectionRevision.value++;
    notifyListeners();
  }

  void setEvents(Iterable<GameEvent> events) {
    _allEvents
      ..clear()
      ..addAll(events);
    _rebuildEventIndices();
    _selectedEventIds.removeWhere((id) => !_eventIndices.containsKey(id));
    _dataChanged();
  }

  void addEvent(GameEvent event) {
    if (containsEvent(event.id)) {
      upsertEvent(event);
      return;
    }
    _eventIndices[event.id] = _allEvents.length;
    _allEvents.add(event);
    _dataChanged();
  }

  void upsertEvent(GameEvent event) {
    final index = _eventIndices[event.id];
    if (index == null) {
      _eventIndices[event.id] = _allEvents.length;
      _allEvents.add(event);
    } else {
      _allEvents[index] = event;
    }
    if (_activeEvent?.id == event.id) _activeEvent = event;
    _dataChanged();
  }

  void updateEvent(GameEvent event) {
    if (!containsEvent(event.id)) return;
    upsertEvent(event);
  }

  void deleteEvent(GameEvent event) => deleteEventsById(<String>{event.id});

  /// Deletes all IDs in one pass and emits at most one controller notification.
  int deleteEventsById(Iterable<String> eventIds) {
    final ids = eventIds is Set<String> ? eventIds : eventIds.toSet();
    if (ids.isEmpty) return 0;
    final before = _allEvents.length;
    _allEvents.removeWhere((event) => ids.contains(event.id));
    final removed = before - _allEvents.length;
    if (removed == 0) return 0;
    _rebuildEventIndices();
    if (_activeEvent != null && ids.contains(_activeEvent!.id)) {
      _activeEvent = null;
    }
    _selectedEventIds.removeAll(ids);
    selectionRevision.value++;
    _dataChanged();
    return removed;
  }

  void selectEvent(GameEvent? event) {
    if (_activeEvent == event) return;
    _activeEvent = event;
    notifyListeners();
  }

  void toggleSelection(String eventId) {
    if (!_selectedEventIds.add(eventId)) _selectedEventIds.remove(eventId);
    _selectionChanged();
  }

  void setSelection(Iterable<String> eventIds) {
    final next = eventIds.toSet();
    if (setEquals(next, _selectedEventIds)) return;
    _selectedEventIds
      ..clear()
      ..addAll(next);
    _selectionChanged();
  }

  void clearSelection() {
    if (_selectedEventIds.isEmpty) return;
    _selectedEventIds.clear();
    _selectionChanged();
  }

  void setFilter(EventsFilter filter) {
    _filter = filter;
    _filteredEventsCache = null;
    _chronologicalCache = null;
    dataRevision.value++;
    notifyListeners();
  }

  void clearFilter() => setFilter(EventsFilter());

  void clearEvents() {
    if (_allEvents.isEmpty && _selectedEventIds.isEmpty) return;
    _allEvents.clear();
    _eventIndices.clear();
    _activeEvent = null;
    _selectedEventIds.clear();
    selectionRevision.value++;
    _dataChanged();
  }

  @override
  void dispose() {
    dataRevision.dispose();
    selectionRevision.dispose();
    super.dispose();
  }

  void _rebuildEventIndices() {
    _eventIndices.clear();
    for (var index = 0; index < _allEvents.length; index++) {
      _eventIndices[_allEvents[index].id] = index;
    }
  }
}
