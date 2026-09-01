import 'package:flow_lens/controllers/events_controller.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flutter_test/flutter_test.dart';

GameEvent event(String id, int seconds) => GameEvent(
  id: id,
  timestamp: Duration(seconds: seconds),
  label: id,
  categoryId: 'shot',
);

void main() {
  test('collection views are stable and chronology ignores selection', () {
    final controller = EventsController();
    controller.setEvents([event('late', 20), event('early', 10)]);

    expect(identical(controller.allEvents, controller.allEvents), isTrue);
    final chronological = controller.chronologicalFilteredEvents;
    expect(chronological.map((item) => item.id), ['early', 'late']);

    controller.toggleSelection('early');
    expect(
      identical(chronological, controller.chronologicalFilteredEvents),
      isTrue,
    );
  });

  test('upsert and batch deletion notify once', () {
    final controller = EventsController();
    controller.setEvents([event('a', 1), event('b', 2), event('c', 3)]);
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.upsertEvent(event('b', 9));
    expect(
      controller.allEvents.singleWhere((item) => item.id == 'b').timestamp,
      const Duration(seconds: 9),
    );

    notifications = 0;
    expect(controller.deleteEventsById({'a', 'c'}), 2);
    expect(notifications, 1);
    expect(controller.allEvents.map((item) => item.id), ['b']);
  });
}
