import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/dock_layout_state.dart';
import 'package:flow_lens/services/dock_layout_repository.dart';
import 'package:flow_lens/widgets/dock_layout.dart';
import 'package:flow_lens/widgets/dock_split.dart';
import 'package:flow_lens/widgets/tool_action_grid.dart';

class _Repository implements DockLayoutRepository {
  DockLayoutState state = const DockLayoutState();
  int saves = 0;
  @override
  Future<DockLayoutState> load() async =>
      DockLayoutState.fromJson(state.toJson());
  @override
  Future<void> save(DockLayoutState state) async {
    this.state = state;
    saves++;
  }
}

const ids = [PanelId.quickEvents, PanelId.categories, PanelId.eventsList];

Widget workspace(UIController controller, {bool lanes = false}) => MaterialApp(
  home: Scaffold(
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) => DockLayout(
        uiController: controller,
        panels: [
          for (final id in (lanes ? ids.take(2) : ids))
            DockPanelEntry(
              id: id,
              title: id.name,
              icon: Icons.widgets,
              defaultFloatingPosition: Offset.zero,
              layout: ToolsetLayout.widget(
                preferredWidth: lanes ? 1400 : 200,
                preferredHeight: 180,
              ),
              builder: (_) => Text(id.name),
            ),
        ],
        child: const ColoredBox(key: ValueKey('video'), color: Colors.black),
      ),
    ),
  ),
);

Rect panel(WidgetTester tester, PanelId id) =>
    tester.getRect(find.byKey(ValueKey('workspace-panel-${id.name}')));

