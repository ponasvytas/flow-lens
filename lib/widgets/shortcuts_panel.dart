import 'package:flutter/material.dart';

/// Keyboard shortcuts panel - toggleable and draggable
class ShortcutsPanel extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onToggle;
  final double positionX;
  final double positionY;
  final Function(double dx, double dy) onPositionChanged;
  final VoidCallback? onResetPosition;

  const ShortcutsPanel({
    required this.isVisible,
    required this.onToggle,
    required this.positionX,
    required this.positionY,
    required this.onPositionChanged,
    this.onResetPosition,
    super.key,
  });

  @override
  State<ShortcutsPanel> createState() => _ShortcutsPanelState();
}

class _ShortcutsPanelState extends State<ShortcutsPanel> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = Offset(widget.positionX, widget.positionY);
  }

  @override
  void didUpdateWidget(ShortcutsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.positionX != widget.positionX ||
        oldWidget.positionY != widget.positionY) {
      _position = Offset(widget.positionX, widget.positionY);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) return const SizedBox.shrink();

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() => _position += details.delta);
        },
        onPanEnd: (_) {
          widget.onPositionChanged(
            _position.dx - widget.positionX,
            _position.dy - widget.positionY,
          );
        },
        child: Material(color: Colors.transparent, child: _buildPanel()),
      ),
    );
  }

  Widget _buildPanel() {
    return Container(
      width: 360,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                const Icon(Icons.drag_handle, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Icon(Icons.keyboard, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Keyboard Shortcuts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (widget.onResetPosition != null)
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white70,
                      size: 18,
                    ),
                    onPressed: widget.onResetPosition,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Reset position',
                  ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 20,
                  ),
                  onPressed: widget.onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.white24, height: 16),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Shortcuts are disabled while typing in text fields.',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Scrollable shortcut list
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Global (all modes) ──
                  _buildSectionHeader('All Modes', Colors.blue),
                  _buildShortcutRow('Ctrl+M', 'Cycle app mode'),
                  _buildShortcutRow('Space', 'Play / Pause video'),
                  _buildShortcutRow('←  /  →', 'Jump ±3 seconds'),
                  _buildShortcutRow('Shift+←/→', 'Jump ±10 seconds'),
                  _buildShortcutRow('Ctrl+←/→', 'Jump ±30 seconds'),
                  _buildShortcutRow('A', 'Jump back 5 seconds'),
                  _buildShortcutRow('S', 'Slow playback speed'),
                  _buildShortcutRow('D', 'Default playback speed'),
                  _buildShortcutRow('F (hold)', 'Fast-forward while held'),
                  _buildShortcutRow('M', 'Toggle mute / unmute'),
                  _buildShortcutRow('Scroll', 'Zoom in / out'),

                  const SizedBox(height: 12),

                  // ── Record + Review ──
                  _buildSectionHeader('Review Only', Colors.orange),
                  _buildShortcutRow('G', 'Toggle drawing mode'),
                  _buildShortcutRow('C', 'Clear all drawings'),
                  _buildShortcutRow('K', 'Toggle laser pointer'),
                  _buildShortcutRow(
                    '1 / 2 / 3',
                    'Freehand / Line / Arrow (drawing mode)',
                  ),

                  const SizedBox(height: 12),

                  // ── Record only ──
                  _buildSectionHeader('Record Only', Colors.redAccent),
                  _buildShortcutRow(
                    'Assigned key',
                    'Quick event (edit keys in quick menu)',
                  ),
                  _buildShortcutRow('Alt (tap)', 'Toggle staged event entry'),
                  _buildShortcutRow('1–9', 'Choose category, type, then grade'),
                  _buildShortcutRow('PgUp/PgDn', 'Previous / next choices'),
                  _buildShortcutRow('0 (grade)', 'Save without a grade'),
                  _buildShortcutRow('Enter', 'Save event (SmartHUD)'),
                  _buildShortcutRow('Esc', 'Close event popup'),

                  const SizedBox(height: 12),

                  // ── Tracking only ──
                  _buildSectionHeader('Tracking Only', Colors.greenAccent),
                  _buildShortcutRow(
                    '(assigned)',
                    'Trigger counter / timer hotkey',
                  ),
                  _buildShortcutRow('(hold)', 'Hold-mode timer while key held'),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Assign hotkeys per tracker via the key badge '
                      'in the tracking panel. Use a letter or number; '
                      'playback keys are reserved.',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.25)),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String key, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 80),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade600, width: 1),
            ),
            child: Text(
              key,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
