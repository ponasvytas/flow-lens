import 'package:flutter/material.dart';
import '../models/app_mode.dart';

/// Which edge a panel is docked to (or floating freely)
enum PanelDockEdge {
  left,
  right,
  top,
  bottom,
  floating, // Not snapped to any edge
}

// ---------------------------------------------------------------------------
// Layout constants — single source of truth
// ---------------------------------------------------------------------------
const double kSnapThreshold = 30.0;
const double kAppTitleBarHeight = 64.0;
const double kProgressBarReserve = 70.0;
const double kPanelTitleStripHeight = 32.0;
const double kPanelFloatingMinWidth = 220.0;
const double kPanelFloatingMaxWidth = 320.0;
const double kPanelFallbackWidth = 220.0;
const double kPanelCornerRadius = 8.0;
const double kPanelEdgeMargin = 20.0;
const Duration kCollapseAnimDuration = Duration(milliseconds: 180);

// ---------------------------------------------------------------------------
// DockPanel — pure visual wrapper. Positioning is handled by DockLayout.
// ---------------------------------------------------------------------------

/// Collapsible panel card with title strip, dock-picker menu, and collapse
/// toggle. **Does not manage its own position** — the parent [DockLayout]
/// handles placement.
class DockPanel extends StatefulWidget {
  final PanelId panelId;
  final String title;
  final IconData icon;
  final bool isCollapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final PanelDockEdge dockEdge;
  final ValueChanged<PanelDockEdge> onDockEdgeChanged;
  final BoxConstraints constraints;
  final Widget child;

  const DockPanel({
    required this.panelId,
    required this.title,
    required this.icon,
    required this.isCollapsed,
    required this.onCollapsedChanged,
    required this.dockEdge,
    required this.onDockEdgeChanged,
    required this.child,
    this.constraints = const BoxConstraints(),
    super.key,
  });

  @override
  State<DockPanel> createState() => _DockPanelState();
}

class _DockPanelState extends State<DockPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _collapseAnim;
  late final Animation<double> _collapseAnimation;

  @override
  void initState() {
    super.initState();
    _collapseAnim = AnimationController(
      vsync: this,
      duration: kCollapseAnimDuration,
      value: widget.isCollapsed ? 0.0 : 1.0,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseAnim,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(DockPanel old) {
    super.didUpdateWidget(old);
    if (widget.isCollapsed != old.isCollapsed) {
      widget.isCollapsed ? _collapseAnim.reverse() : _collapseAnim.forward();
    }
  }

  @override
  void dispose() {
    _collapseAnim.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Dock picker menu
  // -------------------------------------------------------------------------

  void _showDockMenu(BuildContext context) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero);

    showMenu<PanelDockEdge>(
      context: context,
      color: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Colors.white12),
      ),
      position: RelativeRect.fromLTRB(
        topLeft.dx,
        topLeft.dy + kPanelTitleStripHeight,
        topLeft.dx + 160,
        topLeft.dy + kPanelTitleStripHeight + 200,
      ),
      items: [
        _menuItem(PanelDockEdge.left, Icons.align_horizontal_left, 'Dock Left'),
        _menuItem(PanelDockEdge.right, Icons.align_horizontal_right, 'Dock Right'),
        _menuItem(PanelDockEdge.top, Icons.align_vertical_top, 'Dock Top'),
        _menuItem(PanelDockEdge.bottom, Icons.align_vertical_bottom, 'Dock Bottom'),
        _menuItem(PanelDockEdge.floating, Icons.open_with, 'Float'),
      ],
    ).then((edge) {
      if (edge != null) widget.onDockEdgeChanged(edge);
    });
  }

  PopupMenuItem<PanelDockEdge> _menuItem(
      PanelDockEdge edge, IconData icon, String label) {
    final isActive = widget.dockEdge == edge;
    return PopupMenuItem<PanelDockEdge>(
      value: edge,
      height: 36,
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isActive ? const Color(0xFF9b5fb8) : Colors.white60),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF9b5fb8) : Colors.white70,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive) ...[
            const Spacer(),
            const Icon(Icons.check, size: 12, color: Color(0xFF9b5fb8)),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isVertical =
        widget.dockEdge == PanelDockEdge.left ||
        widget.dockEdge == PanelDockEdge.right;

    Widget panel = Container(
      constraints: widget.constraints,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.82),
        borderRadius: BorderRadius.circular(kPanelCornerRadius),
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTitleStrip(compact: isVertical),
          SizeTransition(
            sizeFactor: _collapseAnimation,
            axisAlignment: -1.0,
            child: widget.child,
          ),
        ],
      ),
    );

    if (isVertical || widget.dockEdge == PanelDockEdge.floating) {
      panel = IntrinsicWidth(child: panel);
    }

    return Material(color: Colors.transparent, child: panel);
  }

  // -------------------------------------------------------------------------
  // Title strip
  // -------------------------------------------------------------------------

  Widget _buildTitleStrip({bool compact = false}) {
    return Container(
      height: kPanelTitleStripHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(kPanelCornerRadius),
          topRight: const Radius.circular(kPanelCornerRadius),
          bottomLeft: widget.isCollapsed
              ? const Radius.circular(kPanelCornerRadius)
              : Radius.zero,
          bottomRight: widget.isCollapsed
              ? const Radius.circular(kPanelCornerRadius)
              : Radius.zero,
        ),
      ),
      child: compact ? _buildCompactStrip() : _buildFullStrip(),
    );
  }

  Widget _buildFullStrip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => _showDockMenu(ctx),
            child: Tooltip(
              message: 'Dock position',
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Icon(
                  widget.dockEdge == PanelDockEdge.floating
                      ? Icons.open_with
                      : Icons.push_pin,
                  color: widget.dockEdge == PanelDockEdge.floating
                      ? Colors.white38
                      : const Color(0xFF9b5fb8),
                  size: 15,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Icon(widget.icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => widget.onCollapsedChanged(!widget.isCollapsed),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              widget.isCollapsed
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_up,
              color: Colors.white54,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStrip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Builder(
          builder: (ctx) => GestureDetector(
            onTap: () => _showDockMenu(ctx),
            child: Tooltip(
              message: 'Dock position',
              child: Icon(
                Icons.push_pin,
                color: const Color(0xFF9b5fb8),
                size: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        GestureDetector(
          onTap: () => widget.onCollapsedChanged(!widget.isCollapsed),
          child: Icon(
            widget.isCollapsed
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_up,
            color: Colors.white54,
            size: 14,
          ),
        ),
      ],
    );
  }
}
