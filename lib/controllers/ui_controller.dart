import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/app_mode.dart';
import '../models/dock_layout_state.dart';
import '../models/workspace_tool.dart';
import '../services/dock_layout_repository.dart';

/// Owns workflow selection and the persisted layout of every dockable panel.
class UIController extends ChangeNotifier {
  final DockLayoutRepository? _repository;
  AppMode _currentMode = AppMode.record;
  DockLayoutState _layoutState = const DockLayoutState();
  Future<void> _saveChain = Future.value();
  WorkflowDockState? _presentation;
  WorkflowDockState? _beforeReset;

  UIController([this._repository]);

  AppMode get currentMode => _currentMode;
  DockLayoutState get layoutState => _layoutState;

  static const Map<AppMode, Map<PanelId, bool>> _modeDefaults = {
    AppMode.record: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: false,
      PanelId.quickEvents: true,
      PanelId.eventNavigation: false,
      PanelId.playerTracking: false,
      PanelId.shortcuts: false,
    },
    AppMode.review: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: true,
      PanelId.quickEvents: false,
      PanelId.eventNavigation: true,
      PanelId.playerTracking: false,
      PanelId.shortcuts: false,
    },
    AppMode.tracking: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: false,
      PanelId.quickEvents: false,
      PanelId.eventNavigation: false,
      PanelId.playerTracking: true,
      PanelId.shortcuts: false,
    },
  };

  bool get isPresenting => _presentation != null;
  bool get canUndoReset => _beforeReset != null;
  WorkflowDockState get _workflow =>
      _presentation ?? _layoutState.workflow(_currentMode);
  DockPanelState _panel(PanelId id) =>
      _workflow.panels[id] ??
      (id == PanelId.categories || id == PanelId.eventsList
          ? const DockPanelState(edge: PanelDockEdge.right, visible: false)
          : const DockPanelState());

  Future<void> loadDockLayouts() async {
    final repository = _repository;
    if (repository == null) return;
    _layoutState = await repository.load();
    notifyListeners();
  }

  void initializeRecommendedLayouts() {
    for (final mode in AppMode.values) {
      if (!_layoutState.workflows.containsKey(mode)) {
        _layoutState = _layoutState.withWorkflow(mode, _recommended(mode));
      }
    }
    notifyListeners();
  }

  void resetLayout() {
    _beforeReset = _workflow;
    _updateWorkflow(_recommended(_currentMode));
  }

  void undoReset() {
    final previous = _beforeReset;
    if (previous == null) return;
    _beforeReset = null;
    _updateWorkflow(previous);
  }

  void setFullTagging(bool full) {
    if (_currentMode != AppMode.record) return;
    _updateWorkflow(
      _workflow
          .withPanel(
            PanelId.categories,
            _panel(
              PanelId.categories,
            ).copyWith(visible: full, collapsed: false),
          )
          .withPanel(
            PanelId.quickEvents,
            _panel(
              PanelId.quickEvents,
            ).copyWith(visible: !full, collapsed: false),
          ),
    );
  }

  void togglePresentation() {
    if (_currentMode != AppMode.review) return;
    if (_presentation != null) {
      _presentation = null;
    } else {
      _presentation = WorkflowDockState(
        presentationMode: DockPresentationMode.squeeze,
        extents: const DockEdgeExtents(top: 96, bottom: 112),
        panels: {
          for (final tool in WorkspaceTool.all)
            tool.id: _panel(tool.id).copyWith(visible: false),
          PanelId.playbackControls: const DockPanelState(
            edge: PanelDockEdge.bottom,
            visible: true,
          ),
          PanelId.eventNavigation: const DockPanelState(
            edge: PanelDockEdge.bottom,
            visible: true,
          ),
          PanelId.drawingTools: const DockPanelState(
            edge: PanelDockEdge.top,
            visible: true,
          ),
        },
      );
    }
    _beforeReset = null;
    notifyListeners();
  }

  WorkflowDockState _recommended(AppMode mode) => WorkflowDockState(
    presentationMode: DockPresentationMode.squeeze,
    extents: DockEdgeExtents(
      left: 112,
      right: mode == AppMode.tracking ? 360 : 224,
    ),
    panels: {
      PanelId.playbackControls: const DockPanelState(edge: PanelDockEdge.left),
      PanelId.quickEvents: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.categories: const DockPanelState(
        edge: PanelDockEdge.right,
        visible: false,
      ),
      PanelId.eventsList: const DockPanelState(
        edge: PanelDockEdge.right,
        visible: false,
      ),
      PanelId.eventNavigation: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.playerTracking: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.drawingTools: const DockPanelState(
        edge: PanelDockEdge.right,
        collapsed: true,
      ),
    },
  );

  bool panelVisible(PanelId id) =>
      WorkspaceTool.available(id, _currentMode) &&
      (_panel(id).visible ?? _modeDefaults[_currentMode]?[id] ?? false);

  bool panelCollapsed(PanelId id) => _panel(id).collapsed;

  PanelDockEdge dockEdge(PanelId id) => _panel(id).edge;

  Offset floatingPosition(PanelId id, Offset fallback) =>
      _panel(id).floatingPosition ?? fallback;

  Size floatingSize(PanelId id, Size fallback) =>
      _panel(id).floatingSize ?? fallback;

  DockPresentationMode get dockPresentationMode => _workflow.presentationMode;

  DockEdgeExtents get dockExtents => _workflow.extents;

  double dockExtent(PanelDockEdge edge) => _workflow.extents.forEdge(edge);

  List<double>? dockSplit(String group) => _workflow.splits[group];

  void setDockSplit(String group, List<double>? sizes) {
    final splits = {..._workflow.splits};
    if (sizes == null) {
      if (splits.remove(group) == null) return;
    } else {
      if (sizes.length < 2 || sizes.any((v) => !v.isFinite || v <= 0)) return;
      final total = sizes.fold(0.0, (sum, size) => sum + size);
      if (!total.isFinite) return;
      splits[group] = List.unmodifiable(sizes.map((size) => size / total));
    }
    _updateWorkflow(_workflow.copyWith(splits: Map.unmodifiable(splits)));
  }

  void setMode(AppMode mode) {
    if (_currentMode == mode) return;
    _presentation = null;
    _beforeReset = null;
    _currentMode = mode;
    notifyListeners();
  }

  void cycleMode() {
    final modes = AppMode.values;
    setMode(modes[(modes.indexOf(_currentMode) + 1) % modes.length]);
  }

  void showPanel(PanelId id) {
    if (!WorkspaceTool.available(id, _currentMode)) return;
    _updatePanel(
      id,
      (panel) => panel.copyWith(visible: true, collapsed: false),
    );
  }

  void hidePanel(PanelId id) =>
      _updatePanel(id, (panel) => panel.copyWith(visible: false));

  void togglePanel(PanelId id) =>
      panelVisible(id) ? hidePanel(id) : showPanel(id);

  void collapsePanel(PanelId id) =>
      _updatePanel(id, (panel) => panel.copyWith(collapsed: true));

  void expandPanel(PanelId id) =>
      _updatePanel(id, (panel) => panel.copyWith(collapsed: false));

  void toggleCollapsed(PanelId id) =>
      _updatePanel(id, (panel) => panel.copyWith(collapsed: !panel.collapsed));

  void setDockEdge(PanelId id, PanelDockEdge edge) =>
      _updatePanel(id, (panel) => panel.copyWith(edge: edge, collapsed: false));

  void setFloatingPosition(PanelId id, Offset position) =>
      _updatePanel(id, (panel) => panel.copyWith(floatingPosition: position));

  void setFloatingSize(PanelId id, Size size) =>
      _updatePanel(id, (panel) => panel.copyWith(floatingSize: size));

  void setDockExtent(PanelDockEdge edge, double extent) {
    if (edge == PanelDockEdge.floating || dockExtent(edge) == extent) return;
    _updateWorkflow(
      _workflow.copyWith(extents: _workflow.extents.withEdge(edge, extent)),
    );
  }

  void setDockPresentationMode(DockPresentationMode mode) {
    if (_workflow.presentationMode == mode) return;
    _updateWorkflow(_workflow.copyWith(presentationMode: mode));
  }

  void _updatePanel(
    PanelId id,
    DockPanelState Function(DockPanelState panel) update,
  ) {
    final current = _panel(id);
    final next = update(current);
    if (identical(current, next)) return;
    _updateWorkflow(_workflow.withPanel(id, next));
  }

  void _updateWorkflow(WorkflowDockState workflow) {
    if (_presentation != null) {
      _presentation = workflow;
      notifyListeners();
      return;
    }
    _layoutState = _layoutState.withWorkflow(_currentMode, workflow);
    _queueSave();
    notifyListeners();
  }

  void _queueSave() {
    final repository = _repository;
    if (repository == null) return;
    final snapshot = _layoutState;
    _saveChain = _saveChain.then((_) => repository.save(snapshot));
  }
}
