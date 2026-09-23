import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/quick_events_controller.dart';
import 'package:flow_lens/controllers/events_controller.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/quick_event.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/dock_layout_state.dart';
import 'package:flow_lens/services/quick_events_repository.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'package:flow_lens/widgets/quick_events_panel.dart';
import 'package:flow_lens/widgets/event_buttons_panel.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/branded_title_bar.dart';
import 'package:flow_lens/widgets/smart_hud.dart';
import 'package:flow_lens/widgets/control_bar.dart';
import 'package:flow_lens/models/app_settings.dart';

class MemoryQuickRepository implements QuickEventsRepository {
  Map<String, dynamic> data = {};
  bool fail = false;
  @override
  Future<Map<String, dynamic>> load() async =>
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  @override
  Future<void> save(Map<String, dynamic> data) async {
    if (fail) throw StateError('disk full');
    this.data = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

void main() {
  final taxonomy = SportTaxonomy.fromJson(
    jsonDecode(File('assets/sports/hockey.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final onNet = QuickEvent(
    categoryId: 'shot',
    eventTypeId: 'shot_on_net',
    grade: EventGrade.positive,
    hotkey: 'j',
  );
  final wide = QuickEvent(
    categoryId: 'shot',
    eventTypeId: 'shot_wide',
    grade: EventGrade.negative,
    hotkey: 'k',
  );

  testWidgets('adding a shortcut follows hierarchy and confirms its grade', (
    tester,
  ) async {
    final ctrl = QuickEventsController(MemoryQuickRepository());
    await ctrl.load();
    ctrl.selectGame('hierarchy', taxonomy);
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: Scaffold(
          body: QuickEventsEditor(controller: ctrl, taxonomy: taxonomy),
        ),
      ),
    );
    await tester.tap(find.text('Add quick event'));
    await tester.pumpAndSettle();
    expect(find.text('1. Choose main event'), findsOneWidget);
    expect(find.text('On Net'), findsNothing);
    await tester.tap(find.text('Shot'));
    await tester.pumpAndSettle();
    expect(find.text('2. Choose sub-event'), findsOneWidget);
    await tester.ensureVisible(find.text('Saved'));
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('3. Choose grade'), findsOneWidget);
    expect(ctrl.items, isEmpty);
    await tester.tap(find.text('Negative'));
    await tester.tap(find.text('Add to quick menu'));
    await tester.pumpAndSettle();
    expect(ctrl.items.single.categoryId, 'shot');
    expect(ctrl.items.single.eventTypeId, 'shot_saved');
    expect(ctrl.items.single.grade, EventGrade.negative);

    await tester.tap(find.text('Add quick event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shot'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Saved'));
    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Negative'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add to quick menu'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Ungraded'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add to quick menu'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('2. Choose sub-event'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('1. Choose main event'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(ctrl.items, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await ctrl.flushed;
    ctrl.dispose();
  });

  for (final edge in [
    PanelDockEdge.left,
    PanelDockEdge.right,
    PanelDockEdge.top,
    PanelDockEdge.bottom,
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('quick shortcuts follow $edge at text scale $scale', (
        tester,
      ) async {
        final ctrl = QuickEventsController(MemoryQuickRepository());
        await ctrl.load();
        ctrl.selectGame('orientation', taxonomy);
        ctrl.add(onNet);
        ctrl.add(wide);
        final layout = UIController()..setDockEdge(PanelId.eventButtons, edge);
        var captures = 0;
        var opened = false;
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
              body: DockLayout(
                uiController: layout,
                panels: [
                  DockPanelEntry(
                    id: PanelId.eventButtons,
                    title: 'Quick events',
                    icon: Icons.bolt,
                    fillSideDock: true,
                    horizontalDockWidth: 480,
                    defaultFloatingPosition: Offset.zero,
                    builder: (dockEdge) => QuickEventsPanel(
                      controller: ctrl,
                      taxonomy: taxonomy,
                      vertical:
                          dockEdge != PanelDockEdge.top &&
                          dockEdge != PanelDockEdge.bottom,
                      onRecord: (_) => captures++,
                      onAllEvents: () => opened = true,
                    ),
                  ),
                ],
                child: const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final first = find.byKey(ValueKey('quick-${onNet.id}'));
        final second = find.byKey(ValueKey('quick-${wide.id}'));
        final a = tester.getRect(first);
        final b = tester.getRect(second);
        final horizontal =
            edge == PanelDockEdge.top || edge == PanelDockEdge.bottom;
        if (horizontal) {
          expect(a.center.dy, b.center.dy);
          expect(a.right, lessThan(b.left));
        } else {
          expect(a.left, b.left);
          expect(a.bottom, lessThan(b.top));
        }
        await tester.ensureVisible(second);
        await tester.pumpAndSettle();
        await tester.tap(second);
        expect(captures, 1);
        expect(find.byIcon(Icons.sports_hockey), findsNWidgets(2));
        expect(find.text('Negative'), findsOneWidget);
        await tester.tap(
          horizontal ? find.byTooltip('All events') : find.text('All events'),
        );
        expect(opened, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await ctrl.flushed;
        ctrl.dispose();
        layout.dispose();
      });
    }
  }

  testWidgets(
    'touch playback uses configured rates and keeps primary actions vertical',
    (tester) async {
      double? rate;
      Duration? back;
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 112,
              child: PlaybackControls(
                rate: 1.25,
                playing: true,
                dockEdge: PanelDockEdge.left,
                settings: const AppSettings(
                  slowPlaybackSpeed: 0.25,
                  defaultPlaybackSpeed: 1.25,
                  fastPlaySpeed: 4,
                ),
                onSpeedChange: (value) => rate = value,
                onJumpBackward: (value) => back = value,
                onJumpForward: (_) {},
                onTogglePlayPause: () {},
                onToggleMute: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Slow'));
      expect(rate, 0.25);
      await tester.tap(find.text('Fast'));
      expect(rate, 4);
      await tester.tap(find.text('Back 5s'));
      expect(back, const Duration(seconds: 5));
      expect(
        tester.getTopLeft(find.text('Slow')).dy,
        lessThan(tester.getTopLeft(find.text('Fast')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1024, 768), const Size(390, 844)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'quick workspace fits $size at text scale $scale with a long menu',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final ctrl = QuickEventsController(MemoryQuickRepository());
          await ctrl.load();
          ctrl.selectGame('preview', taxonomy);
          ctrl.add(onNet);
          ctrl.add(wide);
          for (final category in taxonomy.categories) {
            for (final type in category.eventTypes) {
              ctrl.add(
                QuickEvent(
                  categoryId: category.categoryId,
                  eventTypeId: type.eventTypeId,
                  grade: type.defaultImpact ?? EventGrade.neutral,
                ),
              );
            }
          }
          final controller = UIController()..initializeRecommendedLayouts();
          final boundaryKey = GlobalKey();
          var opened = false;
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
                body: RepaintBoundary(
                  key: boundaryKey,
                  child: Column(
                    children: [
                      BrandedTitleBar(
                        onShowShortcuts: () {},
                        showShortcuts: false,
                        currentMode: AppMode.record,
                        onModeChanged: (_) {},
                      ),
                      Expanded(
                        child: DockLayout(
                          adaptive: true,
                          uiController: controller,
                          panels: [
                            DockPanelEntry(
                              id: PanelId.playbackControls,
                              title: 'Playback',
                              icon: Icons.play_arrow,
                              defaultFloatingPosition: Offset.zero,
                              builder: (edge) => PlaybackControls(
                                rate: 1,
                                playing: true,
                                dockEdge: edge,
                                onSpeedChange: (_) {},
                                onJumpForward: (_) {},
                                onJumpBackward: (_) {},
                                onToggleMute: () {},
                                onTogglePlayPause: () {},
                              ),
                            ),
                            DockPanelEntry(
                              id: PanelId.eventButtons,
                              title: 'Quick events',
                              icon: Icons.bolt,
                              fillSideDock: true,
                              defaultFloatingPosition: Offset.zero,
                              builder: (edge) => QuickEventsPanel(
                                controller: ctrl,
                                taxonomy: taxonomy,
                                onRecord: (_) {},
                                vertical:
                                    edge == PanelDockEdge.left ||
                                    edge == PanelDockEdge.right,
                                onAllEvents: () => opened = true,
                              ),
                            ),
                          ],
                          child: const Center(
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: ColoredBox(
                                color: Color(0xFF283346),
                                child: Center(
                                  child: Text(
                                    'Synthetic video fixture',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (size.width >= 900) {
            await tester.tap(find.text('All events'));
            expect(
              opened,
              isTrue,
              reason:
                  'Footer remains reachable without scrolling through the long menu',
            );
          }
          if (const bool.fromEnvironment('CAPTURE_TOUCH_PREVIEWS')) {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/touch-preview-${size.width.toInt()}-${scale.toInt()}.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox());
          await ctrl.flushed;
          controller.dispose();
          ctrl.dispose();
        },
      );
    }
  }

  test(
    'game menus and presets remain independent after reorder, edit, delete and reload',
    () async {
      final repo = MemoryQuickRepository();
      final ctrl = QuickEventsController(repo);
      await ctrl.load();
      ctrl.selectGame('game-one', taxonomy);
      ctrl.add(onNet);
      ctrl.add(wide);
      ctrl.add(onNet);
      expect(ctrl.items.length, 2);
      ctrl.savePreset('Shots');
      final preset = ctrl.presets.single;
      ctrl.move(0, 1);
      expect(ctrl.items.last.hotkey, 'j');
      ctrl.update(onNet.copyWith(grade: EventGrade.neutral));
      expect(preset.items.first.grade, EventGrade.positive);
      ctrl.selectGame('game-two', taxonomy);
      expect(ctrl.items, isEmpty);
      ctrl.applyPreset(preset);
      ctrl.remove(wide.id);
      ctrl.deletePreset(preset.id);
      await ctrl.flushed;
      final restored = QuickEventsController(repo);
      await restored.load();
      restored.selectGame('game-one', taxonomy);
      expect(restored.items.map((e) => e.id), [wide.id, onNet.id]);
      expect(restored.items.last.grade, EventGrade.neutral);
      restored.selectGame('game-two', taxonomy);
      expect(restored.items.single.id, onNet.id);
      expect(restored.presets, isEmpty);
      ctrl.dispose();
      restored.dispose();
    },
  );

  test(
    'rapid capture keeps video timestamps, taxonomy IDs and distinct event IDs',
    () async {
      final ctrl = QuickEventsController(MemoryQuickRepository());
      final events = List.generate(
        100,
        (_) => ctrl.createEvent(
          onNet,
          taxonomy,
          const Duration(milliseconds: 12345),
        )!,
      );
      expect(events.map((e) => e.id).toSet().length, 100);
      expect(
        events.every(
          (e) =>
              e.timestamp.inMilliseconds == 12345 &&
              e.eventTypeId == 'shot_on_net' &&
              e.grade == EventGrade.positive,
        ),
        isTrue,
      );
      expect(
        ctrl.createEvent(
          QuickEvent(
            categoryId: 'missing',
            eventTypeId: 'missing',
            grade: EventGrade.neutral,
          ),
          taxonomy,
          Duration.zero,
        ),
        isNull,
      );
      ctrl.dispose();
    },
  );

  test('hotkey conflicts and write failures are recoverable', () async {
    final repo = MemoryQuickRepository();
    final ctrl = QuickEventsController(repo);
    await ctrl.load();
    ctrl.selectGame('one', taxonomy);
    ctrl.add(onNet);
    ctrl.add(wide);
    expect(ctrl.update(wide.copyWith(hotkey: 'j')), isFalse);
    expect(ctrl.update(wide.copyWith(hotkey: 's')), isFalse);
    expect(ctrl.update(wide.copyWith(clearHotkey: true)), isTrue);
    await ctrl.flushed;
    repo.fail = true;
    ctrl.remove(onNet.id);
    await ctrl.flushed;
    expect(ctrl.error, isNotNull);
    repo.fail = false;
    ctrl.retrySave();
    await ctrl.flushed;
    expect(ctrl.error, isNull);
    ctrl.dispose();
  });

  testWidgets(
    'quick panel captures once per tap and editing does not capture',
    (tester) async {
      final ctrl = QuickEventsController(MemoryQuickRepository());
      await ctrl.load();
      ctrl.selectGame('one', taxonomy);
      ctrl.add(onNet);
      ctrl.add(wide);
      var captures = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: Scaffold(
            body: SizedBox(
              width: 224,
              child: QuickEventsPanel(
                controller: ctrl,
                taxonomy: taxonomy,
                onRecord: (_) => captures++,
                onAllEvents: () {},
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Shot On Net'));
      await tester.tap(find.text('Shot Wide'));
      expect(captures, 2);
      await tester.tap(find.text('Edit quick menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Move down').first);
      await tester.pumpAndSettle();
      expect(ctrl.items.first.id, wide.id);
      expect(captures, 2);
      await tester.tap(find.text('Done').last);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await ctrl.flushed;
      ctrl.dispose();
    },
  );

  for (final size in [
    const Size(1024, 768),
    const Size(820, 1180),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('responsive shell and vertical categories fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ui = UIController()..initializeRecommendedLayouts();
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: Scaffold(
            body: Column(
              children: [
                BrandedTitleBar(
                  onShowShortcuts: () {},
                  showShortcuts: false,
                  currentMode: AppMode.record,
                  onModeChanged: (_) {},
                ),
                Expanded(
                  child: DockLayout(
                    adaptive: true,
                    uiController: ui,
                    panels: [
                      DockPanelEntry(
                        id: PanelId.eventButtons,
                        title: 'Events',
                        icon: Icons.bolt,
                        defaultFloatingPosition: Offset.zero,
                        builder: (edge) => EventButtonsPanel(
                          taxonomy: taxonomy,
                          dockEdge: edge,
                          onEventTriggered: (_) {},
                        ),
                      ),
                    ],
                    child: const ColoredBox(
                      key: ValueKey('video'),
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final video = tester.getRect(find.byKey(const ValueKey('video')));
      expect(video.width, greaterThan(300));
      expect(video.height, greaterThan(150));
      if (size.width >= 900) {
        expect(
          tester.getTopLeft(find.text('Shot')).dx,
          tester.getTopLeft(find.text('Pass')).dx,
        );
        expect(
          tester.getTopLeft(find.text('Shot')).dy,
          lessThan(tester.getTopLeft(find.text('Pass')).dy),
        );
      }
      await tester.pumpWidget(const SizedBox());
      ui.dispose();
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'touch save closes the editor with the selected event at scale $scale',
      (tester) async {
        GameEvent? draft = GameEvent(
          id: 'touch-draft',
          timestamp: const Duration(seconds: 12),
          categoryId: 'shot',
          label: 'Shot',
        );
        GameEvent? saved;
        var saves = 0;
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
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 260,
                  child: StatefulBuilder(
                    builder: (context, setState) => draft == null
                        ? const Text('Video')
                        : SmartHUD(
                            event: draft!,
                            taxonomy: taxonomy,
                            onUpdateEvent: (event) =>
                                setState(() => draft = event),
                            onDeleteEvent: (_) => setState(() => draft = null),
                            onDismiss: () => setState(() => draft = null),
                            onSave: () => setState(() {
                              saved = draft;
                              saves++;
                              draft = null;
                            }),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final save = find.widgetWithText(FilledButton, 'Save event');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(find.byIcon(Icons.thumb_up));
        await tester.tap(find.byIcon(Icons.thumb_up));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await tester.ensureVisible(find.text('Saved'));
        await tester.tap(find.text('Saved'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byIcon(Icons.thumb_down));
        await tester.tap(find.byIcon(Icons.thumb_down));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byType(SmartHUD), findsOneWidget);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(find.byType(SmartHUD), findsNothing);
        expect(saves, 1);
        expect(saved!.eventTypeId, 'shot_saved');
        expect(saved!.grade, EventGrade.negative);
        expect(saved!.timestamp, const Duration(seconds: 12));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final complete in [true, false]) {
    testWidgets('closing a saved event preserves it (complete: $complete)', (
      tester,
    ) async {
      final events = EventsController();
      final saved = GameEvent(
        id: 'saved-event',
        timestamp: const Duration(seconds: 12),
        categoryId: 'shot',
        label: 'Shot',
        eventTypeId: complete ? 'shot_on_net' : null,
        detail: complete ? 'On Net' : null,
        grade: complete ? EventGrade.positive : null,
      );
      events.addEvent(saved);
      events.selectEvent(saved);
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
            body: Center(
              child: SizedBox(
                width: 360,
                height: 260,
                child: ListenableBuilder(
                  listenable: events,
                  builder: (context, _) => events.activeEvent == null
                      ? const Text('Video')
                      : SmartHUD(
                          event: events.activeEvent!,
                          taxonomy: taxonomy,
                          onUpdateEvent: (_) =>
                              fail('Closing must not edit the event'),
                          onDeleteEvent: (_) =>
                              fail('Closing must not delete the event'),
                          onSave: () =>
                              fail('Closing must not save another event'),
                          onDismiss: () => events.selectEvent(null),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final close = find.byTooltip('Close event popup');
      expect(tester.getSize(close).height, greaterThanOrEqualTo(48));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(find.byType(SmartHUD), findsNothing);
      expect(events.activeEvent, isNull);
      expect(events.allEvents.single, same(saved));
      events.selectEvent(saved);
      await tester.pumpAndSettle();
      expect(find.byType(SmartHUD), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(events.allEvents.single, same(saved));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      events.dispose();
    });
  }

  testWidgets('touch event editor remains visible beyond the old timeout', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: Scaffold(
          body: Center(
            child: SmartHUD(
              event: GameEvent(
                id: 'draft',
                timestamp: Duration.zero,
                categoryId: 'shot',
                label: 'Shot',
              ),
              taxonomy: taxonomy,
              onUpdateEvent: (_) {},
              onDeleteEvent: (_) {},
              onDismiss: () => dismissed = true,
              onSave: () => dismissed = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 5));
    expect(dismissed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