void main() {
  for (final edge in [
    PanelDockEdge.left,
    PanelDockEdge.right,
    PanelDockEdge.top,
    PanelDockEdge.bottom,
  ]) {
    testWidgets(
      '$edge shares space between neighbors and restores saved proportions',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository();
        final controller = UIController(repository);
        for (final id in ids) {
          controller.showPanel(id);
          controller.setDockEdge(id, edge);
        }
        await tester.pumpWidget(workspace(controller));
        await tester.pumpAndSettle();
        final horizontal =
            edge == PanelDockEdge.top || edge == PanelDockEdge.bottom;
        double extent(Rect rect) => horizontal ? rect.width : rect.height;
        final before = ids.map((id) => extent(panel(tester, id))).toList();
        final video = tester.getRect(find.byKey(const ValueKey('video')));
        final divider = find.byKey(
          const ValueKey('divider-quickEvents-categories'),
        );
        final saves = repository.saves;
        final gesture = await tester.startGesture(tester.getCenter(divider));
        await gesture.moveBy(
          horizontal ? const Offset(80, 0) : const Offset(0, 80),
        );
        await tester.pump();
        expect(
          repository.saves,
          saves,
          reason: 'Drag previews do not write persistence',
        );
        await gesture.up();
        await tester.pumpAndSettle();
        final after = ids.map((id) => extent(panel(tester, id))).toList();
        expect(after[0], greaterThan(before[0] + 40));
        expect(after[1], lessThan(before[1] - 40));
        expect(after[2], closeTo(before[2], .01));
        expect(
          after.reduce((a, b) => a + b),
          closeTo(before.reduce((a, b) => a + b), .01),
        );
        expect(tester.getRect(find.byKey(const ValueKey('video'))), video);
        expect(repository.saves, saves + 1);

        controller.hidePanel(ids[1]);
        await tester.pumpAndSettle();
        controller.showPanel(ids[1]);
        await tester.pumpAndSettle();
        expect(extent(panel(tester, ids[0])), closeTo(after[0], .01));
        controller.collapsePanel(ids[1]);
        await tester.pumpAndSettle();
        controller.expandPanel(ids[1]);
        await tester.pumpAndSettle();
        expect(extent(panel(tester, ids[0])), closeTo(after[0], .01));

        final restored = UIController(repository);
        await restored.loadDockLayouts();
        await tester.pumpWidget(workspace(restored));
        await tester.pumpAndSettle();
        for (var i = 0; i < ids.length; i++) {
          expect(extent(panel(tester, ids[i])), closeTo(after[i], .01));
        }
        await tester.binding.setSurfaceSize(
          horizontal ? const Size(1500, 900) : const Size(1280, 1100),
        );
        await tester.pumpAndSettle();
        final resized = ids.map((id) => extent(panel(tester, id)) + 8).toList();
        expect(
          resized[0] / resized[1],
          closeTo((after[0] + 8) / (after[1] + 8), .01),
        );

        await tester.drag(
          divider,
          horizontal ? const Offset(5000, 0) : const Offset(0, 5000),
        );
        await tester.pumpAndSettle();
        expect(
          extent(panel(tester, ids[1])),
          greaterThanOrEqualTo(horizontal ? 270 : 98),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        restored.dispose();
      },
    );
  }

  for (final edge in [PanelDockEdge.top, PanelDockEdge.bottom]) {
    testWidgets(
      '$edge stacked rows can share height and reset by double click',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = UIController();
        for (final id in ids.take(2)) {
          controller.showPanel(id);
          controller.setDockEdge(id, edge);
        }
        await tester.pumpWidget(workspace(controller, lanes: true));
        await tester.pumpAndSettle();
        final original = panel(tester, ids[0]);
        final divider = find.byKey(
          const ValueKey('divider-quickEvents-categories'),
        );
        await tester.drag(divider, const Offset(0, 60));
        await tester.pumpAndSettle();
        expect(panel(tester, ids[0]).height, greaterThan(original.height + 30));
        await tester.tap(divider);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(divider);
        await tester.pumpAndSettle();
        expect(panel(tester, ids[0]), original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  test('split allocation honors minimums and fixed collapsed sizes', () {
    final sizes = allocateDockSplit(
      available: 658,
      preferred: [300, 58, 300],
      minimums: [106, 58, 106],
      fixed: [false, true, false],
      fractions: [.01, .1, .89],
    );
    expect(sizes[0], 106);
    expect(sizes[1], 58);
    expect(sizes[2], 494);
  });

  testWidgets('cancelling a divider drag restores sizes without saving', (
    tester,
  ) async {
    final repository = _Repository();
    final controller = UIController(repository);
    for (final id in ids) {
      controller.showPanel(id);
      controller.setDockEdge(id, PanelDockEdge.left);
    }
    await tester.pumpWidget(workspace(controller));
    await tester.pumpAndSettle();
    final before = panel(tester, ids[0]);
    final saves = repository.saves;
    final divider = find.byKey(
      const ValueKey('divider-quickEvents-categories'),
    );
    final gesture = await tester.startGesture(tester.getCenter(divider));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(panel(tester, ids[0]).height, greaterThan(before.height));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(panel(tester, ids[0]), before);
    expect(repository.saves, saves);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'narrowing an action toolset reflows its controls and grows the horizontal dock',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = UIController();
      for (final id in ids.take(2)) {
        controller.showPanel(id);
        controller.setDockEdge(id, PanelDockEdge.top);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => DockLayout(
                uiController: controller,
                panels: [
                  for (final id in ids.take(2))
                    DockPanelEntry(
                      id: id,
                      title: id.name,
                      icon: Icons.widgets,
                      defaultFloatingPosition: Offset.zero,
                      layout: ToolsetLayout.actions(List.filled(9, '')),
                      builder: (_) => ToolActionGrid(
                        title: id.name,
                        layout: ToolsetLayout.actions(List.filled(9, '')),
                        children: List.generate(
                          9,
                          (i) => ToolActionButton(
                            key: ValueKey('${id.name}-$i'),
                            label: '',
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
        ),
      );
      await tester.pumpAndSettle();
      final before = panel(tester, ids[0]);
      await tester.drag(
        find.byKey(const ValueKey('divider-quickEvents-categories')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(panel(tester, ids[0]).height, greaterThan(before.height));
      for (final id in ids.take(2)) {
        final bounds = panel(tester, id);
        for (var i = 0; i < 9; i++) {
          final button = find.byKey(ValueKey('${id.name}-$i'));
          final rect = tester.getRect(button);
          expect(bounds.contains(rect.topLeft), isTrue);
          expect(bounds.contains(rect.bottomRight), isTrue);
          expect(rect.width, greaterThanOrEqualTo(48));
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(button.hitTestable(), findsOneWidget);
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  test(
    'old layouts load automatically and invalid saved splits are ignored',
    () {
      expect(WorkflowDockState.fromJson({}).splits, isEmpty);
      final restored = WorkflowDockState.fromJson({
        'splits': {
          'valid': [2, 3],
          'zero': [0, 1],
          'nan': [double.nan, 2],
          'type': ['a', 1],
          'short': [1],
        },
      });
      expect(restored.splits, {
        'valid': [.4, .6],
      });
    },
  );

  test('sharing is isolated per workflow, presentation and reset undo', () {
    final controller = UIController();
    controller.setDockSplit('group', [1, 3]);
    controller.setMode(AppMode.review);
    expect(controller.dockSplit('group'), isNull);
    controller.setDockSplit('group', [2, 3]);
    controller.togglePresentation();
    controller.setDockSplit('group', [1, 4]);
    controller.togglePresentation();
    expect(controller.dockSplit('group'), [.4, .6]);
    controller.resetLayout();
    expect(controller.dockSplit('group'), isNull);
    controller.undoReset();
    expect(controller.dockSplit('group'), [.4, .6]);
    controller.setMode(AppMode.record);
    expect(controller.dockSplit('group'), [.25, .75]);
    controller.dispose();
  });
}
