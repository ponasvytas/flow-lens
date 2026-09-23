import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/app_mode.dart';
import '../models/dock_layout_state.dart';
import '../services/dock_layout_repository.dart';

/// Owns workflow selection and the persisted layout of every dockable panel.
class UIController extends ChangeNotifier {
  final DockLayoutRepository? _repository;
  AppMode _currentMode = AppMode.record;
  DockLayoutState _layoutState = const DockLayoutState();
  Future<void> _saveChain = Future.value();

  UIController([this._repository]);

  AppMode get currentMode => _currentMode;
  DockLayoutState get layoutState => _layoutState;

  static const Map<AppMode, Map<PanelId, bool>> _modeDefaults = {
    AppMode.record: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: false,
      PanelId.eventButtons: true,
      PanelId.eventNavigation: false,
      PanelId.playerTracking: false,
      PanelId.shortcuts: false,
    },
    AppMode.review: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: true,
      PanelId.eventButtons: false,
      PanelId.eventNavigation: true,
      PanelId.playerTracking: false,
      PanelId.shortcuts: false,
    },
    AppMode.tracking: {
      PanelId.playbackControls: true,
      PanelId.drawingTools: false,
      PanelId.eventButtons: false,
      PanelId.eventNavigation: false,
      PanelId.playerTracking: true,
      PanelId.shortcuts: false,
    },
  };

  WorkflowDockState get _workflow => _layoutState.workflow(_currentMode);
  DockPanelState _panel(PanelId id) => _workflow.panel(id);

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

  void resetLayout() => _updateWorkflow(_recommended(_currentMode));

  WorkflowDockState _recommended(AppMode mode) => WorkflowDockState(
    presentationMode: DockPresentationMode.squeeze,
    extents: DockEdgeExtents(
      left: 112,
      right: mode == AppMode.tracking ? 360 : 224,
    ),
    panels: {
      PanelId.playbackControls: const DockPanelState(edge: PanelDockEdge.left),
      PanelId.eventButtons: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.eventNavigation: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.playerTracking: const DockPanelState(edge: PanelDockEdge.right),
      PanelId.drawingTools: const DockPanelState(
        edge: PanelDockEdge.right,
        collapsed: true,
      ),
    },
  );

  bool panelVisible(PanelId id) =>
      _panel(id).visible ?? _modeDefaults[_currentMode]?[id] ?? false;

  bool panelCollapsed(PanelId id) => _panel(id).collapsed;

  PanelDockEdge dockEdge(PanelId id) => _panel(id).edge;

  Offset floatingPosition(PanelId id, Offset fallback) =>
      _panel(id).floatingPosition ?? fallback;

  Size floatingSize(PanelId id, Size fallback) =>
      _panel(id).floatingSize ?? fallback;

  DockPresentationMode get dockPresentationMode => _workflow.presentationMode;

  DockEdgeExtents get dockExtents => _workflow.extents;

  double dockExtent(PanelDockEdge edge) => _workflow.extents.forEdge(edge);

  void setMode(AppMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    notifyListeners();
  }

  void cycleMode() {
    final modes = AppMode.values;
    setMode(modes[(modes.indexOf(_currentMode) + 1) % modes.length]);
  }

  void showPanel(PanelId id) =>
      _updatePanel(id, (panel) => panel.copyWith(visible: true));

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
      _updatePanel(id, (panel) => panel.copyWith(edge: edge));

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
