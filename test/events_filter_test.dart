import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_analyzer/models/game_event.dart';
import 'package:flutter_video_analyzer/models/events_filter.dart';

void main() {
  group('EventsFilter', () {
    late GameEvent shotGoalEvent;
    late GameEvent passTurnoverEvent;
    late GameEvent battleWonEvent;

    setUp(() {
      shotGoalEvent = GameEvent(
        id: '1',
        timestamp: const Duration(seconds: 10),
        grade: EventGrade.positive,
        label: 'Shot',
        categoryId: 'shot',
        eventTypeId: 'shot_goal',
      );

      passTurnoverEvent = GameEvent(
        id: '2',
        timestamp: const Duration(seconds: 20),
        grade: EventGrade.negative,
        label: 'Pass',
        categoryId: 'pass',
        eventTypeId: 'pass_turnover',
      );

      battleWonEvent = GameEvent(
        id: '3',
        timestamp: const Duration(seconds: 30),
        grade: EventGrade.positive,
        label: 'Battle',
        categoryId: 'battle',
        eventTypeId: 'battle_won',
      );
    });

    test('empty filter matches all events', () {
      final filter = EventsFilter();

      expect(filter.isActive, false);
      expect(filter.matches(shotGoalEvent), true);
      expect(filter.matches(passTurnoverEvent), true);
      expect(filter.matches(battleWonEvent), true);
    });

    test('filters by category', () {
      final filter = EventsFilter(categoryIds: {'shot', 'battle'});

      expect(filter.isActive, true);
      expect(filter.matches(shotGoalEvent), true);
      expect(filter.matches(passTurnoverEvent), false);
      expect(filter.matches(battleWonEvent), true);
    });

    test('filters by event type', () {
      final filter = EventsFilter(eventTypeIds: {'shot_goal', 'battle_won'});

      expect(filter.matches(shotGoalEvent), true);
      expect(filter.matches(passTurnoverEvent), false);
      expect(filter.matches(battleWonEvent), true);
    });

    test('filters by impact', () {
      final filter = EventsFilter(impacts: {EventGrade.positive});

      expect(filter.matches(shotGoalEvent), true);
      expect(filter.matches(passTurnoverEvent), false);
      expect(filter.matches(battleWonEvent), true);
    });

    test('combines multiple filters (AND logic)', () {
      final filter = EventsFilter(
        categoryIds: {'shot', 'battle'},
        impacts: {EventGrade.positive},
      );

      expect(filter.matches(shotGoalEvent), true);
      expect(filter.matches(passTurnoverEvent), false);
      expect(filter.matches(battleWonEvent), true);
    });

    test('counts active filters', () {
      final noFilters = EventsFilter();
      expect(noFilters.activeFilterCount, 0);

      final oneFilter = EventsFilter(categoryIds: {'shot'});
      expect(oneFilter.activeFilterCount, 1);

      final twoFilters = EventsFilter(
        categoryIds: {'shot'},
        impacts: {EventGrade.positive},
      );
      expect(twoFilters.activeFilterCount, 2);

      final threeFilters = EventsFilter(
        categoryIds: {'shot'},
        eventTypeIds: {'shot_goal'},
        impacts: {EventGrade.positive},
      );
      expect(threeFilters.activeFilterCount, 3);
    });

    test('copyWith updates filters', () {
      final original = EventsFilter(categoryIds: {'shot'});
      final updated = original.copyWith(impacts: {EventGrade.positive});

      expect(updated.categoryIds, {'shot'});
      expect(updated.impacts, {EventGrade.positive});
    });

    test('copyWith can clear filters', () {
      final original = EventsFilter(
        categoryIds: {'shot'},
        impacts: {EventGrade.positive},
      );
      final cleared = original.copyWith(clearCategories: true);

      expect(cleared.categoryIds, null);
      expect(cleared.impacts, {EventGrade.positive});
    });

    test('clear removes all filters', () {
      final filtered = EventsFilter(
        categoryIds: {'shot'},
        eventTypeIds: {'shot_goal'},
        impacts: {EventGrade.positive},
      );
      final cleared = filtered.clear();

      expect(cleared.isActive, false);
      expect(cleared.categoryIds, null);
      expect(cleared.eventTypeIds, null);
      expect(cleared.impacts, null);
    });
  });
}
