import 'game_event.dart';

class EventsFilter {
  final Set<String>? categoryIds;
  final Set<String>? eventTypeIds;
  final Set<EventGrade>? impacts;
  final bool includeUngraded;
  final Map<String, String> contextValues;

  EventsFilter({
    Set<String>? categoryIds,
    Set<String>? eventTypeIds,
    Set<EventGrade>? impacts,
    this.includeUngraded = false,
    Map<String, String> contextValues = const {},
  }) : categoryIds = categoryIds == null ? null : Set.unmodifiable(categoryIds),
       eventTypeIds = eventTypeIds == null
           ? null
           : Set.unmodifiable(eventTypeIds),
       impacts = impacts == null ? null : Set.unmodifiable(impacts),
       contextValues = Map.unmodifiable(contextValues);

  bool get isActive =>
      (categoryIds != null && categoryIds!.isNotEmpty) ||
      (eventTypeIds != null && eventTypeIds!.isNotEmpty) ||
      (impacts != null && impacts!.isNotEmpty) ||
      includeUngraded ||
      contextValues.isNotEmpty;

  int get activeFilterCount {
    int count = 0;
    if (categoryIds != null && categoryIds!.isNotEmpty) count++;
    if (eventTypeIds != null && eventTypeIds!.isNotEmpty) count++;
    if ((impacts != null && impacts!.isNotEmpty) || includeUngraded) count++;
    count += contextValues.length;
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

    if ((impacts != null && impacts!.isNotEmpty) || includeUngraded) {
      if (event.grade == null
          ? !includeUngraded
          : !(impacts?.contains(event.grade) ?? false)) {
        return false;
      }
    }
    for (final entry in contextValues.entries) {
      if (event.context[entry.key] != entry.value) return false;
    }
    return true;
  }

  EventsFilter copyWith({
    Set<String>? categoryIds,
    Set<String>? eventTypeIds,
    Set<EventGrade>? impacts,
    bool? includeUngraded,
    Map<String, String>? contextValues,
    bool clearCategories = false,
    bool clearEventTypes = false,
    bool clearImpacts = false,
  }) {
    return EventsFilter(
      categoryIds: clearCategories ? null : (categoryIds ?? this.categoryIds),
      eventTypeIds: clearEventTypes
          ? null
          : (eventTypeIds ?? this.eventTypeIds),
      impacts: clearImpacts ? null : (impacts ?? this.impacts),
      includeUngraded: clearImpacts
          ? false
          : (includeUngraded ?? this.includeUngraded),
      contextValues: contextValues ?? this.contextValues,
    );
  }

  EventsFilter clear() {
    return EventsFilter();
  }
}
