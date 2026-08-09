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
              ),
            ),
          ],
        ),
      ),
    );
  }

  const edgeDrags = {
    PanelDockEdge.left: Offset(-80, 0),
    PanelDockEdge.right: Offset(470, 0),
    PanelDockEdge.top: Offset(0, -20),
    PanelDockEdge.bottom: Offset(0, 350),
  };

  for (final MapEntry(key: edge, value: dragOffset) in edgeDrags.entries) {
    testWidgets('dragging near the ${edge.name} edge snaps the panel', (
      tester,
    ) async {
      final controller = UIController();
      await tester.pumpWidget(buildLayout(controller));

      await tester.drag(find.text('Test Panel'), dragOffset);
      await tester.pump();

      expect(controller.dockEdge(panelId), edge);
    });
  }

  test('nearest edge wins at a corner', () {
    expect(
      nearestDockEdge(
        const Offset(10, kAppTitleBarHeight + 20),
        const Size(100, 50),
        const Size(800, 600),
      ),
      PanelDockEdge.left,
    );
    expect(
      nearestDockEdge(
        const Offset(20, kAppTitleBarHeight + 5),
        const Size(100, 50),
        const Size(800, 600),
      ),
      PanelDockEdge.top,
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
}
