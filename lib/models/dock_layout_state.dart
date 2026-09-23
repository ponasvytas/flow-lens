import 'dart:ui';

import 'app_mode.dart';

enum PanelDockEdge { left, right, top, bottom, floating }

enum DockPresentationMode { overlay, squeeze }

class DockPanelState {
  final PanelDockEdge edge;
  final Offset? floatingPosition;
  final Size? floatingSize;
  final bool collapsed;
  final bool? visible;

  const DockPanelState({
    this.edge = PanelDockEdge.floating,
    this.floatingPosition,
    this.floatingSize,
    this.collapsed = false,
    this.visible,
  });

  DockPanelState copyWith({
    PanelDockEdge? edge,
    Offset? floatingPosition,
    Size? floatingSize,
    bool? collapsed,
    bool? visible,
    bool clearVisible = false,
  }) {
    return DockPanelState(
      edge: edge ?? this.edge,
      floatingPosition: floatingPosition ?? this.floatingPosition,
      floatingSize: floatingSize ?? this.floatingSize,
      collapsed: collapsed ?? this.collapsed,
      visible: clearVisible ? null : visible ?? this.visible,
    );
  }

  Map<String, Object?> toJson() => {
    'edge': edge.name,
    if (floatingPosition case final position?)
      'position': {'x': position.dx, 'y': position.dy},
    if (floatingSize case final size?)
      'size': {'width': size.width, 'height': size.height},
    'collapsed': collapsed,
    if (visible != null) 'visible': visible,
  };

  factory DockPanelState.fromJson(Map<String, Object?> json) {
    final position = json['position'];
    final size = json['size'];
    return DockPanelState(
      edge: PanelDockEdge.values.firstWhere(
        (value) => value.name == json['edge'],
        orElse: () => PanelDockEdge.floating,
      ),
      floatingPosition: position is Map
          ? Offset(
              (position['x'] as num?)?.toDouble() ?? 0,
              (position['y'] as num?)?.toDouble() ?? 0,
            )
          : null,
      floatingSize: size is Map
          ? Size(
              (size['width'] as num?)?.toDouble() ?? 0,
              (size['height'] as num?)?.toDouble() ?? 0,
            )
          : null,
      collapsed: json['collapsed'] as bool? ?? false,
      visible: json['visible'] as bool?,
    );
  }
}

class DockEdgeExtents {
  final double left;
  final double right;
  final double top;
  final double bottom;

  const DockEdgeExtents({
    this.left = 280,
    this.right = 280,
    this.top = 112,
    this.bottom = 112,
  });

  double forEdge(PanelDockEdge edge) => switch (edge) {
    PanelDockEdge.left => left,
    PanelDockEdge.right => right,
    PanelDockEdge.top => top,
    PanelDockEdge.bottom => bottom,
    PanelDockEdge.floating => 0,
  };

  DockEdgeExtents withEdge(PanelDockEdge edge, double extent) => switch (edge) {
    PanelDockEdge.left => copyWith(left: extent),
    PanelDockEdge.right => copyWith(right: extent),
    PanelDockEdge.top => copyWith(top: extent),
    PanelDockEdge.bottom => copyWith(bottom: extent),
    PanelDockEdge.floating => this,
  };

  DockEdgeExtents copyWith({
    double? left,
    double? right,
    double? top,
    double? bottom,
  }) => DockEdgeExtents(
    left: left ?? this.left,
    right: right ?? this.right,
    top: top ?? this.top,
    bottom: bottom ?? this.bottom,
  );

  Map<String, Object?> toJson() => {
    'left': left,
    'right': right,
    'top': top,
    'bottom': bottom,
  };

  factory DockEdgeExtents.fromJson(Map<String, Object?> json) =>
      DockEdgeExtents(
        left: (json['left'] as num?)?.toDouble() ?? 280,
        right: (json['right'] as num?)?.toDouble() ?? 280,
        top: (json['top'] as num?)?.toDouble() ?? 112,
        bottom: (json['bottom'] as num?)?.toDouble() ?? 112,
      );
}

class WorkflowDockState {
  final DockPresentationMode presentationMode;
  final DockEdgeExtents extents;
  final Map<PanelId, DockPanelState> panels;

  const WorkflowDockState({
    this.presentationMode = DockPresentationMode.overlay,
    this.extents = const DockEdgeExtents(),
    this.panels = const {},
  });

  DockPanelState panel(PanelId id) => panels[id] ?? const DockPanelState();

  WorkflowDockState copyWith({
    DockPresentationMode? presentationMode,
    DockEdgeExtents? extents,
    Map<PanelId, DockPanelState>? panels,
  }) => WorkflowDockState(
    presentationMode: presentationMode ?? this.presentationMode,
    extents: extents ?? this.extents,
    panels: panels ?? this.panels,
  );

  WorkflowDockState withPanel(PanelId id, DockPanelState state) => copyWith(
    panels: Map<PanelId, DockPanelState>.unmodifiable({...panels, id: state}),
  );

  Map<String, Object?> toJson() => {
    'presentationMode': presentationMode.name,
    'extents': extents.toJson(),
    'panels': {
      for (final entry in panels.entries) entry.key.name: entry.value.toJson(),
    },
  };

  factory WorkflowDockState.fromJson(Map<String, Object?> json) {
    final rawPanels = json['panels'];
    final panels = <PanelId, DockPanelState>{};
    if (rawPanels is Map) {
      for (final entry in rawPanels.entries) {
        final id = PanelId.values
            .where((value) => value.name == entry.key)
            .firstOrNull;
        if (id != null && entry.value is Map) {
          panels[id] = DockPanelState.fromJson(
            Map<String, Object?>.from(entry.value as Map),
          );
        }
      }
    }
    final rawExtents = json['extents'];
    return WorkflowDockState(
      presentationMode: DockPresentationMode.values.firstWhere(
        (value) => value.name == json['presentationMode'],
        orElse: () => DockPresentationMode.overlay,
      ),
      extents: rawExtents is Map
          ? DockEdgeExtents.fromJson(Map<String, Object?>.from(rawExtents))
          : const DockEdgeExtents(),
      panels: Map<PanelId, DockPanelState>.unmodifiable(panels),
    );
  }
}

class DockLayoutState {
  final Map<AppMode, WorkflowDockState> workflows;

  const DockLayoutState({this.workflows = const {}});

  WorkflowDockState workflow(AppMode mode) =>
      workflows[mode] ?? const WorkflowDockState();

  DockLayoutState withWorkflow(AppMode mode, WorkflowDockState state) =>
      DockLayoutState(
        workflows: Map<AppMode, WorkflowDockState>.unmodifiable({
          ...workflows,
          mode: state,
        }),
      );

  Map<String, Object?> toJson() => {
    'version': 1,
    'workflows': {
      for (final entry in workflows.entries)
        entry.key.name: entry.value.toJson(),
    },
  };

  factory DockLayoutState.fromJson(Map<String, Object?> json) {
    final rawWorkflows = json['workflows'];
    final workflows = <AppMode, WorkflowDockState>{};
    if (rawWorkflows is Map) {
      for (final entry in rawWorkflows.entries) {
        final mode = AppMode.values
            .where((value) => value.name == entry.key)
            .firstOrNull;
        if (mode != null && entry.value is Map) {
          workflows[mode] = WorkflowDockState.fromJson(
            Map<String, Object?>.from(entry.value as Map),
          );
        }
      }
    }
    return DockLayoutState(
      workflows: Map<AppMode, WorkflowDockState>.unmodifiable(workflows),
    );
  }
}
