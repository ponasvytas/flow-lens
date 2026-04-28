import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'dockable_panel.dart';

/// Playback control bar with speed and jump controls.
/// Adapts layout based on dock edge: single row for top/bottom,
/// single column for left/right sides.
class DraggableControlBar extends StatefulWidget {
  final Player player;
  final Function(double) onSpeedChange;
  final Function(Duration) onJumpForward;
  final Function(Duration) onJumpBackward;
  final VoidCallback onTogglePlayPause;
  final PanelDockEdge dockEdge;

  const DraggableControlBar({
    required this.player,
    required this.onSpeedChange,
    required this.onJumpForward,
    required this.onJumpBackward,
    required this.onTogglePlayPause,
    this.dockEdge = PanelDockEdge.floating,
    super.key,
  });

  @override
  State<DraggableControlBar> createState() => _DraggableControlBarState();
}

class _DraggableControlBarState extends State<DraggableControlBar> {
  bool get _isVertical =>
      widget.dockEdge == PanelDockEdge.left ||
      widget.dockEdge == PanelDockEdge.right;

  bool get _isFloating => widget.dockEdge == PanelDockEdge.floating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _isVertical
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: _isVertical
          ? _buildVertical()
          : _isFloating
              ? _buildFloating()
              : _buildHorizontal(),
    );
  }

  // -------------------------------------------------------------------------
  // Floating layout — compact two-row card
  // -------------------------------------------------------------------------

  Widget _buildFloating() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1: Speed chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _speedButtons(Axis.horizontal),
          ),
        ),
        const SizedBox(height: 6),
        // Row 2: Jump / play controls
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: _jumpButtons(Axis.horizontal),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Horizontal layout (floating / top / bottom) — one scrollable row
  // -------------------------------------------------------------------------

  Widget _buildHorizontal() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed buttons
          ..._speedButtons(Axis.horizontal),
          const SizedBox(width: 8),
          _divider(Axis.horizontal),
          const SizedBox(width: 8),
          // Jump / play controls
          ..._jumpButtons(Axis.horizontal),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Vertical layout (left / right) — one column
  // -------------------------------------------------------------------------

  Widget _buildVertical() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Speed buttons stacked
        ..._speedButtons(Axis.vertical),
        const SizedBox(height: 6),
        _divider(Axis.vertical),
        const SizedBox(height: 6),
        // Jump / play controls stacked
        ..._jumpButtons(Axis.vertical),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Shared builders
  // -------------------------------------------------------------------------

  Widget _divider(Axis axis) {
    return axis == Axis.horizontal
        ? Container(width: 1, height: 24, color: Colors.white24)
        : Container(height: 1, width: 24, color: Colors.white24);
  }

  /// Speed chips — compact toggle buttons
  List<Widget> _speedButtons(Axis axis) {
    const speeds = [0.25, 0.5, 1.0, 2.0, 3.0];
    final spacing = axis == Axis.horizontal
        ? const SizedBox(width: 4)
        : const SizedBox(height: 4);

    return [
      if (axis == Axis.horizontal)
        const Text('Speed', style: TextStyle(color: Colors.white70, fontSize: 11)),
      if (axis == Axis.horizontal) const SizedBox(width: 6),
      for (int i = 0; i < speeds.length; i++) ...[
        if (i > 0) spacing,
        _SpeedChip(
          label: '${speeds[i]}x',
          onTap: () => widget.onSpeedChange(speeds[i]),
        ),
      ],
    ];
  }

  /// Jump-back, play/pause, jump-forward buttons
  List<Widget> _jumpButtons(Axis axis) {
    final spacing = axis == Axis.horizontal
        ? const SizedBox(width: 2)
        : const SizedBox(height: 2);

    return [
      _JumpBtn(icon: Icons.fast_rewind, label: '30', onTap: () => widget.onJumpBackward(const Duration(seconds: 30)), axis: axis),
      spacing,
      _JumpBtn(icon: Icons.replay_10, onTap: () => widget.onJumpBackward(const Duration(seconds: 10)), axis: axis),
      spacing,
      _JumpBtn(icon: Icons.fast_rewind, label: '3', onTap: () => widget.onJumpBackward(const Duration(seconds: 3)), axis: axis),
      spacing,
      // Play / Pause
      StreamBuilder<bool>(
        stream: widget.player.stream.playing,
        builder: (context, snapshot) {
          final isPlaying = snapshot.data ?? false;
          return IconButton(
            onPressed: widget.onTogglePlayPause,
            icon: Icon(
              isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: Colors.white,
              size: 28,
            ),
            tooltip: isPlaying ? 'Pause' : 'Play',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          );
        },
      ),
      spacing,
      _JumpBtn(icon: Icons.fast_forward, label: '3', labelFirst: true, onTap: () => widget.onJumpForward(const Duration(seconds: 3)), axis: axis),
      spacing,
      _JumpBtn(icon: Icons.forward_10, onTap: () => widget.onJumpForward(const Duration(seconds: 10)), axis: axis),
      spacing,
      _JumpBtn(icon: Icons.fast_forward, label: '30', labelFirst: true, onTap: () => widget.onJumpForward(const Duration(seconds: 30)), axis: axis),
    ];
  }
}

// ---------------------------------------------------------------------------
// Small helper widgets
// ---------------------------------------------------------------------------

class _SpeedChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SpeedChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ),
    );
  }
}

class _JumpBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool labelFirst;
  final VoidCallback onTap;
  final Axis axis;

  const _JumpBtn({
    required this.icon,
    required this.onTap,
    required this.axis,
    this.label,
    this.labelFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconW = Icon(icon, color: Colors.white, size: 18);
    final labelW = label != null
        ? Text(label!, style: const TextStyle(color: Colors.white, fontSize: 11))
        : null;

    final children = <Widget>[
      if (labelFirst && labelW != null) labelW,
      iconW,
      if (!labelFirst && labelW != null) labelW,
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: axis == Axis.horizontal
            ? Row(mainAxisSize: MainAxisSize.min, children: children)
            : Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}
