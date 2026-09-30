import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/events_controller.dart';
import 'package:flow_lens/controllers/quick_events_controller.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/services/quick_events_repository.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'package:flow_lens/widgets/branded_title_bar.dart';
import 'package:flow_lens/widgets/capture_status_bar.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/event_navigation_panel.dart';
import 'package:flow_lens/widgets/events_table_view.dart';
import 'package:flow_lens/widgets/quick_events_panel.dart';
import 'package:flow_lens/widgets/video_progress_bar.dart';
import 'package:flow_lens/controllers/settings_controller.dart';
import 'package:flow_lens/models/app_settings.dart';
import 'package:flow_lens/services/settings_repository.dart';
import 'package:flow_lens/widgets/settings_view.dart';

class _Repository implements QuickEventsRepository {
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<void> save(Map<String, dynamic> data) async {}
}

class _SettingsRepository implements SettingsRepository {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async {}
}

Future<void> resize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.binding.setSurfaceSize(size);
}

void main() {
  final taxonomy = SportTaxonomy.fromJson(
    jsonDecode(File('assets/sports/hockey.json').readAsStringSync()),
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'phone capture, feedback, rotation and review at scale $scale',
      (tester) async {
        await resize(tester, const Size(390, 844));
        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });
        final ui = UIController()..initializeRecommendedLayouts();
        final events = EventsController();
        final quick = QuickEventsController(_Repository());
        await quick.load();
        quick.selectGame('phone', taxonomy);
        quick.applyPreset(quick.suggestedPresets.first);
        quick.setShowAllEventsAction(true);
        final savedLayout = jsonEncode(ui.layoutState.toJson());
        var playing = true;
        var rate = 1.0;
        var position = const Duration(seconds: 42);
        GameEvent? last;
        GameEvent? navigated;
        late StateSetter update;
        final video = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: FlowTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                padding: const EdgeInsets.only(top: 24, bottom: 16),
              ),
              child: child!,
            ),
            home: Scaffold(
              resizeToAvoidBottomInset: false,
              body: SafeArea(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Column(
                      children: [
                        BrandedTitleBar(
                          onShowShortcuts: () {},
                          showShortcuts: false,
                          currentMode: ui.currentMode,
                          onModeChanged: (mode) =>
                              setState(() => ui.setMode(mode)),
                        ),
                        Expanded(
                          child: DockLayout(
                            adaptive: true,
                            uiController: ui,
                            phoneFeedback: CaptureStatusBar(
                              lastEvent: ui.currentMode == AppMode.record
                                  ? last
                                  : null,
                              onUndo: () => setState(() {
                                events.deleteEvent(last!);
                                last = null;
                              }),
                            ),
                            panels: [
                              if (ui.currentMode == AppMode.record)
                                DockPanelEntry(
                                  id: PanelId.quickEvents,
                                  title: 'Quick events',
                                  icon: Icons.bolt,
                                  defaultFloatingPosition: Offset.zero,
                                  layout: QuickEventsPanel.layoutFor(
                                    quick,
                                    taxonomy,
                                  ),
                                  builder: (_) => QuickEventsPanel(
                                    controller: quick,
                                    taxonomy: taxonomy,
                                    onAllEvents: () {},
                                    onRecord: (item) => setState(() {
                                      last = quick.createEvent(
                                        item,
                                        taxonomy,
                                        position,
                                      )!;
                                      events.addEvent(last!);
                                    }),
                                  ),
                                ),
                              if (ui.currentMode == AppMode.review)
                                DockPanelEntry(
                                  id: PanelId.eventNavigation,
                                  title: 'Event Navigation',
                                  icon: Icons.search,
                                  defaultFloatingPosition: Offset.zero,
                                  builder: (_) => EventNavigationPanel(
                                    controller: events,
                                    currentPosition: position,
                                    onNavigateTo: (event) => navigated = event,
                                    onOpenEventsTable: () {},
                                  ),
                                ),
                            ],
                            child: SizedBox.expand(key: video),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                          child: VideoTransportBar(
                            playing: playing,
                            rate: rate,
                            muted: false,
                            onPlayPause: () =>
                                setState(() => playing = !playing),
                            onJumpBackward: () => setState(
                              () => position -= const Duration(seconds: 5),
                            ),
                            onMute: () {},
                            onSpeedChange: (value) =>
                                setState(() => rate = value),
                            seekBar: VideoSeekTrack(
                              markers: const SizedBox(),
                              position: position,
                              duration: const Duration(minutes: 90),
                              onChanged: (_) {},
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final videoElement = video.currentContext;
        for (final size in [
          const Size(390, 844),
          const Size(844, 390),
          const Size(667, 375),
          const Size(320, 568),
        ]) {
          await resize(tester, size);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final action = find.byKey(ValueKey('quick-${quick.items.first.id}'));
          await tester.ensureVisible(action);
          await tester.tap(action);
          await tester.pump();
          expect(last!.timestamp, position);
          expect(playing, isTrue);
          expect(rate, 1);
          final undo = find.byTooltip('Undo last event');
          expect(undo.hitTestable(), findsOneWidget);
          expect(
            tester
                .getRect(find.byKey(const ValueKey('phone-scroll-quickEvents')))
                .overlaps(tester.getRect(undo)),
            isFalse,
          );
          final count = events.totalEventCount;
          await tester.tap(undo);
          await tester.pump();
          expect(events.totalEventCount, count - 1);
          await tester.tap(action);
          await tester.pump();
          await tester.ensureVisible(find.text('All events'));
          expect(find.text('All events').hitTestable(), findsOneWidget);
          expect(
            find.byKey(const ValueKey('expand-actions-Quick events')),
            findsNothing,
          );
          await tester.tap(find.byTooltip('Back 5 seconds'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(video.currentContext, same(videoElement));
          if (size.width > size.height) {
            expect(tester.getSize(find.byKey(video)).height, greaterThan(180));
          }
        }
        await tester.tap(find.byTooltip('Hide tools'));
        await tester.pump();
        await tester.tap(find.byTooltip('Show tools'));
        await tester.pump();
        update(() => ui.setMode(AppMode.review));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next event'));
        expect(navigated, isNotNull);
        expect(find.byType(OutlinedButton).hitTestable(), findsWidgets);
        await resize(tester, const Size(1280, 800));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('phone-tools')), findsNothing);
        expect(video.currentContext, same(videoElement));
        expect(jsonEncode(ui.layoutState.toJson()), savedLayout);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await quick.flushed;
        quick.dispose();
        events.dispose();
        ui.dispose();
      },
    );
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'phone settings and quick menu remain reachable with keyboard $size',
      (tester) async {
        await resize(tester, size);
        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
          await tester.binding.setSurfaceSize(null);
        });
        final settings = SettingsController(_SettingsRepository());
        Widget app(Widget child) => MaterialApp(
          theme: FlowTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: child,
        );
        await tester.pumpWidget(app(SettingsView(controller: settings)));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Reset to Defaults'));
        expect(find.text('Reset to Defaults').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        final quick = QuickEventsController(_Repository());
        await quick.load();
        quick.selectGame('phone', taxonomy);
        await tester.pumpWidget(
          app(QuickEventsEditor(controller: quick, taxonomy: taxonomy)),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Add quick event'));
        await tester.tap(find.text('Add quick event'));
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 180);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).last, 'shot');
        await tester.pumpAndSettle();
        expect(find.text('Cancel').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Done').hitTestable(), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await quick.flushed;
        quick.dispose();
        settings.dispose();
      },
    );

    testWidgets(
      'phone event list supports selection, sort, filter and navigation $size',
      (tester) async {
        await resize(tester, size);
        addTearDown(() async {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
        });
        final events = EventsController()
          ..setEvents([
            GameEvent(
              id: 'a',
              categoryId: 'shot',
              label: 'Shot',
              detail: 'On net',
              timestamp: const Duration(seconds: 10),
            ),
            GameEvent(
              id: 'b',
              categoryId: 'shot',
              label: 'Shot',
              detail: 'Wide',
              timestamp: const Duration(seconds: 20),
            ),
          ]);
        GameEvent? navigated;
        await tester.pumpWidget(
          MaterialApp(
            theme: FlowTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: EventsTableView(
              controller: events,
              taxonomy: taxonomy,
              onEventTap: (event) => navigated = event,
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final first = find.byKey(const ValueKey('phone-event-a'));
        await tester.tap(
          find.descendant(of: first, matching: find.byType(Checkbox)),
        );
        await tester.pump();
        expect(events.selectedEventIds, contains('a'));
        await tester.tap(find.byTooltip('Sort events'));
        await tester.pumpAndSettle();
        await tester.tap(
          find
              .byWidgetPredicate((widget) => widget is CheckedPopupMenuItem)
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('phone-event-b'))).dy,
          lessThan(tester.getTopLeft(first).dy),
        );
        await tester.tap(find.byTooltip('Filter events'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(first);
        await tester.tap(
          find.descendant(of: first, matching: find.byType(Text)).first,
        );
        expect(navigated?.id, 'a');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        events.dispose();
      },
    );
  }
}
