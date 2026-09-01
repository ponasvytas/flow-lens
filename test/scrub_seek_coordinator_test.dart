import 'dart:async';

import 'package:flow_lens/controllers/scrub_seek_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scrub seeks exactly once on completion and resumes playback', () async {
    final seeks = <Duration>[];
    var pauses = 0;
    var plays = 0;
    final coordinator = ScrubSeekCoordinator(
      seek: (position) async => seeks.add(position),
      pause: () async => pauses++,
      play: () async => plays++,
      isPlaying: () => true,
    );

    coordinator.begin();
    expect(seeks, isEmpty);
    await coordinator.complete(const Duration(seconds: 12));
    expect(seeks, [const Duration(seconds: 12)]);
    expect(pauses, 1);
    expect(plays, 1);
  });

  test('stale seek completion cannot resume playback', () async {
    final firstSeek = Completer<void>();
    var seekCount = 0;
    var plays = 0;
    final coordinator = ScrubSeekCoordinator(
      seek: (_) {
        seekCount++;
        return firstSeek.future;
      },
      pause: () async {},
      play: () async => plays++,
      isPlaying: () => true,
    );

    coordinator.begin();
    final completion = coordinator.complete(Duration.zero);
    coordinator.begin();
    firstSeek.complete();
    expect(await completion, isFalse);
    expect(seekCount, 1);
    expect(plays, 0);
  });
}
