import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrackingSession hotkeySession({Map<String, String>? hotkeys}) =>
      TrackingSession(
        id: 'hotkeys',
        subjects: const [TrackingSubject(id: 's', label: 'Player')],
        trackers: const [
          TrackingDefinition(
            id: 'counter',
            label: 'Passes',
            kind: TrackerKind.counter,
          ),
          TrackingDefinition(
            id: 'timer',
            label: 'Possession',
            kind: TrackerKind.timer,
            timerMode: TimerMode.hold,
          ),
          TrackingDefinition(
            id: 'toggle',
            label: 'Shift',
            kind: TrackerKind.timer,
            timerMode: TimerMode.toggle,
          ),
        ],
        hotkeys: hotkeys,
      );

  test(
    'tracking rejects playback and duplicate keys without changing bindings',
    () {
      final controller = TrackingController(session: hotkeySession());
      addTearDown(controller.dispose);
      expect(controller.setHotkey('s', 'counter', 'J'), isTrue);
      expect(controller.getHotkey('s', 'counter'), 'j');
      for (final key in [
        'a',
        's',
        'd',
        'f',
        'm',
        ' ',
        'space',
        'arrow left',
        'arrow right',
        'p',
        'enter',
        'shift',
        'tab',
      ]) {
        expect(controller.setHotkey('s', 'counter', key), isFalse, reason: key);
        expect(controller.getHotkey('s', 'counter'), 'j');
        expect(controller.handleHotkeyDown(key, Duration.zero), isFalse);
      }
      expect(controller.setHotkey('s', 'timer', 'j'), isFalse);
      expect(controller.getHotkey('s', 'counter'), 'j');
      expect(controller.getHotkey('s', 'timer'), isNull);
      expect(
        controller.handleHotkeyDown('j', const Duration(seconds: 2)),
        isTrue,
      );
      expect(controller.getCounterValue('s', 'counter'), 1);
      expect(controller.events.single.timestamp, const Duration(seconds: 2));
    },
  );

  test(
    'saved playback conflicts cannot intercept playback and uppercase keys work',
    () {
      final controller = TrackingController(
        session: hotkeySession(hotkeys: {'s:counter': 'S', 's:timer': 'J'}),
      );
      addTearDown(controller.dispose);
      expect(controller.handleHotkeyDown('s', Duration.zero), isFalse);
      expect(controller.handleHotkeyUp('s', Duration.zero), isFalse);
      expect(controller.events, isEmpty);
      expect(
        controller.handleHotkeyDown('j', const Duration(seconds: 2)),
        isTrue,
      );
      expect(controller.isTimerRunning('s', 'timer'), isTrue);
      expect(
        controller.handleHotkeyUp('j', const Duration(seconds: 5)),
        isTrue,
      );
      expect(
        controller.getTimerDuration('s', 'timer'),
        const Duration(seconds: 3),
      );
      expect(controller.setHotkey('s', 'toggle', '1'), isTrue);
      controller.handleHotkeyDown('1', const Duration(seconds: 6));
      controller.handleHotkeyUp('1', const Duration(seconds: 7));
      expect(controller.isTimerRunning('s', 'toggle'), isTrue);
      controller.handleHotkeyDown('1', const Duration(seconds: 9));
      expect(
        controller.getTimerDuration('s', 'toggle'),
        const Duration(seconds: 3),
      );
    },
  );

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
