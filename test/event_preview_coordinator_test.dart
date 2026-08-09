import 'dart:async';

import 'package:flow_lens/controllers/event_preview_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clamps preview boundaries and pauses from video position', () async {
    final seeks = <Duration>[];
    var plays = 0;
    var pauses = 0;
    final coordinator = EventPreviewCoordinator(
      seek: (position) async => seeks.add(position),
      play: () async => plays++,
      pause: () async => pauses++,
      duration: () => const Duration(seconds: 20),
    );

    await coordinator.preview(
      eventTimestamp: const Duration(seconds: 2),
      leadIn: const Duration(seconds: 5),
      leadOut: const Duration(seconds: 30),
    );
    expect(seeks, [Duration.zero]);
    expect(coordinator.pauseAt, const Duration(seconds: 20));
    expect(plays, 1);

    coordinator.onPosition(const Duration(seconds: 19));
    expect(pauses, 0);
    coordinator.onPosition(const Duration(seconds: 20));
    await Future<void>.delayed(Duration.zero);
    expect(pauses, 1);
  });

  test('cancel ignores a stale seek completion', () async {
    final seekCompletion = Completer<void>();
    var plays = 0;
    final coordinator = EventPreviewCoordinator(
      seek: (_) => seekCompletion.future,
      play: () async => plays++,
      pause: () async {},
      duration: () => const Duration(minutes: 1),
    );

    final preview = coordinator.preview(
      eventTimestamp: const Duration(seconds: 10),
      leadIn: const Duration(seconds: 2),
      leadOut: const Duration(seconds: 2),
    );
    coordinator.cancel();
    seekCompletion.complete();
    await preview;
    expect(plays, 0);
    expect(coordinator.isActive, isFalse);
  });

  test('zero-duration videos do not play', () async {
    var plays = 0;
    var pauses = 0;
    final coordinator = EventPreviewCoordinator(
      seek: (_) async {},
      play: () async => plays++,
      pause: () async => pauses++,
      duration: () => Duration.zero,
    );
    await coordinator.preview(
      eventTimestamp: Duration.zero,
      leadIn: Duration.zero,
      leadOut: Duration.zero,
    );
    expect(plays, 0);
    expect(pauses, 1);
  });
}
