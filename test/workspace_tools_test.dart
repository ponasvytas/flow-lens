import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/controllers/events_controller.dart';
import 'package:flow_lens/controllers/event_entry_controller.dart';
import 'package:flow_lens/controllers/quick_events_controller.dart';
import 'package:flow_lens/controllers/drawing_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/dock_layout_state.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/services/quick_events_repository.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/drawing_tools_panel.dart';
import 'package:flow_lens/widgets/event_entry_surface.dart';
import 'package:flow_lens/widgets/quick_events_panel.dart';
import 'package:flow_lens/widgets/workspace_tools_menu.dart';

class _QuickRepository implements QuickEventsRepository {
  @override
  Future<Map<String, dynamic>> load() async => {};
  @override
  Future<void> save(Map<String, dynamic> data) async {}
}

void main() {
  final taxonomy = SportTaxonomy.fromJson(
    jsonDecode(File('assets/sports/hockey.json').readAsStringSync()),
  );
  const capture = bool.fromEnvironment('CAPTURE_WORKSPACE');
  setUpAll(() async {
    if (capture) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (await font.exists()) {
        final loader = FontLoader('Roboto')
          ..addFont(
            font.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
      }
    }
  });

  testWidgets(
    'Tools remains open for multiple selections and restores hidden panels',
    (tester) async {
      final controller = UIController()..initializeRecommendedLayouts();
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showWorkspaceTools(context, controller, onShortcuts: () {}),
                child: const Text('Open tools'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quick events'));
      await tester.pumpAndSettle();
      expect(controller.panelVisible(PanelId.quickEvents), isFalse);
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      expect(controller.panelVisible(PanelId.categories), isTrue);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Drawing'), findsNothing);
      await tester.tap(find.text('Quick events'));
      await tester.pumpAndSettle();
      expect(controller.panelVisible(PanelId.quickEvents), isTrue);
      expect(controller.panelCollapsed(PanelId.quickEvents), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  for (final edge in PanelDockEdge.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('drawing palette works at $edge with text scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1100, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = UIController()
          ..initializeRecommendedLayouts()
          ..setMode(AppMode.review);
        controller.showPanel(PanelId.drawingTools);
        controller.setDockEdge(PanelId.drawingTools, edge);
        final drawing = DrawingController();
        final boundaryKey = GlobalKey();
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
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => DockLayout(
                    uiController: controller,
                    panels: [
                      DockPanelEntry(
                        id: PanelId.drawingTools,
                        title: 'Drawing',
                        icon: Icons.draw,
                        defaultFloatingPosition: const Offset(60, 50),
                        defaultFloatingSize: const Size(560, 160),
                        layout: DrawingToolsPanel.layout,
                        builder: (edge) => ListenableBuilder(
                          listenable: drawing,
                          builder: (context, _) => DrawingToolsPanel(
                            isDrawingMode: drawing.isDrawingMode,
                            currentTool: drawing.currentTool,
                            drawingColor: drawing.drawingColor,
                            onToggleDrawingMode: drawing.toggleDrawingMode,
                            onClearDrawing: drawing.clearAll,
                            onToolChange: drawing.setTool,
                            onColorChange: drawing.setColor,
                            dockEdge: edge,
                            onWidthChange: drawing.setStrokeWidth,
                          ),
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
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('Pen (1)'));
        await tester.tap(find.byTooltip('Pen (1)'));
        await tester.pumpAndSettle();
        expect(drawing.isDrawingMode, isTrue);
        await tester.ensureVisible(find.byTooltip('Drawing color'));
        await tester.tap(find.byTooltip('Drawing color'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<Color>, 'Yellow'),
        );
        await tester.pumpAndSettle();
        expect(drawing.drawingColor, Colors.yellow);
        expect(tester.takeException(), isNull);
        if (capture && scale == 1) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/workspace-drawing-${edge.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        controller.collapsePanel(PanelId.drawingTools);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        controller.hidePanel(PanelId.drawingTools);
        await tester.pumpAndSettle();
        expect(find.byType(DrawingToolsPanel), findsNothing);
        controller.showPanel(PanelId.drawingTools);
        await tester.pumpAndSettle();
        expect(controller.panelCollapsed(PanelId.drawingTools), isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        drawing.dispose();
      });
    }
  }

  for (final size in [
    const Size(1280, 800),
    const Size(390, 844),
    const Size(844, 390),
    const Size(844, 204),
  ]) {
    testWidgets(
      'Quick events and Categories share workspace at $size without losing a draft',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = UIController()
          ..initializeRecommendedLayouts()
          ..showPanel(PanelId.categories);
        final entry = EventEntryController();
        final events = EventsController();
        final quick = QuickEventsController(_QuickRepository());
        await quick.load();
        quick.selectGame('workspace', taxonomy);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: FlowTheme.dark,
            home: Scaffold(
              body: RepaintBoundary(
                key: boundaryKey,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => DockLayout(
                    adaptive: true,
                    uiController: controller,
                    panels: [
                      DockPanelEntry(
                        id: PanelId.quickEvents,
                        title: 'Quick events',
                        icon: Icons.bolt,
                        fillSideDock: true,
                        defaultFloatingPosition: Offset.zero,
                        builder: (edge) => QuickEventsPanel(
                          controller: quick,
                          taxonomy: taxonomy,
                          onRecord: (_) {},
                          onAllEvents: () {},
                          vertical: edge == PanelDockEdge.right,
                        ),
                      ),
                      DockPanelEntry(
                        id: PanelId.categories,
                        title: 'Categories',
                        icon: Icons.category,
                        defaultFloatingPosition: Offset.zero,
                        builder: (edge) => EventEntrySurface(
                          events: events,
                          entry: entry,
                          quickEvents: quick,
                          taxonomy: taxonomy,
                          dockEdge: edge,
                          onCategory: (id) => entry.beginDraft(
                            GameEvent(
                              id: 'draft',
                              sportId: 'hockey',
                              categoryId: id,
                              label: taxonomy.getCategoryById(id)!.name,
                              timestamp: const Duration(seconds: 42),
                            ),
                          ),
                          onUpdate: entry.updateDraft,
                          onDelete: (_) => entry.cancelDraft(),
                          onSave: () => entry.commitDraft(events),
                          onCancel: entry.cancelDraft,
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
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (size.width < 900) {
          final selector = find.byType(DropdownButton<PanelId>);
          if (selector.evaluate().isNotEmpty) {
            await tester.tap(selector);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Categories').last);
          } else {
            await tester.tap(find.text('Categories').first);
          }
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Shot'));
        await tester.tap(find.text('Shot'));
        await tester.pumpAndSettle();
        expect(entry.draft?.timestamp, const Duration(seconds: 42));
        controller.hidePanel(PanelId.quickEvents);
        controller.hidePanel(PanelId.categories);
        await tester.pumpAndSettle();
        expect(find.byType(EventEntrySurface), findsNothing);
        expect(entry.draft, isNotNull);
        controller.showPanel(PanelId.categories);
        await tester.pumpAndSettle();
        expect(entry.draft?.timestamp, const Duration(seconds: 42));
        expect(tester.takeException(), isNull);
        if (capture && size.width > 1000) {
          entry.cancelDraft();
          controller.showPanel(PanelId.quickEvents);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/workspace-record.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await quick.flushed;
        controller.dispose();
        entry.dispose();
        events.dispose();
        quick.dispose();
      },
    );
  }
}
