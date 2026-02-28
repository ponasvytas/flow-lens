import 'package:flutter/material.dart';
import '../controllers/ui_controller.dart';
import '../models/app_mode.dart';
import 'dockable_panel.dart';

// ---------------------------------------------------------------------------
// Data class that describes one panel for the dock layout system.
// ---------------------------------------------------------------------------

/// Everything the layout system needs to know about a panel.
///
/// The [builder] receives the *current* [PanelDockEdge] so child widgets can
/// adapt (row vs column).
class DockPanelEntry {
  final PanelId id;
  final String title;
  final IconData icon;
  final Offset defaultFloatingPosition;
  final Widget Function(PanelDockEdge dockEdge) builder;

  const DockPanelEntry({
    required this.id,
    required this.title,
    required this.icon,
    required this.defaultFloatingPosition,
    required this.builder,
  });
}

// ---------------------------------------------------------------------------
// DockLayout — groups panels by edge, positions them, handles drag for floats.
// ---------------------------------------------------------------------------

/// Arranges [DockPanel]s by their dock edge.
///
/// * **Top / Bottom**: centered [Row] of panels side-by-side.
/// * **Left / Right**: [Column] of panels stacked top-to-bottom.
/// * **Floating**: absolutely positioned with drag-to-snap.
///
/// All dock-edge and floating-position state lives in [UIController].
class DockLayout extends StatefulWidget {
  final UIController uiController;
  final List<DockPanelEntry> panels;

  const DockLayout({
    required this.uiController,
    required this.panels,
    super.key,
  });

  @override
  State<DockLayout> createState() => _DockLayoutState();
}

class _DockLayoutState extends State<DockLayout> {
  // Temporary drag offset used only while a floating panel is being dragged.
  // Keyed by PanelId so multiple floats don't interfere.
  final Map<PanelId, Offset> _dragOffsets = {};

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final ui = widget.uiController;

    // Collect visible panels grouped by dock edge.
    final groups = <PanelDockEdge, List<DockPanelEntry>>{};
    for (final entry in widget.panels) {
      if (!ui.panelVisible(entry.id)) continue;
      final edge = ui.dockEdge(entry.id);
      groups.putIfAbsent(edge, () => []).add(entry);
    }

