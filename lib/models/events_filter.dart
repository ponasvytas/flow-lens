import 'game_event.dart';

class EventsFilter {
  final Set<String>? categoryIds;
  final Set<String>? eventTypeIds;
  final Set<EventGrade>? impacts;

  EventsFilter({
    this.categoryIds,
    this.eventTypeIds,
    this.impacts,
  });

  bool get isActive =>
      (categoryIds != null && categoryIds!.isNotEmpty) ||
      (eventTypeIds != null && eventTypeIds!.isNotEmpty) ||
      (impacts != null && impacts!.isNotEmpty);

  int get activeFilterCount {
    int count = 0;
    if (categoryIds != null && categoryIds!.isNotEmpty) count++;
    if (eventTypeIds != null && eventTypeIds!.isNotEmpty) count++;
    if (impacts != null && impacts!.isNotEmpty) count++;
    return count;
  }

  bool matches(GameEvent event) {
    if (categoryIds != null &&
        categoryIds!.isNotEmpty &&
        !categoryIds!.contains(event.categoryId)) {
      return false;
    }

    if (eventTypeIds != null && eventTypeIds!.isNotEmpty) {
      // Check if event matches by eventTypeId or by label/detail
      bool matchesEventType = false;
      
      if (event.eventTypeId != null) {
        matchesEventType = eventTypeIds!.contains(event.eventTypeId);
      } else {
        // For events without eventTypeId, check against label/detail
        final eventKey = event.detail ?? event.label;
        matchesEventType = eventTypeIds!.contains(eventKey);
      }
      
      if (!matchesEventType) {
        return false;
      }
    }

    if (impacts != null && impacts!.isNotEmpty) {
      if (event.grade == null || !impacts!.contains(event.grade)) {
        return false;
      }
    }

    return true;
  }

  EventsFilter copyWith({
    Set<String>? categoryIds,
    Set<String>? eventTypeIds,
    Set<EventGrade>? impacts,
    bool clearCategories = false,
    bool clearEventTypes = false,
    bool clearImpacts = false,
  }) {
    return EventsFilter(
      categoryIds: clearCategories ? null : (categoryIds ?? this.categoryIds),
      eventTypeIds:
          clearEventTypes ? null : (eventTypeIds ?? this.eventTypeIds),
      impacts: clearImpacts ? null : (impacts ?? this.impacts),
    );
  }

  EventsFilter clear() {
    return EventsFilter();
  }
}
