import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/ui_controller.dart';
import '../models/app_mode.dart';
import 'dockable_panel.dart';

const double kDockResizeHandleSize = 8;
const double kDockMinSideExtent = 180;
const double kDockMinHorizontalExtent = 88;
const double kDockMinCenterWidth = 320;
const double kDockMinCenterHeight = 220;

class DockPanelEntry {
  final PanelId id;
  final String title;
  final IconData icon;
  final Offset defaultFloatingPosition;
  final Size defaultFloatingSize;
  final double horizontalDockWidth;
  final Object? contentRevision;
  final Widget Function(PanelDockEdge dockEdge) builder;

  const DockPanelEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.defaultFloatingPosition,
    required this.builder,
    this.defaultFloatingSize = const Size(300, 240),
    this.horizontalDockWidth = 360,
    this.contentRevision,
  });
}

class DockGeometry {
  final Rect contentRect;
  final Rect centerRect;
  final Rect? leftRect;
  final Rect? rightRect;
  final Rect? topRect;
  final Rect? bottomRect;

  const DockGeometry({
    required this.contentRect,
    required this.centerRect,
    this.leftRect,
    this.rightRect,
    this.topRect,
    this.bottomRect,
  });
}

DockGeometry resolveDockGeometry({
  required Size size,
  required Set<PanelDockEdge> activeEdges,
  required DockEdgeExtents extents,
  required DockPresentationMode presentationMode,
}) {
  final horizontal = _fitPair(
    total: size.width,
    minimumCenter: kDockMinCenterWidth,
    first: activeEdges.contains(PanelDockEdge.left) ? extents.left : 0,
    second: activeEdges.contains(PanelDockEdge.right) ? extents.right : 0,
    minimumExtent: kDockMinSideExtent,
  );
  final vertical = _fitPair(
    total: size.height,
    minimumCenter: kDockMinCenterHeight,
    first: activeEdges.contains(PanelDockEdge.top) ? extents.top : 0,
    second: activeEdges.contains(PanelDockEdge.bottom) ? extents.bottom : 0,
    minimumExtent: kDockMinHorizontalExtent,
  );
  final left = horizontal.$1;
  final right = horizontal.$2;
  final top = vertical.$1;
  final bottom = vertical.$2;
  final center = Rect.fromLTWH(
    left,
    top,
    math.max(0, size.width - left - right),
    math.max(0, size.height - top - bottom),
  );
  return DockGeometry(
    centerRect: center,
    contentRect: presentationMode == DockPresentationMode.squeeze
        ? center
        : Offset.zero & size,
    topRect: top > 0 ? Rect.fromLTWH(0, 0, size.width, top) : null,
    bottomRect: bottom > 0
        ? Rect.fromLTWH(0, size.height - bottom, size.width, bottom)
        : null,
    leftRect: left > 0 ? Rect.fromLTWH(0, top, left, center.height) : null,
    rightRect: right > 0
        ? Rect.fromLTWH(size.width - right, top, right, center.height)
        : null,
  );
}

(double, double) _fitPair({
  required double total,
  required double minimumCenter,
  required double first,
  required double second,
  required double minimumExtent,
}) {
  final center = math.min(minimumCenter, total * 0.55);
  final available = math.max(0.0, total - center);
  var fittedFirst = first > 0 ? math.max(first, minimumExtent) : 0.0;
  var fittedSecond = second > 0 ? math.max(second, minimumExtent) : 0.0;
  final requested = fittedFirst + fittedSecond;
  if (requested > available && requested > 0) {
    final scale = available / requested;
    fittedFirst *= scale;
    fittedSecond *= scale;
  }
  return (fittedFirst, fittedSecond);
}

class DockLayout extends StatefulWidget {
  final UIController uiController;
  final List<DockPanelEntry> panels;
  final Widget child;

  const DockLayout({
    required this.uiController,
    required this.panels,
    this.child = const SizedBox.expand(),
    super.key,
  });

  @override
  State<DockLayout> createState() => _DockLayoutState();
}

class _DockLayoutState extends State<DockLayout> {
  final Map<PanelId, Offset> _dragPositions = {};
  final Map<PanelId, Size> _dragSizes = {};
  final Map<(PanelId, PanelDockEdge, Object?), Widget> _panelChildren = {};
  DockEdgeExtents? _resizingExtents;

