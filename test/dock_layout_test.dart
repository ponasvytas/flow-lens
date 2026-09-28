import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/dockable_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const panelId = PanelId.playbackControls;
  const defaultPosition = Offset(100, 100);

  Widget buildLayout(UIController controller) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => DockLayout(
                uiController: controller,
                panels: [
                  DockPanelEntry(
                    id: panelId,
                    title: 'Test Panel',
                    icon: Icons.widgets,
                    defaultFloatingPosition: defaultPosition,
                    builder: (_) => const SizedBox(
                      width: 100,
                      height: 50,
                      child: Text('Panel content'),
                    ),
                  ),
                ],
                child: const ColoredBox(
                  key: ValueKey('content-surface'),
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  const edgeDrags = {
    'left': Offset(-80, 0),
    'right': Offset(470, 0),
    'top': Offset(0, -20),
    'bottom': Offset(0, 350),
  };

  for (final edge in [PanelDockEdge.top, PanelDockEdge.bottom]) {
    testWidgets('$edge uses inline controls and collapses to one button', (
      tester,
    ) async {
      final controller = UIController()..setDockEdge(panelId, edge);
      await tester.pumpWidget(buildLayout(controller));
      await tester.pumpAndSettle();
      expect(find.text('Test Panel'), findsNothing);
      final dock = find.byTooltip('Test Panel — Dock position');
      final collapse = find.text('Collapse panel');
      final content = find.text('Panel content');
      expect(
        tester.getRect(dock).right,
        lessThanOrEqualTo(tester.getRect(content).left),
      );
      expect(
        tester.getRect(content).right,
        lessThanOrEqualTo(tester.getRect(find.byType(DockPanel)).right),
      );
      final expandedWidth = tester.getSize(find.byType(DockPanel)).width;
      await tester.tap(dock);
      await tester.pumpAndSettle();
      await tester.tap(collapse);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DockPanel)).width,
        kPanelCollapsedInlineWidth,
      );
      expect(find.text('Panel content'), findsNothing);
      expect(find.byTooltip('Test Panel — Dock position'), findsNothing);
      await tester.tap(find.byTooltip('Expand Test Panel'));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(DockPanel)).width, expandedWidth);
      expect(content, findsOneWidget);
      await tester.tap(dock);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dock Left'));
      await tester.pumpAndSettle();
      expect(controller.dockEdge(panelId), PanelDockEdge.left);
      expect(find.text('Test Panel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('horizontal collapse preserves content state', (tester) async {
    var collapsed = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return SizedBox(
                width: collapsed ? kPanelCollapsedInlineWidth : 360,
                height: 104,
                child: DockPanel(
                  panelId: panelId,
                  title: 'Test Panel',
                  icon: Icons.widgets,
                  dockEdge: PanelDockEdge.top,
                  onDockEdgeChanged: (_) {},
                  isCollapsed: collapsed,
                  onCollapsedChanged: (value) =>
                      setState(() => collapsed = value),
                  presentationMode: DockPresentationMode.overlay,
                  onPresentationModeChanged: (_) {},
                  child: const TextField(),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Keep this value');
    update(() => collapsed = true);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText, skipOffstage: false))
          .focusNode
          .canRequestFocus,
      isFalse,
    );
    await tester.tap(find.byTooltip('Expand Test Panel'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this value'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final MapEntry(key: edge, value: dragOffset) in edgeDrags.entries) {
    testWidgets('dragging near the $edge edge keeps the panel floating', (
      tester,
    ) async {
      final controller = UIController();
      await tester.pumpWidget(buildLayout(controller));

      await tester.drag(find.text('Test Panel'), dragOffset);
      await tester.pump();

      expect(controller.dockEdge(panelId), PanelDockEdge.floating);
    });
  }

  testWidgets('dragging beyond the viewport clamps the floating position', (
    tester,
  ) async {
    final controller = UIController();
    await tester.pumpWidget(buildLayout(controller));

    await tester.drag(find.text('Test Panel'), const Offset(-500, -500));
    await tester.pump();

    expect(controller.dockEdge(panelId), PanelDockEdge.floating);
    expect(controller.floatingPosition(panelId, defaultPosition), Offset.zero);
  });

  testWidgets('dragging panel content does not move the floating panel', (
    tester,
  ) async {
    final controller = UIController();
    await tester.pumpWidget(buildLayout(controller));

    await tester.drag(find.text('Panel content'), const Offset(80, 40));
    await tester.pump();

    expect(
      controller.floatingPosition(panelId, defaultPosition),
      defaultPosition,
    );
  });

  testWidgets('floating panel tracks the full global pointer displacement', (
    tester,
  ) async {
    final controller = UIController();
    await tester.pumpWidget(buildLayout(controller));

    await tester.drag(find.text('Test Panel'), const Offset(120, 60));
    await tester.pump();

    expect(
      controller.floatingPosition(panelId, defaultPosition),
      const Offset(220, 160),
    );
  });

  testWidgets('dock menu still docks a floating panel', (tester) async {
    final controller = UIController();
    await tester.pumpWidget(buildLayout(controller));

    await tester.tap(find.byTooltip('Dock position'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dock Left'));
    await tester.pumpAndSettle();

    expect(controller.dockEdge(panelId), PanelDockEdge.left);
  });

  testWidgets('dock resize handle updates the edge extent', (tester) async {
    final controller = UIController();
    controller.setDockEdge(panelId, PanelDockEdge.left);
    await tester.pumpWidget(buildLayout(controller));

    await tester.drag(
      find.byKey(const ValueKey('dock-resize-left')),
      const Offset(40, 0),
    );
    await tester.pump();

    expect(controller.dockExtent(PanelDockEdge.left), 320);
  });

  testWidgets('dock menu toggles between overlay and squeeze modes', (
    tester,
  ) async {
    final controller = UIController();
    await tester.pumpWidget(buildLayout(controller));

    await tester.tap(find.byTooltip('Dock position'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Docks overlay video'));
    await tester.pumpAndSettle();

    expect(controller.dockPresentationMode, DockPresentationMode.squeeze);
  });

  for (final size in [
    const Size(1024, 768),
    const Size(1180, 820),
    const Size(1280, 500),
  ]) {
    testWidgets('side tools preserve video space at $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UIController()..initializeRecommendedLayouts();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 56),
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
                        builder: (_) => const Text('Playback actions'),
                      ),
                      DockPanelEntry(
                        id: PanelId.quickEvents,
                        title: 'Quick events',
                        icon: Icons.bolt,
                        defaultFloatingPosition: Offset.zero,
                        builder: (_) => const Text('Event actions'),
                      ),
                    ],
                    child: const ColoredBox(
                      key: ValueKey('video'),
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('side-tool-selector')), findsOneWidget);
      expect(find.text('Event actions'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('video'))).width,
        greaterThanOrEqualTo(size.width * 0.68),
      );
      await tester.tap(find.byKey(const ValueKey('side-tool-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Playback').last);
      await tester.pumpAndSettle();
      expect(find.text('Playback actions'), findsOneWidget);
      expect(controller.dockEdge(PanelId.playbackControls), PanelDockEdge.left);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('wide docks retain at least half the workspace for video', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = UIController()
      ..initializeRecommendedLayouts()
      ..setDockEdge(PanelId.quickEvents, PanelDockEdge.right)
      ..setDockExtent(PanelDockEdge.left, 620)
      ..setDockExtent(PanelDockEdge.right, 620);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DockLayout(
            adaptive: true,
            uiController: controller,
            panels: [
              for (final id in [PanelId.playbackControls, PanelId.quickEvents])
                DockPanelEntry(
                  id: id,
                  title: id.name,
                  icon: Icons.widgets,
                  defaultFloatingPosition: Offset.zero,
                  builder: (_) => Text(id.name),
                ),
            ],
            child: const ColoredBox(
              key: ValueKey('video'),
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('video'))).width, 720);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final size in [
    const Size(1920, 1080),
    const Size(1280, 720),
    const Size(820, 1180),
    const Size(768, 1024),
  ]) {
    testWidgets('workspace and tools fit $size', (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UIController()..initializeRecommendedLayouts();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 56),
                Expanded(
                  child: DockLayout(
                    adaptive: true,
                    uiController: controller,
                    panels: [
                      for (final id in [
                        PanelId.playbackControls,
                        PanelId.quickEvents,
                      ])
                        DockPanelEntry(
                          id: id,
                          title: id.name,
                          icon: Icons.widgets,
                          defaultFloatingPosition: Offset.zero,
                          builder: (_) => Text('${id.name} actions'),
                        ),
                    ],
                    child: const ColoredBox(
                      key: ValueKey('video'),
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final video = tester.getSize(find.byKey(const ValueKey('video')));
      if (size.width >= 1200) {
        expect(video.width, greaterThanOrEqualTo(size.width * 0.5));
      } else {
        expect(video.height, greaterThanOrEqualTo((size.height - 126) * 0.4));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
