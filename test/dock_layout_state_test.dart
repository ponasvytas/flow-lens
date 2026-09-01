import 'dart:ui';

import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/dock_layout_state.dart';
import 'package:flow_lens/services/dock_layout_repository.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryDockLayoutRepository implements DockLayoutRepository {
  DockLayoutState state = const DockLayoutState();

  @override
  Future<DockLayoutState> load() async => state;

  @override
  Future<void> save(DockLayoutState state) async {
    this.state = state;
  }
}

void main() {
  test('dock layout state preserves every workflow through JSON', () {
    final state = const DockLayoutState().withWorkflow(
      AppMode.tracking,
      const WorkflowDockState(
        presentationMode: DockPresentationMode.squeeze,
        extents: DockEdgeExtents(left: 340, top: 120),
      ).withPanel(
        PanelId.playerTracking,
        const DockPanelState(
          edge: PanelDockEdge.left,
          floatingPosition: Offset(18, 24),
          floatingSize: Size(410, 520),
          collapsed: true,
          visible: true,
        ),
      ),
    );

    final restored = DockLayoutState.fromJson(state.toJson());
    final workflow = restored.workflow(AppMode.tracking);
    final panel = workflow.panel(PanelId.playerTracking);

    expect(workflow.presentationMode, DockPresentationMode.squeeze);
    expect(workflow.extents.left, 340);
    expect(workflow.extents.top, 120);
    expect(panel.edge, PanelDockEdge.left);
    expect(panel.floatingPosition, const Offset(18, 24));
    expect(panel.floatingSize, const Size(410, 520));
    expect(panel.collapsed, isTrue);
    expect(panel.visible, isTrue);
  });

  test('controller persists independent layouts per workflow', () async {
    final repository = _MemoryDockLayoutRepository();
    final controller = UIController(repository);

    controller.setDockEdge(PanelId.playbackControls, PanelDockEdge.bottom);
    controller.setDockExtent(PanelDockEdge.bottom, 132);
    controller.setMode(AppMode.review);
    controller.setDockEdge(PanelId.playbackControls, PanelDockEdge.left);
    controller.setDockPresentationMode(DockPresentationMode.squeeze);
    controller.setMode(AppMode.tracking);
    controller.setDockEdge(PanelId.playerTracking, PanelDockEdge.right);
    await Future<void>.delayed(Duration.zero);

    final restored = UIController(repository);
    await restored.loadDockLayouts();
    expect(restored.dockEdge(PanelId.playbackControls), PanelDockEdge.bottom);
    expect(restored.dockExtent(PanelDockEdge.bottom), 132);

    restored.setMode(AppMode.review);
    expect(restored.dockEdge(PanelId.playbackControls), PanelDockEdge.left);
    expect(restored.dockPresentationMode, DockPresentationMode.squeeze);

    restored.setMode(AppMode.tracking);
    expect(restored.dockEdge(PanelId.playerTracking), PanelDockEdge.right);
  });

  test('dock geometry keeps all four regions disjoint', () {
    final geometry = resolveDockGeometry(
      size: const Size(1200, 800),
      activeEdges: const {
        PanelDockEdge.left,
        PanelDockEdge.right,
        PanelDockEdge.top,
        PanelDockEdge.bottom,
      },
      extents: const DockEdgeExtents(
        left: 240,
        right: 260,
        top: 100,
        bottom: 120,
      ),
      presentationMode: DockPresentationMode.squeeze,
    );

    expect(geometry.centerRect, const Rect.fromLTWH(240, 100, 700, 580));
    expect(geometry.contentRect, geometry.centerRect);
    expect(geometry.leftRect!.overlaps(geometry.topRect!), isFalse);
    expect(geometry.leftRect!.overlaps(geometry.bottomRect!), isFalse);
    expect(geometry.rightRect!.overlaps(geometry.topRect!), isFalse);
    expect(geometry.rightRect!.overlaps(geometry.bottomRect!), isFalse);
  });

  test('dock geometry retains a usable center on constrained screens', () {
    final geometry = resolveDockGeometry(
      size: const Size(400, 300),
      activeEdges: PanelDockEdge.values.toSet()..remove(PanelDockEdge.floating),
      extents: const DockEdgeExtents(
        left: 320,
        right: 320,
        top: 200,
        bottom: 200,
      ),
      presentationMode: DockPresentationMode.overlay,
    );

    expect(geometry.centerRect.width, greaterThanOrEqualTo(220));
    expect(geometry.centerRect.height, greaterThanOrEqualTo(165));
    expect(geometry.contentRect, Offset.zero & const Size(400, 300));
  });
}
