import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/ui_controller.dart';
import '../models/app_mode.dart';
import 'dockable_panel.dart';
import 'tool_action_grid.dart';
import 'dock_split.dart';

const double kDockResizeHandleSize = 8;
const double kDockMinSideExtent = 112;
const double kDockMinHorizontalExtent = 88;
const double kDockMinCenterWidth = 320;
const double kDockMinCenterHeight = 220;

bool usesCompactDockLayout(Size size) =>
    size.width < 900 || size.width < size.height || size.height < 440;

class DockPanelEntry {
  final PanelId id;
  final String title;
  final IconData icon;
  final Offset defaultFloatingPosition;
  final Size defaultFloatingSize;
  final ToolsetLayout layout;
  final Object? contentRevision;
  final bool fillSideDock;
  final Widget Function(PanelDockEdge dockEdge) builder;

  const DockPanelEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.defaultFloatingPosition,
    required this.builder,
    this.defaultFloatingSize = const Size(300, 240),
    this.layout = const ToolsetLayout.widget(),
    this.contentRevision,
    this.fillSideDock = false,
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
  final bool adaptive;

  const DockLayout({
    required this.uiController,
    required this.panels,
    this.child = const SizedBox.expand(),
    this.adaptive = false,
    super.key,
  });

  @override
  State<DockLayout> createState() => _DockLayoutState();
}