  @override
  void didUpdateWidget(DockLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.panels.map((entry) => entry.id).toSet();
    final revisions = {
      for (final entry in widget.panels) entry.id: entry.contentRevision,
    };
    _panelChildren.removeWhere(
      (key, child) => !ids.contains(key.$1) || revisions[key.$1] != key.$3,
    );
    _dragPositions.removeWhere((id, position) => !ids.contains(id));
    _dragSizes.removeWhere((id, size) => !ids.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final groups = <PanelDockEdge, List<DockPanelEntry>>{};
        for (final entry in widget.panels) {
          if (!widget.uiController.panelVisible(entry.id)) continue;
          groups
              .putIfAbsent(widget.uiController.dockEdge(entry.id), () => [])
              .add(entry);
        }
        final activeEdges = groups.keys
            .where((edge) => edge != PanelDockEdge.floating)
            .toSet();
        final geometry = resolveDockGeometry(
          size: size,
          activeEdges: activeEdges,
          extents: _resizingExtents ?? widget.uiController.dockExtents,
          presentationMode: widget.uiController.dockPresentationMode,
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fromRect(
              rect: geometry.contentRect,
              child: widget.child,
            ),
            if (geometry.topRect case final rect?)
              _buildDockRegion(
                PanelDockEdge.top,
                rect,
                groups[PanelDockEdge.top]!,
                size,
              ),
            if (geometry.bottomRect case final rect?)
              _buildDockRegion(
                PanelDockEdge.bottom,
                rect,
                groups[PanelDockEdge.bottom]!,
                size,
              ),
            if (geometry.leftRect case final rect?)
              _buildDockRegion(
                PanelDockEdge.left,
                rect,
                groups[PanelDockEdge.left]!,
                size,
              ),
            if (geometry.rightRect case final rect?)
              _buildDockRegion(
                PanelDockEdge.right,
                rect,
                groups[PanelDockEdge.right]!,
                size,
              ),
            for (final entry in groups[PanelDockEdge.floating] ?? const [])
              _buildFloatingPanel(entry, size),
          ],
        );
      },
    );
  }

  Widget _buildDockRegion(
    PanelDockEdge edge,
    Rect rect,
    List<DockPanelEntry> entries,
    Size workspaceSize,
  ) {
    final horizontal =
        edge == PanelDockEdge.top || edge == PanelDockEdge.bottom;
    final panels = [
      for (final entry in entries)
        Padding(
          padding: const EdgeInsets.all(4),
          child: horizontal
              ? SizedBox(
                  width: math.min(
                    entry.horizontalDockWidth,
                    workspaceSize.width,
                  ),
                  height: math.max(0, rect.height - 8),
                  child: _wrapPanel(entry, edge, workspaceSize),
                )
              : SizedBox(
                  width: math.max(0, rect.width - 8),
                  child: _wrapPanel(entry, edge, workspaceSize),
                ),
        ),
    ];
    final content = horizontal
        ? ListView(scrollDirection: Axis.horizontal, children: panels)
        : ListView(children: panels);
    return Positioned.fromRect(
      rect: rect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF101016).withValues(alpha: 0.94),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: content),
            _buildResizeHandle(edge),
          ],
        ),
      ),
    );
  }

  Widget _buildResizeHandle(PanelDockEdge edge) {
    final vertical = edge == PanelDockEdge.left || edge == PanelDockEdge.right;
    return Positioned(
      left: edge == PanelDockEdge.right
          ? 0
          : vertical
          ? null
          : 0,
      right: edge == PanelDockEdge.left
          ? 0
          : vertical
          ? null
          : 0,
      top: edge == PanelDockEdge.bottom
          ? 0
          : vertical
          ? 0
          : null,
      bottom: edge == PanelDockEdge.top
          ? 0
          : vertical
          ? 0
          : null,
      width: vertical ? kDockResizeHandleSize : null,
      height: vertical ? null : kDockResizeHandleSize,
      child: MouseRegion(
        key: ValueKey('dock-resize-${edge.name}'),
        cursor: vertical
            ? SystemMouseCursors.resizeColumn
            : SystemMouseCursors.resizeRow,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => _resizeDock(edge, details.delta),
          onPanEnd: (_) => _finishDockResize(edge),
          child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
    );
  }

  void _resizeDock(PanelDockEdge edge, Offset delta) {
    final current = _resizingExtents ?? widget.uiController.dockExtents;
    final change = switch (edge) {
      PanelDockEdge.left => delta.dx,
      PanelDockEdge.right => -delta.dx,
      PanelDockEdge.top => delta.dy,
      PanelDockEdge.bottom => -delta.dy,
      PanelDockEdge.floating => 0.0,
    };
    final minimum = edge == PanelDockEdge.left || edge == PanelDockEdge.right
        ? kDockMinSideExtent
        : kDockMinHorizontalExtent;
    setState(() {
      _resizingExtents = current.withEdge(
        edge,
        math.max(minimum, current.forEdge(edge) + change),
      );
    });
  }

  void _finishDockResize(PanelDockEdge edge) {
    final extents = _resizingExtents;
    if (extents == null) return;
    setState(() => _resizingExtents = null);
    widget.uiController.setDockExtent(edge, extents.forEdge(edge));
  }

  Widget _buildFloatingPanel(DockPanelEntry entry, Size workspaceSize) {
    final collapsed = widget.uiController.panelCollapsed(entry.id);
    final size =
        _dragSizes[entry.id] ??
        widget.uiController.floatingSize(entry.id, entry.defaultFloatingSize);
    final clampedSize = Size(
      size.width.clamp(
        kPanelFloatingMinWidth,
        math.max(kPanelFloatingMinWidth, workspaceSize.width),
      ),
      size.height.clamp(
        kPanelTitleStripHeight,
        math.max(kPanelTitleStripHeight, workspaceSize.height),
      ),
    );
    final requestedPosition =
        _dragPositions[entry.id] ??
        widget.uiController.floatingPosition(
          entry.id,
          entry.defaultFloatingPosition,
        );
    final position = _clampPosition(
      requestedPosition,
      collapsed ? Size(clampedSize.width, kPanelTitleStripHeight) : clampedSize,
      workspaceSize,
    );
    final displayedHeight = collapsed
        ? kPanelTitleStripHeight
        : clampedSize.height;
    return Positioned(
      left: position.dx,
      top: position.dy,
      width: clampedSize.width,
      height: displayedHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: _wrapPanel(
              entry,
              PanelDockEdge.floating,
              workspaceSize,
              onDragUpdate: (details) => setState(
                () => _dragPositions[entry.id] = position + details.delta,
              ),
              onDragEnd: (_) =>
                  _finishFloatingDrag(entry, clampedSize, workspaceSize),
            ),
          ),
          if (!collapsed)
            Positioned(
              right: 0,
              bottom: 0,
              width: 22,
              height: 22,
              child: MouseRegion(
                key: ValueKey('floating-resize-${entry.id.name}'),
                cursor: SystemMouseCursors.resizeDownRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) => setState(() {
                    _dragSizes[entry.id] = Size(
                      math.max(
                        kPanelFloatingMinWidth,
                        clampedSize.width + details.delta.dx,
                      ),
                      math.max(96, clampedSize.height + details.delta.dy),
                    );
                  }),
                  onPanEnd: (_) => _finishFloatingResize(entry, workspaceSize),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(
                      Icons.drag_handle,
                      size: 15,
                      color: Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Offset _clampPosition(Offset position, Size panelSize, Size workspaceSize) =>
      Offset(
        position.dx.clamp(
          0.0,
          math.max(0.0, workspaceSize.width - panelSize.width),
        ),
        position.dy.clamp(
          0.0,
          math.max(0.0, workspaceSize.height - panelSize.height),
        ),
      );

  void _finishFloatingDrag(
    DockPanelEntry entry,
    Size panelSize,
    Size workspaceSize,
  ) {
    final position = _clampPosition(
      _dragPositions[entry.id] ??
          widget.uiController.floatingPosition(
            entry.id,
            entry.defaultFloatingPosition,
          ),
      panelSize,
      workspaceSize,
    );
    setState(() => _dragPositions.remove(entry.id));
    widget.uiController.setFloatingPosition(entry.id, position);
  }

  void _finishFloatingResize(DockPanelEntry entry, Size workspaceSize) {
    final size = _dragSizes.remove(entry.id);
    if (size == null) return;
    final fitted = Size(
      size.width.clamp(kPanelFloatingMinWidth, workspaceSize.width),
      size.height.clamp(96, workspaceSize.height),
    );
    setState(() {});
    widget.uiController.setFloatingSize(entry.id, fitted);
  }

  Widget _wrapPanel(
    DockPanelEntry entry,
    PanelDockEdge edge,
    Size workspaceSize, {
    GestureDragUpdateCallback? onDragUpdate,
    GestureDragEndCallback? onDragEnd,
  }) {
    final ui = widget.uiController;
    final sideDock = edge == PanelDockEdge.left || edge == PanelDockEdge.right;
    return DockPanel(
      panelId: entry.id,
      title: entry.title,
      icon: entry.icon,
      isCollapsed: ui.panelCollapsed(entry.id),
      onCollapsedChanged: (_) => ui.toggleCollapsed(entry.id),
      dockEdge: edge,
      onDockEdgeChanged: (newEdge) => ui.setDockEdge(entry.id, newEdge),
      presentationMode: ui.dockPresentationMode,
      onPresentationModeChanged: ui.setDockPresentationMode,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      constraints: sideDock
          ? const BoxConstraints()
          : const BoxConstraints.expand(),
      child: _panelChildren.putIfAbsent((
        entry.id,
        edge,
        entry.contentRevision,
      ), () => entry.builder(edge)),
    );
  }
}
