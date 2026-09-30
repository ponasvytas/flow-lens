import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'package:flow_lens/widgets/player_tracking_panel.dart';
import 'package:media_kit/media_kit.dart';

class _FakePlayer extends Fake implements Player {
  @override
  final PlayerState state = _FakePlayerState();

  @override
  final PlayerStream stream = _FakePlayerStream();
}

class _FakePlayerState extends Fake implements PlayerState {
  @override
  Duration get position => Duration.zero;
}

class _FakePlayerStream extends Fake implements PlayerStream {
  @override
  Stream<Duration> get position => const Stream.empty();
}

void main() {
  testWidgets('tracking controls fit narrow and wide panels at large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final player = _FakePlayer();
    final controller = TrackingController(
      session: TrackingSession(
        id: 'layout',
        subjects: [const TrackingSubject(id: 'p', label: 'Alex', number: '12')],
        trackers: [
          const TrackingDefinition(
            id: 'passes',
            label: 'Completed passes',
            kind: TrackerKind.counter,
          ),
          const TrackingDefinition(
            id: 'time',
            label: 'Time on ice',
            kind: TrackerKind.timer,
            timerMode: TimerMode.toggle,
          ),
        ],
      ),
    );
    addTearDown(controller.dispose);
    var width = 112.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: width,
                height: 900,
                child: SingleChildScrollView(
                  child: PlayerTrackingPanel(
                    controller: controller,
                    player: player,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    for (final nextWidth in [112.0, 220.0, 420.0]) {
      update(() => width = nextWidth);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Width: $nextWidth');
      expect(find.byTooltip('Add Completed passes for Alex'), findsOneWidget);
      expect(find.byTooltip('Remove Alex'), findsOneWidget);
    }
    await tester.tap(find.byTooltip('Add Completed passes for Alex'));
    await tester.pumpAndSettle();
    expect(find.text('1 tracking event'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last tracking event'));
    await tester.pumpAndSettle();
    expect(find.text('0 tracking events'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove Alex'));
    await tester.pumpAndSettle();
    expect(controller.subjects, hasLength(1));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.subjects, hasLength(1));
    await tester.tap(find.byTooltip('Remove Alex'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(controller.subjects, isEmpty);
  });
}
