import 'package:flutter/foundation.dart';
import '../models/game_event.dart';
import '../models/events_filter.dart';

class EventsController extends ChangeNotifier {
  List<GameEvent> _allEvents = [];
  GameEvent? _activeEvent;
  EventsFilter _filter = EventsFilter();

  List<GameEvent> get allEvents => List.unmodifiable(_allEvents);
  GameEvent? get activeEvent => _activeEvent;
  EventsFilter get filter => _filter;

  List<GameEvent> get filteredEvents {
    if (!_filter.isActive) {
      return _allEvents;
    }

    return _allEvents.where((event) => _filter.matches(event)).toList();
  }

  int get totalEventCount => _allEvents.length;
  int get filteredEventCount => filteredEvents.length;

  void setEvents(List<GameEvent> events) {
    _allEvents = events;
    notifyListeners();
  }

  void addEvent(GameEvent event) {
    _allEvents.add(event);
    notifyListeners();
  }

  void updateEvent(GameEvent updatedEvent) {
    final index = _allEvents.indexWhere((e) => e.id == updatedEvent.id);
    if (index != -1) {
      _allEvents[index] = updatedEvent;
      if (_activeEvent?.id == updatedEvent.id) {
        _activeEvent = updatedEvent;
      }
      notifyListeners();
    }
  }

  void deleteEvent(GameEvent event) {
    _allEvents.removeWhere((e) => e.id == event.id);
    if (_activeEvent?.id == event.id) {
      _activeEvent = null;
    }
    notifyListeners();
  }

  void selectEvent(GameEvent? event) {
    _activeEvent = event;
    notifyListeners();
  }

  void setFilter(EventsFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearFilter() {
    _filter = EventsFilter();
    notifyListeners();
  }

  void clearEvents() {
    _allEvents.clear();
    _activeEvent = null;
    notifyListeners();
  }
}
