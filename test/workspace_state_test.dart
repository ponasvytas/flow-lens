import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/ui_controller.dart';
import 'package:flow_lens/controllers/event_entry_controller.dart';
import 'package:flow_lens/controllers/events_controller.dart';
import 'package:flow_lens/models/app_mode.dart';
import 'package:flow_lens/models/dock_layout_state.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/services/dock_layout_repository.dart';

class _Layouts implements DockLayoutRepository {
  DockLayoutState state;
  _Layouts(this.state);
  @override
  Future<DockLayoutState> load() async => state;
  @override
  Future<void> save(DockLayoutState value) async => state = value;
}

void main() {
  test('legacy quick layout migrates independently from Categories', () async {
    final repository = _Layouts(
      DockLayoutState.fromJson({
        'version': 1,
        'workflows': {
          'record': {
            'panels': {
              'eventButtons': {
                'edge': 'bottom',
                'visible': false,
                'collapsed': true,
                'position': {'x': 120, 'y': 80},
                'size': {'width': 360, 'height': 420},
              },
            },
          },
        },
      }),
    );
    final ui = UIController(repository);
    await ui.loadDockLayouts();
    expect(ui.panelVisible(PanelId.quickEvents), isFalse);
    expect(ui.dockEdge(PanelId.quickEvents), PanelDockEdge.bottom);
    expect(ui.panelVisible(PanelId.categories), isFalse);
    ui.showPanel(PanelId.categories);
    expect(ui.panelVisible(PanelId.quickEvents), isFalse);
    ui.showPanel(PanelId.quickEvents);
    expect(ui.panelCollapsed(PanelId.quickEvents), isFalse);
    expect(
      ui.floatingPosition(PanelId.quickEvents, Offset.zero),
      const Offset(120, 80),
    );
    await Future<void>.delayed(Duration.zero);
    final restored = UIController(repository);
    await restored.loadDockLayouts();
    expect(restored.panelVisible(PanelId.categories), isTrue);
    expect(
      restored.floatingSize(PanelId.quickEvents, Size.zero),
      const Size(360, 420),
    );
    ui.dispose();
    restored.dispose();
  });

  test('presentation changes never replace the saved review layout', () async {
    final repository = _Layouts(const DockLayoutState());
    final ui = UIController(repository)..initializeRecommendedLayouts();
    ui.setMode(AppMode.review);
    ui.showPanel(PanelId.eventsList);
    ui.setDockEdge(PanelId.eventsList, PanelDockEdge.left);
    await Future<void>.delayed(Duration.zero);
    final before = ui.layoutState.toJson();
    ui.togglePresentation();
    expect(ui.isPresenting, isTrue);
    expect(ui.panelVisible(PanelId.eventsList), isFalse);
    ui.hidePanel(PanelId.drawingTools);
    ui.setDockExtent(PanelDockEdge.top, 160);
    await Future<void>.delayed(Duration.zero);
    expect(repository.state.toJson(), before);
    ui.togglePresentation();
    expect(ui.panelVisible(PanelId.eventsList), isTrue);
    expect(ui.dockEdge(PanelId.eventsList), PanelDockEdge.left);
    expect(ui.layoutState.toJson(), before);
    ui.togglePresentation();
    ui.setMode(AppMode.record);
    expect(ui.isPresenting, isFalse);
    ui.showPanel(PanelId.drawingTools);
    expect(ui.panelVisible(PanelId.drawingTools), isFalse);
    ui.dispose();
  });

  test('reset can be undone without changing another workflow', () {
    final ui = UIController()..initializeRecommendedLayouts();
    ui.hidePanel(PanelId.quickEvents);
    ui.showPanel(PanelId.categories);
    final before = ui.layoutState.toJson();
    ui.resetLayout();
    expect(ui.panelVisible(PanelId.quickEvents), isTrue);
    ui.undoReset();
    expect(ui.layoutState.toJson(), before);
    ui.dispose();
  });

  test(
    'draft survives navigation, quick capture, and entry visibility changes',
    () {
      final events = EventsController();
      final entry = EventEntryController();
      final draft = GameEvent(
        id: 'draft',
        sportId: 'hockey',
        categoryId: 'shot',
        label: 'Shot',
        timestamp: const Duration(seconds: 12),
      );
      final earlier = draft.copyWith(id: 'earlier', eventTypeId: 'shot_saved');
      events.addEvent(earlier);
      entry.beginDraft(draft);
      entry.toggle();
      entry.exit();
      events.selectEvent(earlier);
      events.addEvent(earlier.copyWith(id: 'quick'));
      expect(entry.draft, same(draft));
      expect(entry.beginDraft(earlier), isFalse);
      expect(entry.commitDraft(events), isNull);
      entry.updateDraft(
        draft.copyWith(eventTypeId: 'shot_saved', detail: 'Saved'),
      );
      final saved = entry.commitDraft(events)!;
      expect(saved.timestamp, const Duration(seconds: 12));
      expect(events.allEvents.length, 3);
      expect(entry.draft, isNull);
      entry.beginDraft(saved);
      entry.updateDraft(saved.copyWith(grade: EventGrade.negative));
      entry.cancelDraft();
      expect(events.allEvents.last.grade, isNull);
      expect(events.activeEvent, same(earlier));
      entry.dispose();
      events.dispose();
    },
  );
}
