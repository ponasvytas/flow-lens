import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../models/app_mode.dart';
import '../widgets/dockable_panel.dart';

/// Drives which mode is active and which panels are visible / collapsed.
///
/// Each [AppMode] has a default visibility for each [PanelId]. Users can
/// temporarily override visibility for the current mode; overrides reset when
/// the mode changes.
///
/// Also owns dock-edge and floating-position state for every panel so that
/// the [DockLayout] widget can arrange panels without each panel managing its
/// own position.
class UIController extends ChangeNotifier {
  AppMode _currentMode = AppMode.record;

  // user overrides: null = use mode default, true/false = explicit override
  final Map<PanelId, bool?> _visibilityOverrides = {};
  final Map<PanelId, bool> _collapsed = {};

  // Dock edge per panel (persists across rebuilds, resets on mode change)
  final Map<PanelId, PanelDockEdge> _dockEdges = {};

  // Floating-mode position per panel (persists until mode change)
  final Map<PanelId, Offset> _floatingPositions = {};

  AppMode get currentMode => _currentMode;

  // ---------------------------------------------------------------------------
  // Default visibility table
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Whether the panel should be rendered (visible + not hidden by mode)
  bool panelVisible(PanelId id) {
    final override = _visibilityOverrides[id];
    if (override != null) return override;
    return _modeDefaults[_currentMode]![id] ?? false;
  }

  /// Whether the panel is collapsed to its title strip
  bool panelCollapsed(PanelId id) => _collapsed[id] ?? false;

  /// Current dock edge for a panel (defaults to floating)
  PanelDockEdge dockEdge(PanelId id) =>
      _dockEdges[id] ?? PanelDockEdge.floating;

  /// Current floating position for a panel (falls back to [fallback])
  Offset floatingPosition(PanelId id, Offset fallback) =>
      _floatingPositions[id] ?? fallback;

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  void setMode(AppMode mode) {
    if (_currentMode == mode) return;
    _currentMode = mode;
    _visibilityOverrides.clear(); // reset user overrides on mode change
    _collapsed.clear();
    _dockEdges.clear();
    _floatingPositions.clear();
    notifyListeners();
  }

  void cycleMode() {
    final modes = AppMode.values;
    final nextIndex = (modes.indexOf(_currentMode) + 1) % modes.length;
    setMode(modes[nextIndex]);
  }

  /// Show a panel (overrides the mode default for this session)
  void showPanel(PanelId id) {
    _visibilityOverrides[id] = true;
    notifyListeners();
  }

  /// Hide a panel (overrides the mode default for this session)
  void hidePanel(PanelId id) {
    _visibilityOverrides[id] = false;
    notifyListeners();
  }

  /// Toggle visibility, respecting overrides and mode defaults
  void togglePanel(PanelId id) {
    if (panelVisible(id)) {
      _visibilityOverrides[id] = false;
    } else {
      _visibilityOverrides[id] = true;
    }
    notifyListeners();
  }

  void collapsePanel(PanelId id) {
    _collapsed[id] = true;
    notifyListeners();
  }

  void expandPanel(PanelId id) {
    _collapsed[id] = false;
    notifyListeners();
  }

  void toggleCollapsed(PanelId id) {
    _collapsed[id] = !(_collapsed[id] ?? false);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Dock edge & floating position
  // ---------------------------------------------------------------------------

  void setDockEdge(PanelId id, PanelDockEdge edge) {
    if (_dockEdges[id] != edge) {
      _dockEdges[id] = edge;
      notifyListeners();
    }
  }

  /// Update floating position silently (called during drag, no rebuild needed).
  void setFloatingPositionSilent(PanelId id, Offset pos) {
    _floatingPositions[id] = pos;
  }

  /// Update floating position and notify listeners (e.g. after drag end).
  void setFloatingPosition(PanelId id, Offset pos) {
    _floatingPositions[id] = pos;
    notifyListeners();
  }
}
