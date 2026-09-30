import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/controllers/quick_events_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/app_settings.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/quick_event.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/widgets/capture_status_bar.dart';
import 'package:flow_lens/widgets/control_bar.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/dockable_panel.dart';
import 'package:flow_lens/widgets/event_buttons_panel.dart';
import 'package:flow_lens/widgets/tool_action_grid.dart';
import 'package:flow_lens/widgets/quick_events_panel.dart';
import 'package:flow_lens/services/quick_events_repository.dart';
import 'package:flow_lens/theme/flow_theme.dart';

class _QuickRepository implements QuickEventsRepository {
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<void> save(Map<String, dynamic> data) async {}
}

void expectInside(WidgetTester tester, Finder target, Rect bounds) {
  final rect = tester.getRect(target);
  expect(rect.width, greaterThanOrEqualTo(48));
  expect(rect.height, greaterThanOrEqualTo(48));
  expect(rect.left, greaterThanOrEqualTo(bounds.left));
  expect(rect.top, greaterThanOrEqualTo(bounds.top));
  expect(rect.right, lessThanOrEqualTo(bounds.right + 0.01));
  expect(rect.bottom, lessThanOrEqualTo(bounds.bottom + 0.01));
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_WORKSPACE');
  setUpAll(() async {
    if (capture) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        await (FontLoader(
          'Roboto',
        )..addFont(font.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
  });
  final taxonomy = SportTaxonomy.fromJson(
    jsonDecode(File('assets/sports/hockey.json').readAsStringSync()),
  );

  testWidgets('Playback and Quick events tiles align in narrow sidebars', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final quick = QuickEventsController(_QuickRepository());
    await quick.load();
    quick.selectGame('sidebar', taxonomy);
    for (final item in quick.suggestedPresets.first.items.take(3)) {
      quick.add(item);
    }
    var width = 104.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Row(
                children: [
                  SizedBox(
                    width: width,
                    height: 800,
                    child: PlaybackControls(
                      rate: 1,
                      playing: false,
                      settings: const AppSettings(),
                      onSpeedChange: (_) {},
                      onJumpForward: (_) {},
                      onJumpBackward: (_) {},
                      onTogglePlayPause: () {},
                      onToggleMute: () {},
                    ),
                  ),
                  SizedBox(
                    width: width,
                    height: 800,
                    child: QuickEventsPanel(
                      controller: quick,
                      taxonomy: taxonomy,
                      onRecord: (_) {},
                      onAllEvents: () {},
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    for (final nextWidth in [104.0, 160.0, 220.0, 280.0]) {
      update(() => width = nextWidth);
      await tester.pumpAndSettle();
      final playbackTile = find
          .descendant(
            of: find.byType(PlaybackControls),
            matching: find.byType(ToolActionButton),
          )
          .first;
      final quickTile = find
          .descendant(
            of: find.byType(QuickEventsPanel),
            matching: find.byType(ToolActionButton),
          )
          .first;
      expect(
        tester.getSize(playbackTile).width,
        tester.getSize(quickTile).width,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await quick.flushed;
    quick.dispose();
  });

  for (final edge in PanelDockEdge.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('every category is fully visible at $edge scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1100));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = UIController()
          ..showPanel(PanelId.categories)
          ..setDockEdge(PanelId.categories, edge)
          ..setDockExtent(PanelDockEdge.left, 400)
          ..setDockExtent(PanelDockEdge.right, 400);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: DockLayout(
                uiController: controller,
                panels: [
                  DockPanelEntry(
                    id: PanelId.categories,
                    title: 'Categories',
                    icon: Icons.category,
                    defaultFloatingPosition: const Offset(30, 30),
                    defaultFloatingSize: const Size(400, 100),
                    layout: EventButtonsPanel.layoutFor(taxonomy),
                    builder: (edge) => EventButtonsPanel(
                      taxonomy: taxonomy,
                      dockEdge: edge,
                      onEventTriggered: (id) => selected = id,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('expand-actions-Categories')),
          findsNothing,
        );
        final bounds = tester.getRect(find.byType(DockPanel));
        for (final category in taxonomy.captureCategories) {
          final tile = find.byKey(ValueKey('category-${category.categoryId}'));
          expectInside(tester, tile, bounds);
          await tester.tap(tile);
          expect(selected, category.categoryId);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      });
    }
  }

  for (final edge in [PanelDockEdge.top, PanelDockEdge.bottom]) {
    testWidgets('$edge reflows added actions and toolsets without scrolling', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UIController()
        ..showPanel(PanelId.categories)
        ..showPanel(PanelId.quickEvents)
        ..setDockEdge(PanelId.categories, edge)
        ..setDockEdge(PanelId.quickEvents, edge);
      final count = ValueNotifier(5);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: Listenable.merge([controller, count]),
              builder: (context, _) => DockLayout(
                uiController: controller,
                panels: [
                  for (final id in [PanelId.categories, PanelId.quickEvents])
                    DockPanelEntry(
                      id: id,
                      title: id.name,
                      icon: Icons.widgets,
                      defaultFloatingPosition: Offset.zero,
                      layout: ToolsetLayout.actions(
                        List.generate(count.value, (i) => 'Action $i'),
                        tileWidth: 72,
                      ),
                      builder: (_) => ToolActionGrid(
                        title: id.name,
                        layout: ToolsetLayout.actions(
                          List.generate(count.value, (i) => 'Action $i'),
                          tileWidth: 72,
                        ),
                        children: List.generate(
                          count.value,
                          (i) => ToolActionButton(
                            key: ValueKey('${id.name}-$i'),
                            label: 'Action $i',
                            icon: Icons.sports_hockey,
                            onPressed: () {},
                          ),
                        ),
                      ),
                      contentRevision: count.value,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final total in [5, 12, 4]) {
        count.value = total;
        await tester.pumpAndSettle();
        for (final id in [PanelId.categories, PanelId.quickEvents]) {
          final bounds = tester.getRect(
            find.byKey(ValueKey('workspace-panel-${id.name}')),
          );
          for (var i = 0; i < total; i++) {
            expectInside(tester, find.byKey(ValueKey('${id.name}-$i')), bounds);
          }
        }
        expect(tester.takeException(), isNull);
      }
      controller.hidePanel(PanelId.quickEvents);
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DockPanel)).width, 1016);
      await tester.pumpWidget(const SizedBox());
      count.dispose();
      controller.dispose();
    });
  }

  for (final width in [1024.0, 1280.0]) {
    testWidgets('real capture toolsets share a horizontal dock at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UIController()
        ..showPanel(PanelId.categories)
        ..showPanel(PanelId.quickEvents)
        ..setDockEdge(PanelId.categories, PanelDockEdge.top)
        ..setDockEdge(PanelId.quickEvents, PanelDockEdge.top);
      final quick = QuickEventsController(_QuickRepository());
      await quick.load();
      quick.selectGame('layout', taxonomy);
      for (final type
          in taxonomy.captureCategories.first.captureEventTypes.take(5)) {
        quick.add(
          QuickEvent(
            categoryId: taxonomy.captureCategories.first.categoryId,
            eventTypeId: type.eventTypeId,
            grade: type.defaultImpact,
          ),
        );
      }
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: Scaffold(
            body: RepaintBoundary(
              key: boundaryKey,
              child: DockLayout(
                uiController: controller,
                panels: [
                  DockPanelEntry(
                    id: PanelId.categories,
                    title: 'Categories',
                    icon: Icons.category,
                    defaultFloatingPosition: Offset.zero,
                    layout: EventButtonsPanel.layoutFor(taxonomy),
                    builder: (edge) => EventButtonsPanel(
                      taxonomy: taxonomy,
                      dockEdge: edge,
                      onEventTriggered: (_) {},
                    ),
                  ),
                  DockPanelEntry(
                    id: PanelId.quickEvents,
                    title: 'Quick events',
                    icon: Icons.bolt,
                    defaultFloatingPosition: Offset.zero,
                    layout: QuickEventsPanel.layoutFor(quick, taxonomy),
                    builder: (_) => QuickEventsPanel(
                      controller: quick,
                      taxonomy: taxonomy,
                      onRecord: (_) {},
                      onAllEvents: () {},
                    ),
                  ),
                ],
                child: const ColoredBox(
                  color: Color(0xFF283346),
                  child: Center(child: Text('Video')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in [
        (
          PanelId.categories,
          taxonomy.captureCategories.map((c) => 'category-${c.categoryId}'),
        ),
        (PanelId.quickEvents, quick.items.map((e) => 'quick-${e.id}')),
      ]) {
        final bounds = tester.getRect(
          find.byKey(ValueKey('workspace-panel-${entry.$1.name}')),
        );
        for (final key in entry.$2) {
          expectInside(tester, find.byKey(ValueKey(key)), bounds);
        }
      }
      expect(tester.takeException(), isNull);
      if (capture) {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'build/workspace-capture-top-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await quick.flushed;
      quick.dispose();
      controller.dispose();
    });
  }

  testWidgets(
    'an undersized palette expands explicitly instead of clipping targets',
    (tester) async {
      final labels = List.generate(20, (i) => 'Long action label $i');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 100,
              child: ToolActionGrid(
                title: 'Test actions',
                layout: ToolsetLayout.actions(labels, tileWidth: 96),
                children: [
                  for (final label in labels)
                    ToolActionButton(
                      label: label,
                      icon: Icons.star,
                      onPressed: () {},
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ToolActionButton), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('expand-actions-Test actions')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(ToolActionButton), findsNWidgets(20));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded category selection closes the palette to reveal event entry',
    (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 220,
              height: 100,
              child: EventButtonsPanel(
                taxonomy: taxonomy,
                onEventTriggered: (id) => selected = id,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('expand-actions-Categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shot'));
      await tester.pumpAndSettle();
      expect(selected, 'shot');
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('an expanded palette reflects added and removed actions', (
    tester,
  ) async {
    var count = 8;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: 220,
                height: 100,
                child: ToolActionGrid(
                  title: 'Live',
                  layout: ToolsetLayout.actions(
                    List.filled(count, 'Action'),
                    tileWidth: 72,
                  ),
                  children: List.generate(
                    count,
                    (i) => ToolActionButton(
                      label: 'Action',
                      icon: Icons.star,
                      onPressed: () {},
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('expand-actions-Live')));
    await tester.pumpAndSettle();
    expect(find.byType(ToolActionButton), findsNWidgets(8));
    update(() => count = 12);
    await tester.pumpAndSettle();
    expect(find.byType(ToolActionButton), findsNWidgets(12));
    update(() => count = 6);
    await tester.pumpAndSettle();
    expect(find.byType(ToolActionButton), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a large toolset cannot shrink its neighbor below an accessible target',
    (tester) async {
      final controller = UIController()
        ..showPanel(PanelId.quickEvents)
        ..showPanel(PanelId.categories)
        ..setDockEdge(PanelId.quickEvents, PanelDockEdge.left)
        ..setDockEdge(PanelId.categories, PanelDockEdge.left)
        ..setDockExtent(PanelDockEdge.left, 240);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DockLayout(
              uiController: controller,
              panels: [
                for (final id in [PanelId.quickEvents, PanelId.categories])
                  DockPanelEntry(
                    id: id,
                    title: id.name,
                    icon: Icons.widgets,
                    defaultFloatingPosition: Offset.zero,
                    layout: ToolsetLayout.actions(
                      List.filled(
                        id == PanelId.quickEvents ? 200 : 5,
                        'Action',
                      ),
                      tileWidth: 72,
                    ),
                    builder: (_) => ToolActionGrid(
                      title: id.name,
                      layout: ToolsetLayout.actions(
                        List.filled(
                          id == PanelId.quickEvents ? 200 : 5,
                          'Action',
                        ),
                        tileWidth: 72,
                      ),
                      children: List.generate(
                        id == PanelId.quickEvents ? 200 : 5,
                        (i) => ToolActionButton(
                          label: 'Action',
                          icon: Icons.star,
                          onPressed: () {},
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final id in [PanelId.quickEvents, PanelId.categories]) {
        final bounds = tester.getRect(
          find.byKey(ValueKey('workspace-panel-${id.name}')),
        );
        expectInside(
          tester,
          find.byKey(ValueKey('expand-actions-${id.name}')),
          bounds,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('idle has no status strip and capture feedback expires', (
    tester,
  ) async {
    GameEvent? event;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return CaptureStatusBar(lastEvent: event);
            },
          ),
        ),
      ),
    );
    expect(find.byType(Material).evaluate().length, 1);
    expect(find.textContaining('Ready to'), findsNothing);
    expect(find.byTooltip('Fit video'), findsNothing);
    update(
      () => event = GameEvent(
        id: 'e',
        timestamp: Duration.zero,
        categoryId: 'shot',
        label: 'Shot',
      ),
    );
    await tester.pump();
    expect(find.textContaining('Recorded: Shot'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.textContaining('Recorded: Shot'), findsNothing);
  });
}
