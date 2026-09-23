import 'package:flutter/material.dart';
import '../models/app_mode.dart';
import '../models/dock_layout_state.dart';

export '../models/dock_layout_state.dart';

// ---------------------------------------------------------------------------
// Layout constants — single source of truth
// ---------------------------------------------------------------------------
const double kAppTitleBarHeight = 56.0;
const double kProgressBarReserve = 70.0;
const double kPanelTitleStripHeight = 48.0;
const double kPanelCollapsedInlineWidth = 50.0;
const double kPanelFloatingMinWidth = 220.0;
const double kPanelFloatingMaxWidth = 320.0;
const double kPanelFallbackWidth = 220.0;
const double kPanelCornerRadius = 12.0;
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
  final DockPresentationMode presentationMode;
  final ValueChanged<DockPresentationMode> onPresentationModeChanged;
  final GestureDragStartCallback? onDragStart;
  final GestureDragUpdateCallback? onDragUpdate;
  final GestureDragEndCallback? onDragEnd;
  final BoxConstraints constraints;
  final Widget child;
  final bool scrollContent;
  final VoidCallback? onHide;
  final bool? inlineControls;

  const DockPanel({
    required this.panelId,
    required this.title,
    required this.icon,
    required this.isCollapsed,
    required this.onCollapsedChanged,
    required this.dockEdge,
    required this.onDockEdgeChanged,
    required this.presentationMode,
    required this.onPresentationModeChanged,
    required this.child,
    this.scrollContent = true,
    this.onHide,
    this.inlineControls,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
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
  double _inlineExpandedWidth = kPanelFallbackWidth;

  bool get _isHorizontal =>
      widget.inlineControls ??
      (widget.dockEdge == PanelDockEdge.top ||
          widget.dockEdge == PanelDockEdge.bottom);

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

    showMenu<Object>(
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
        _menuItem(
          PanelDockEdge.right,
          Icons.align_horizontal_right,
          'Dock Right',
        ),
        _menuItem(PanelDockEdge.top, Icons.align_vertical_top, 'Dock Top'),
        _menuItem(
          PanelDockEdge.bottom,
          Icons.align_vertical_bottom,
          'Dock Bottom',
        ),
        _menuItem(PanelDockEdge.floating, Icons.open_with, 'Float'),
        PopupMenuItem<Object>(
          value: _DockMenuCommand.collapse,
          child: Text(widget.isCollapsed ? 'Expand panel' : 'Collapse panel'),
        ),
        if (widget.onHide != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<Object>(
            value: _DockMenuCommand.hide,
            child: Row(
              children: [
                const Icon(Icons.visibility_off_outlined, size: 20),
                const SizedBox(width: 10),
                Text('Hide ${widget.title}'),
              ],
            ),
          ),
        ],
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: _DockMenuCommand.togglePresentation,
          height: 48,
          child: Row(
            children: [
              Icon(
                widget.presentationMode == DockPresentationMode.overlay
                    ? Icons.layers
                    : Icons.view_quilt,
                size: 16,
                color: Colors.white60,
              ),
              const SizedBox(width: 10),
              Text(
                widget.presentationMode == DockPresentationMode.overlay
                    ? 'Docks overlay video'
                    : 'Docks squeeze video',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ).then((selection) {
      if (!mounted) return;
      if (selection is PanelDockEdge) {
        widget.onDockEdgeChanged(selection);
      } else if (selection == _DockMenuCommand.collapse) {
        widget.onCollapsedChanged(!widget.isCollapsed);
      } else if (selection == _DockMenuCommand.hide) {
        widget.onHide?.call();
      } else if (selection == _DockMenuCommand.togglePresentation) {
        widget.onPresentationModeChanged(
          widget.presentationMode == DockPresentationMode.overlay
              ? DockPresentationMode.squeeze
              : DockPresentationMode.overlay,
        );
      }
    });
  }

  PopupMenuItem<Object> _menuItem(
    PanelDockEdge edge,
    IconData icon,
    String label,
  ) {
    final isActive = widget.dockEdge == edge;
    return PopupMenuItem<Object>(
      value: edge,
      height: 48,
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? const Color(0xFF9b5fb8) : Colors.white60,
          ),
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
        color: const Color(0xFF1C1827),
        borderRadius: BorderRadius.circular(kPanelCornerRadius),
        border: Border.all(color: const Color(0xFF453953), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_isHorizontal) return _buildInlineControls(constraints);
          final content = SizeTransition(
            sizeFactor: _collapseAnimation,
            alignment: Alignment.topCenter,
            child: widget.scrollContent
                ? SingleChildScrollView(child: widget.child)
                : widget.child,
          );
          return Column(
            mainAxisSize: constraints.hasBoundedHeight
                ? MainAxisSize.max
                : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTitleStrip(compact: isVertical),
              if (constraints.hasBoundedHeight)
                Expanded(child: content)
              else
                content,
            ],
          );
        },
      ),
    );

    return Material(color: Colors.transparent, child: panel);
  }

  // -------------------------------------------------------------------------
  // Title strip
  // -------------------------------------------------------------------------

  Widget _buildInlineControls(BoxConstraints constraints) {
    if (!widget.isCollapsed) _inlineExpandedWidth = constraints.maxWidth;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Keep panel state and scroll position while collapsed, at its full width.
        Offstage(
          offstage: widget.isCollapsed,
          child: ExcludeFocus(
            excluding: widget.isCollapsed,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: _inlineExpandedWidth,
              maxWidth: _inlineExpandedWidth,
              child: Row(
                children: [
                  SizedBox(width: 48, child: _dockButton()),
                  Expanded(
                    child: widget.scrollContent
                        ? SingleChildScrollView(child: widget.child)
                        : widget.child,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.isCollapsed)
          Center(
            child: IconButton(
              tooltip: 'Expand ${widget.title}',
              onPressed: () => widget.onCollapsedChanged(false),
              icon: Icon(widget.icon, size: 20),
            ),
          ),
      ],
    );
  }

  Widget _buildTitleStrip({bool compact = false}) {
    final strip = Container(
      height: kPanelTitleStripHeight,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
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
    if (widget.onDragUpdate == null) return strip;
    return MouseRegion(
      cursor: SystemMouseCursors.move,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: widget.onDragStart,
        onPanUpdate: widget.onDragUpdate,
        onPanEnd: widget.onDragEnd,
        child: strip,
      ),
    );
  }

  Widget _buildFullStrip() => Row(
    children: [
      _dockButton(),
      Expanded(
        child: Text(
          widget.title,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFFC0B6CD),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      _collapseButton(),
    ],
  );

  Widget _dockButton() => Builder(
    builder: (ctx) => IconButton(
      tooltip: _isHorizontal
          ? '${widget.title} — Dock position'
          : 'Dock position',
      onPressed: () => _showDockMenu(ctx),
      icon: Icon(
        _isHorizontal ? widget.icon : Icons.more_horiz,
        size: 20,
        color: const Color(0xFFC4A5FA),
      ),
    ),
  );

  Widget _collapseButton() => IconButton(
    tooltip: widget.isCollapsed ? 'Expand panel' : 'Collapse panel',
    onPressed: () => widget.onCollapsedChanged(!widget.isCollapsed),
    icon: Icon(
      _isHorizontal
          ? Icons.chevron_left
          : widget.isCollapsed
          ? Icons.expand_more
          : Icons.expand_less,
      size: 20,
    ),
  );

  Widget _buildCompactStrip() => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 190
        ? _buildFullStrip()
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_dockButton(), _collapseButton()],
          ),
  );
}

enum _DockMenuCommand { togglePresentation, hide, collapse }
