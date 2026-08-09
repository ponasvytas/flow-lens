import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads aggregate indexes and derives collision-free event IDs', () {
    final session = TrackingSession(
      id: 'session',
      events: const [
        TrackingEvent(
          id: 'te_2',
          timestamp: Duration(seconds: 1),
          subjectId: 's',
          trackerId: 'counter',
          action: TrackingAction.increment,
          delta: 3,
        ),
        TrackingEvent(
          id: 'te_9',
          timestamp: Duration(seconds: 2),
          subjectId: 's',
          trackerId: 'timer',
          action: TrackingAction.timerStart,
        ),
        TrackingEvent(
          id: 'te_4',
          timestamp: Duration(seconds: 7),
          subjectId: 's',
          trackerId: 'timer',
          action: TrackingAction.timerStop,
        ),
      ],
    );
    final controller = TrackingController(session: session);

    expect(controller.getCounterValue('s', 'counter'), 3);
    expect(
      controller.getTimerDuration('s', 'timer'),
      const Duration(seconds: 5),
    );
    final created = controller.incrementCounter(
      subjectId: 's',
      trackerId: 'counter',
      timestamp: const Duration(seconds: 8),
    );
    expect(created.id, 'te_10');
    expect(controller.getCounterValue('s', 'counter'), 4);
  });

  test('timer stop and undo rebuild scoped stats', () {
    final controller = TrackingController();
    controller.startTimer(
      subjectId: 's',
      trackerId: 't',
      timestamp: const Duration(seconds: 2),
    );
    controller.stopTimer(
      subjectId: 's',
      trackerId: 't',
      timestamp: const Duration(seconds: 8),
    );
    expect(controller.getTimerDuration('s', 't'), const Duration(seconds: 6));

    controller.undoLastEvent();
    expect(controller.getTimerDuration('s', 't'), Duration.zero);
    expect(controller.isTimerRunning('s', 't'), isTrue);
  });
}