    // DockLayout lives inside the parent Stack, so we need a full-size
    // container with its own Stack for the positioned zones.
    return Positioned.fill(
      child: Stack(
        children: [
          // ---------- Edge zones ----------
          if (groups.containsKey(PanelDockEdge.top))
            _buildHorizontalZone(
              PanelDockEdge.top,
              groups[PanelDockEdge.top]!,
              screenSize,
            ),
          if (groups.containsKey(PanelDockEdge.bottom))
            _buildHorizontalZone(
              PanelDockEdge.bottom,
              groups[PanelDockEdge.bottom]!,
              screenSize,
            ),
          if (groups.containsKey(PanelDockEdge.left))
            _buildVerticalZone(
              PanelDockEdge.left,
              groups[PanelDockEdge.left]!,
              screenSize,
            ),
          if (groups.containsKey(PanelDockEdge.right))
            _buildVerticalZone(
              PanelDockEdge.right,
              groups[PanelDockEdge.right]!,
              screenSize,
            ),
          // ---------- Floating panels ----------
          if (groups.containsKey(PanelDockEdge.floating))
            for (final entry in groups[PanelDockEdge.floating]!)
              _buildFloatingPanel(entry, screenSize),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Horizontal zone (top / bottom) — centered Row, panels side-by-side
  // -------------------------------------------------------------------------

  Widget _buildHorizontalZone(
    PanelDockEdge edge,
    List<DockPanelEntry> entries,
    Size screenSize,
  ) {
    final isTop = edge == PanelDockEdge.top;
    return Positioned(
      top: isTop ? kAppTitleBarHeight : null,
      bottom: isTop ? null : kProgressBarReserve,
      left: 0,
      right: 0,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _wrapPanel(entries[i], edge, screenSize),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Vertical zone (left / right) — Column of panels
  // -------------------------------------------------------------------------

  Widget _buildVerticalZone(
    PanelDockEdge edge,
    List<DockPanelEntry> entries,
    Size screenSize,
  ) {
    final isLeft = edge == PanelDockEdge.left;
    return Positioned(
      top: kAppTitleBarHeight,
      bottom: kProgressBarReserve,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              IntrinsicWidth(
                child: _wrapPanel(entries[i], edge, screenSize),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Floating panel — absolutely positioned with drag-to-snap
  // -------------------------------------------------------------------------

  Widget _buildFloatingPanel(DockPanelEntry entry, Size screenSize) {
    final pos = _dragOffsets[entry.id] ??
        widget.uiController.floatingPosition(
            entry.id, entry.defaultFloatingPosition);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => _onFloatingDragUpdate(entry.id, d, entry),
        onPanEnd: (d) => _onFloatingDragEnd(entry.id, d, screenSize, entry),
        child: _wrapPanel(entry, PanelDockEdge.floating, screenSize),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Drag logic for floating panels
  // -------------------------------------------------------------------------

  void _onFloatingDragUpdate(
      PanelId id, DragUpdateDetails details, DockPanelEntry entry) {
    final current = _dragOffsets[id] ??
        widget.uiController.floatingPosition(
            id, entry.defaultFloatingPosition);
    final newPos = Offset(
      current.dx + details.delta.dx,
      current.dy + details.delta.dy,
    );
    setState(() => _dragOffsets[id] = newPos);
    widget.uiController.setFloatingPositionSilent(id, newPos);
  }

  void _onFloatingDragEnd(
    PanelId id,
    DragEndDetails details,
    Size screenSize,
    DockPanelEntry entry,
  ) {
    final pos = _dragOffsets[id] ??
        widget.uiController.floatingPosition(
            id, entry.defaultFloatingPosition);
    double x = pos.dx;
    double y = pos.dy;
    PanelDockEdge newEdge = PanelDockEdge.floating;

    // Snap to left
    if (x < kSnapThreshold) {
      newEdge = PanelDockEdge.left;
    }
    // Snap to right (use fallback width estimate)
    else if (x + kPanelFallbackWidth > screenSize.width - kSnapThreshold) {
      newEdge = PanelDockEdge.right;
    }

    // Snap to top
    if (y < kAppTitleBarHeight + kSnapThreshold) {
      if (newEdge == PanelDockEdge.floating) newEdge = PanelDockEdge.top;
    }
    // Snap to bottom
    else if (y + kPanelTitleStripHeight >
        screenSize.height - kProgressBarReserve - kSnapThreshold) {
      if (newEdge == PanelDockEdge.floating) newEdge = PanelDockEdge.bottom;
    }

    _dragOffsets.remove(id);

    if (newEdge != PanelDockEdge.floating) {
      // Docked — let the zone position it
      widget.uiController.setDockEdge(id, newEdge);
    } else {
      // Stays floating — persist clamped position
      x = x.clamp(0, screenSize.width - 60);
      y = y.clamp(kAppTitleBarHeight, screenSize.height - kProgressBarReserve);
      widget.uiController.setFloatingPosition(id, Offset(x, y));
    }
  }

  // -------------------------------------------------------------------------
  // Panel visual wrapper (shared by all edge types)
  // -------------------------------------------------------------------------

  Widget _wrapPanel(
      DockPanelEntry entry, PanelDockEdge edge, Size screenSize) {
    final ui = widget.uiController;
    final isCollapsed = ui.panelCollapsed(entry.id);
    final isVertical =
        edge == PanelDockEdge.left || edge == PanelDockEdge.right;
    final isHorizontal =
        edge == PanelDockEdge.top || edge == PanelDockEdge.bottom;

    return DockPanel(
      panelId: entry.id,
      title: entry.title,
      icon: entry.icon,
      isCollapsed: isCollapsed,
      onCollapsedChanged: (_) => ui.toggleCollapsed(entry.id),
      dockEdge: edge,
      onDockEdgeChanged: (newEdge) => ui.setDockEdge(entry.id, newEdge),
      constraints: isVertical
          ? const BoxConstraints()
          : isHorizontal
              ? BoxConstraints(
                  maxWidth: screenSize.width - kPanelEdgeMargin * 2)
              : const BoxConstraints(maxWidth: kPanelFloatingMaxWidth),
      child: entry.builder(edge),
    );
  }
}
