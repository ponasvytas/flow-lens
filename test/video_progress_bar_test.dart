import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/widgets/event_timeline.dart';
import 'package:flow_lens/widgets/video_progress_bar.dart';
import 'package:flow_lens/theme/flow_theme.dart';

void main() {
  final events = [
    for (final second in [0, 25, 50, 75, 100])
      GameEvent(
        id: '$second',
        timestamp: Duration(seconds: second),
        categoryId: 'shot',
        label: 'Shot',
      ),
  ];

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'markers and seeks share endpoints through resizing at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var width = 1000.0;
        var playing = false;
        var muted = false;
        var rate = 1.0;
        GameEvent? selected;
        double? sought;
        late StateSetter update;
        final markers = EventTimeline(
          events: events,
          totalDuration: const Duration(seconds: 100),
          onEventTap: (event) => selected = event,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: FlowTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: width,
                      child: VideoTransportBar(
                        playing: playing,
                        muted: muted,
                        rate: rate,
                        onPlayPause: () => setState(() => playing = !playing),
                        onMute: () => setState(() => muted = !muted),
                        onSpeedChange: (value) => setState(() => rate = value),
                        seekBar: VideoSeekTrack(
                          markers: markers,
                          position: const Duration(seconds: 25),
                          duration: const Duration(seconds: 100),
                          onChanged: (_) {},
                          onChangeEnd: (value) => sought = value,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        for (final nextWidth in [1000.0, 600.0, 334.0, 264.0, 1000.0]) {
          update(() => width = nextWidth);
          await tester.pumpAndSettle();
          final sliderFinder = find.byKey(const ValueKey('video-seek-slider'));
          final sliderBox = tester.renderObject<RenderBox>(sliderFinder);
          final theme = SliderTheme.of(tester.element(sliderFinder));
          final localTrack = theme.trackShape!.getPreferredRect(
            parentBox: sliderBox,
            sliderTheme: theme,
            isEnabled: true,
          );
          final track = localTrack.shift(sliderBox.localToGlobal(Offset.zero));
          final paint = find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is EventTimelinePainter,
          );
          final markerRect = tester.getRect(paint);
          expect(markerRect.left, closeTo(track.left, 0.01));
          expect(markerRect.right, closeTo(track.right, 0.01));
          expect(track.width, greaterThan(0));
          for (final event in events) {
            final x =
                track.left + track.width * event.timestamp.inSeconds / 100;
            await tester.tapAt(
              Offset(
                x.clamp(track.left + 0.01, track.right - 0.01),
                markerRect.center.dy,
              ),
            );
            expect(selected?.id, event.id);
          }
          await tester.tapAt(
            Offset(track.left + track.width * .75, track.center.dy),
          );
          expect(sought, closeTo(.75, .01));
          final before = markerRect;
          await tester.tap(
            find.byTooltip(playing ? 'Pause video' : 'Play video'),
          );
          await tester.tap(
            find.byTooltip(muted ? 'Unmute video' : 'Mute video'),
          );
          await tester.pumpAndSettle();
          expect(tester.getRect(paint), before);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byTooltip('Playback speed'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<double>, '0.5×'),
        );
        await tester.pumpAndSettle();
        expect(rate, .5);
        expect(find.text('0.5×'), findsOneWidget);
        expect(events.map((event) => event.timestamp.inSeconds), [
          0,
          25,
          50,
          75,
          100,
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unknown duration disables seeking and long recordings show hours',
    (tester) async {
      expect(
        formatVideoTime(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '2:03:04',
      );
      expect(formatVideoTime(const Duration(minutes: 3, seconds: 4)), '03:04');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoSeekTrack(
              markers: const SizedBox(),
              position: Duration.zero,
              duration: Duration.zero,
              onChanged: (_) => fail('Unknown-duration video must not seek'),
            ),
          ),
        ),
      );
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
