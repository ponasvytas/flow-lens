import 'package:flutter/foundation.dart';
import '../models/game_event.dart';
import '../models/events_filter.dart';
import '../utils/perf.dart';

class EventsController extends ChangeNotifier {
  List<GameEvent> _allEvents = [];
  GameEvent? _activeEvent;
  EventsFilter _filter = EventsFilter();

  // Cached filtered results — invalidated on data or filter change.
  List<GameEvent>? _filteredEventsCache;

  List<GameEvent> get allEvents => List.unmodifiable(_allEvents);
  GameEvent? get activeEvent => _activeEvent;
  EventsFilter get filter => _filter;

  List<GameEvent> get filteredEvents {
    if (!_filter.isActive) {
      return _allEvents;
    }
    if (_filteredEventsCache != null) return _filteredEventsCache!;
    _filteredEventsCache = Perf.time('filterEvents',
        () => _allEvents.where((event) => _filter.matches(event)).toList());
    return _filteredEventsCache!;
  }

  int get totalEventCount => _allEvents.length;
  int get filteredEventCount => filteredEvents.length;

  void _invalidateCache() {
    _filteredEventsCache = null;
  }

  void setEvents(List<GameEvent> events) {
    _allEvents = events;
    _invalidateCache();
    notifyListeners();
  }

  void addEvent(GameEvent event) {
    _allEvents.add(event);
    _invalidateCache();
    notifyListeners();
  }

  void updateEvent(GameEvent updatedEvent) {
    final index = _allEvents.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      _allEvents[index] = updatedEvent;
      if (_activeEvent?.id == updatedEvent.id) {
        _activeEvent = updatedEvent;
      }
      _invalidateCache();
      notifyListeners();
    }
  }

  void deleteEvent(GameEvent event) {
    _allEvents.removeWhere((e) => e.id == event.id);
    if (_activeEvent?.id == event.id) {
      _activeEvent = null;
    }
    _invalidateCache();
    notifyListeners();
  }

  void selectEvent(GameEvent? event) {
    _activeEvent = event;
    notifyListeners();
  }

  void setFilter(EventsFilter filter) {
    _filter = filter;
    _invalidateCache();
    notifyListeners();
  }

  void clearFilter() {
    _filter = EventsFilter();
    _invalidateCache();
    notifyListeners();
  }

  void clearEvents() {
    _allEvents.clear();
    _activeEvent = null;
    _invalidateCache();
    notifyListeners();
  }
}