class _DockLayoutState extends State<DockLayout> {
  final Map<PanelId, Offset> _dragPositions = {};
  final Map<PanelId, (Offset pointer, Offset panel)> _dragAnchors = {};
  final Map<PanelId, Size> _dragSizes = {};
  final Map<(PanelId, PanelDockEdge, Object?), Widget> _panelChildren = {};
  DockEdgeExtents? _resizingExtents;
  PanelId? _compactActive;
  Set<PanelId> _compactVisible = {};

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
    _dragAnchors.removeWhere((id, anchor) => !ids.contains(id));
    _dragSizes.removeWhere((id, size) => !ids.contains(id));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (widget.adaptive && usesCompactDockLayout(size)) {
          final entries =
              widget.panels
                  .where((entry) => widget.uiController.panelVisible(entry.id))
                  .toList()
                ..sort(
                  (a, b) => a.id == PanelId.playbackControls
                      ? -1
                      : b.id == PanelId.playbackControls
                      ? 1
                      : 0,
                );
          final primary = entries
              .where((entry) => entry.id == PanelId.playbackControls)
              .firstOrNull;
          final others = entries
              .where((entry) => entry.id != PanelId.playbackControls)
              .toList();
          final newlyVisible = others.where(
            (entry) => !_compactVisible.contains(entry.id),
          );
          if (_compactVisible.isNotEmpty && newlyVisible.isNotEmpty) {
            _compactActive = newlyVisible.last.id;
          }
          _compactVisible = others.map((entry) => entry.id).toSet();
          final active =
              others.where((entry) => entry.id == _compactActive).firstOrNull ??
              others.firstOrNull;
          final primaryHeight = primary == null
              ? 0.0
              : widget.uiController.panelCollapsed(primary.id)
              ? 50.0
              : primary.layout.heightFor(
                      size.width - 50,
                      MediaQuery.textScalerOf(context),
                    ) +
                    2;
          final activeExpanded =
              active != null && !widget.uiController.panelCollapsed(active.id);
          final tabsHeight = others.length > 1 ? 56.0 : 0.0;
          final requestedHeight = activeExpanded
              ? math.min(400.0, size.height * 0.52)
              : primaryHeight + tabsHeight + (active == null ? 0 : 50);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: widget.child),
              if (entries.isNotEmpty)
                SizedBox(
                  height: math.min(requestedHeight, size.height * 0.6),
                  child: Material(
                    color: const Color(0xFF1C1827),
                    child: LayoutBuilder(
                      builder: (context, shelf) {
                        final shortShelf =
                            shelf.maxHeight < primaryHeight + tabsHeight + 96;
                        if (shortShelf && active != null) {
                          final selected =
                              entries
                                  .where((entry) => entry.id == _compactActive)
                                  .firstOrNull ??
                              active;
                          return Column(
                            children: [
                              if (entries.length > 1)
                                SizedBox(
                                  height: 48,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: DropdownButton<PanelId>(
                                      isExpanded: true,
                                      value: selected.id,
                                      underline: const SizedBox.shrink(),
                                      items: [
                                        for (final entry in entries)
                                          DropdownMenuItem(
                                            value: entry.id,
                                            child: Text(entry.title),
                                          ),
                                      ],
                                      onChanged: (id) =>
                                          setState(() => _compactActive = id),
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: _wrapPanel(
                                  selected,
                                  PanelDockEdge.bottom,
                                  size,
                                  compact: entries.length == 1,
                                ),
                              ),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (primary != null)
                              SizedBox(
                                height: primaryHeight,
                                child: _wrapPanel(
                                  primary,
                                  PanelDockEdge.bottom,
                                  size,
                                ),
                              ),
                            if (others.length > 1)
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    for (final entry in others)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(entry.title),
                                          selected: entry.id == active?.id,
                                          onSelected: (_) => setState(
                                            () => _compactActive = entry.id,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (active != null)
                              Expanded(
                                child: _wrapPanel(
                                  active,
                                  PanelDockEdge.bottom,
                                  size,
                                  compact: true,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        }
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
        final scaler = MediaQuery.textScalerOf(context);
        var extents = _resizingExtents ?? widget.uiController.dockExtents;
        for (final edge in [PanelDockEdge.top, PanelDockEdge.bottom]) {
          final entries = groups[edge];
          if (entries == null) continue;
          final lanes = _horizontalLanes(entries, size.width, scaler);
          final needed = lanes.fold(0.0, (sum, lane) => sum + lane.height);
          extents = extents.withEdge(
            edge,
            entries.every(
                  (entry) => widget.uiController.panelCollapsed(entry.id),
                )
                ? needed + 8
                : math.max(extents.forEdge(edge), needed + 8),
          );
        }
        for (final edge in [PanelDockEdge.left, PanelDockEdge.right]) {
          if (groups[edge]?.every(
                (entry) => widget.uiController.panelCollapsed(entry.id),
              ) ??
              false) {
            extents = extents.withEdge(edge, kDockMinSideExtent);
          }
        }
        final geometry = resolveDockGeometry(
          size: size,
          activeEdges: activeEdges,
          extents: extents,
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
    final scaler = MediaQuery.textScalerOf(context);
    final lanes = _horizontalLanes(entries, rect.width, scaler);
    final heights = [
      for (final entry in entries)
        widget.uiController.panelCollapsed(entry.id)
            ? 58.0
            : entry.layout.heightFor(rect.width - 10, scaler) + 58,
    ];
    final available = math.max(0.0, rect.height - 8);
    final expandedCount = entries
        .where((entry) => !widget.uiController.panelCollapsed(entry.id))
        .length;
    final compactFrames =
        !horizontal &&
        available - (entries.length - expandedCount) * 58 < expandedCount * 106;
    final rowsKey =
        '${edge.name}/rows/${lanes.map((lane) => _groupKey(edge, Axis.horizontal, lane.items.map((item) => item.$1).toList())).join(';')}';
    final content = Padding(
      padding: EdgeInsets.only(
        top: edge == PanelDockEdge.bottom ? 8 : 0,
        bottom: edge == PanelDockEdge.bottom ? 0 : 8,
      ),
      child: horizontal
          ? _split(
              group: rowsKey,
              axis: Axis.vertical,
              preferred: lanes.map((lane) => lane.height).toList(),
              minimums: List.filled(lanes.length, 58),
              fixed: [
                for (final lane in lanes)
                  lane.items.every(
                    (item) => widget.uiController.panelCollapsed(item.$1.id),
                  ),
              ],
              labels: [
                for (final lane in lanes)
                  lane.items.map((item) => item.$1.title).join(', '),
              ],
              children: [
                for (final lane in lanes)
                  _split(
                    group: _groupKey(
                      edge,
                      Axis.horizontal,
                      lane.items.map((item) => item.$1).toList(),
                    ),
                    axis: Axis.horizontal,
                    preferred: lane.items.map((item) => item.$2).toList(),
                    minimums: lane.items
                        .map((item) => _minimumWidth(item.$1, item.$2))
                        .toList(),
                    fixed: [
                      for (final item in lane.items)
                        widget.uiController.panelCollapsed(item.$1.id),
                    ],
                    labels: lane.items.map((item) => item.$1.title).toList(),
                    children: [
                      for (final item in lane.items)
                        Padding(
                          padding: const EdgeInsets.all(4),
                          child: _wrapPanel(item.$1, edge, workspaceSize),
                        ),
                    ],
                  ),
              ],
            )
          : _split(
              group: _groupKey(edge, Axis.vertical, entries),
              axis: Axis.vertical,
              preferred: heights,
              minimums: [
                for (final entry in entries)
                  widget.uiController.panelCollapsed(entry.id) || compactFrames
                      ? 58
                      : 106,
              ],
              fixed: [
                for (final entry in entries)
                  widget.uiController.panelCollapsed(entry.id),
              ],
              labels: entries.map((entry) => entry.title).toList(),
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: _wrapPanel(
                      entry,
                      edge,
                      workspaceSize,
                      forceInline: compactFrames,
                    ),
                  ),
              ],
            ),
    );
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

  String _groupKey(
    PanelDockEdge edge,
    Axis axis,
    List<DockPanelEntry> entries,
  ) =>
      '${edge.name}/${axis.name}/${entries.map((entry) => '${entry.id.name}${widget.uiController.panelCollapsed(entry.id) ? '!' : ''}').join('|')}';

  double _minimumWidth(DockPanelEntry entry, double preferred) =>
      widget.uiController.panelCollapsed(entry.id)
      ? 58
      : math.min(preferred, entry.layout.isActionSet ? 122 : 278);

  Widget _split({
    required String group,
    required Axis axis,
    required List<Widget> children,
    required List<String> labels,
    required List<double> preferred,
    required List<double> minimums,
    required List<bool> fixed,
  }) => DockSplit(
    key: ValueKey(
      '${widget.uiController.currentMode.name}/${widget.uiController.isPresenting}/$group',
    ),
    axis: axis,
    labels: labels,
    preferred: preferred,
    minimums: minimums,
    fixed: fixed,
    fractions: widget.uiController.dockSplit(group),
    onChanged: (sizes) => widget.uiController.setDockSplit(group, sizes),
    children: children,
  );

  List<_DockLane> _horizontalLanes(
    List<DockPanelEntry> entries,
    double width,
    TextScaler scaler,
  ) {
    final groups = <List<DockPanelEntry>>[];
    double ideal(DockPanelEntry entry) =>
        widget.uiController.panelCollapsed(entry.id)
        ? 58
        : math.min(width, entry.layout.idealWidth + 58);
    var used = 0.0;
    for (final entry in entries) {
      if (groups.isEmpty || used + ideal(entry) > width + 0.5) {
        groups.add([]);
        used = 0;
      }
      groups.last.add(entry);
      used += ideal(entry);
    }
    return [
      for (final group in groups)
        () {
          final used = group.fold(0.0, (sum, entry) => sum + ideal(entry));
          final expanded = group
              .where((entry) => !widget.uiController.panelCollapsed(entry.id))
              .length;
          final preferred = [
            for (final entry in group)
              ideal(entry) +
                  (widget.uiController.panelCollapsed(entry.id)
                      ? 0
                      : (width - used) / expanded),
          ];
          final widths = allocateDockSplit(
            available: width,
            preferred: preferred,
            minimums: [
              for (var i = 0; i < group.length; i++)
                _minimumWidth(group[i], preferred[i]),
            ],
            fixed: [
              for (final entry in group)
                widget.uiController.panelCollapsed(entry.id),
            ],
            fractions: widget.uiController.dockSplit(
              _groupKey(
                widget.uiController.dockEdge(group.first.id),
                Axis.horizontal,
                group,
              ),
            ),
          );
          final items = [
            for (var i = 0; i < group.length; i++) (group[i], widths[i]),
          ];
          final height = items.fold(
            58.0,
            (height, item) => math.max(
              height,
              widget.uiController.panelCollapsed(item.$1.id)
                  ? 58
                  : item.$1.layout.heightFor(item.$2 - 58, scaler) + 10,
            ),
          );
          return _DockLane(items, height);
        }(),
    ];
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
          // Keep the grab area generous; only the visible rail clears corners.
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: vertical ? 0 : kPanelCornerRadius + 4,
              vertical: vertical ? kPanelCornerRadius + 4 : 0,
            ),
            child: Center(
              child: Container(
                width: vertical ? 2 : double.infinity,
                height: vertical ? double.infinity : 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(
                    kDockResizeHandleSize / 2,
                  ),
                ),
              ),
            ),
          ),
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
      math
          .max(
            size.height,
            entry.layout.isActionSet
                ? entry.layout.heightFor(
                        math.min(size.width, workspaceSize.width) - 2,
                        MediaQuery.textScalerOf(context),
                      ) +
                      50
                : 0.0,
          )
          .clamp(
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
      collapsed
          ? Size(clampedSize.width, kPanelTitleStripHeight + 2)
          : clampedSize,
      workspaceSize,
    );
    final displayedHeight = collapsed
        ? kPanelTitleStripHeight + 2
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
              onDragStart: (details) {
                _dragAnchors[entry.id] = (details.globalPosition, position);
              },
              onDragUpdate: (details) {
                final anchor = _dragAnchors[entry.id];
                if (anchor == null) return;
                setState(() {
                  _dragPositions[entry.id] =
                      anchor.$2 + details.globalPosition - anchor.$1;
                });
              },
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
                    child: Padding(
                      padding: EdgeInsets.only(right: 4, bottom: 4),
                      child: Icon(
                        Icons.drag_handle,
                        size: 14,
                        color: Colors.white38,
                      ),
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
    setState(() {
      _dragPositions.remove(entry.id);
      _dragAnchors.remove(entry.id);
    });
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
    bool forceInline = false,
    GestureDragStartCallback? onDragStart,
    GestureDragUpdateCallback? onDragUpdate,
    GestureDragEndCallback? onDragEnd,
    bool compact = false,
  }) {
    final ui = widget.uiController;
    return DockPanel(
      key: ValueKey('workspace-panel-${entry.id.name}'),
      panelId: entry.id,
      title: entry.title,
      icon: entry.icon,
      isCollapsed: ui.panelCollapsed(entry.id),
      onCollapsedChanged: (_) => ui.toggleCollapsed(entry.id),
      dockEdge: edge,
      onDockEdgeChanged: (newEdge) => ui.setDockEdge(entry.id, newEdge),
      onHide: () => ui.hidePanel(entry.id),
      inlineControls: forceInline
          ? true
          : compact
          ? false
          : null,
      presentationMode: ui.dockPresentationMode,
      onPresentationModeChanged: ui.setDockPresentationMode,
      onDragStart: onDragStart,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      constraints: const BoxConstraints.expand(),
      scrollContent: !entry.fillSideDock && !entry.layout.isActionSet,
      child: _panelChildren.putIfAbsent((
        entry.id,
        edge,
        entry.contentRevision,
      ), () => entry.builder(edge)),
    );
  }
}

class _DockLane {
  final List<(DockPanelEntry, double)> items;
  final double height;
  const _DockLane(this.items, this.height);
}
