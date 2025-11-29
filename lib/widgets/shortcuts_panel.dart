import 'package:flutter/material.dart';

/// Keyboard shortcuts panel with toggle button
class ShortcutsPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;

  const ShortcutsPanel({
    required this.isVisible,
    required this.onToggle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Shortcuts Toggle Button
        Positioned(
          bottom: 140,
          left: 20,
          child: FloatingActionButton(
            onPressed: onToggle,
            backgroundColor: isVisible ? Colors.blue : Colors.grey.shade700,
            mini: true,
            tooltip: 'Show Keyboard Shortcuts',
            child: const Icon(Icons.keyboard),
          ),
        ),

        // Shortcuts Panel
        if (isVisible)
          Positioned(
            top: 100,
            left: 20,
            child: Material(color: Colors.transparent, child: _buildPanel()),
          ),
      ],
    );
  }

  Widget _buildPanel() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard, color: Colors.blue, size: 24),
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
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: onToggle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildShortcutRow('Space', 'Play/Pause video'),
          const SizedBox(height: 8),
          _buildShortcutRow('←/→', 'Jump ±3 seconds'),
          const SizedBox(height: 8),
          _buildShortcutRow('Alt+←/→', 'Jump ±10 seconds'),
          const SizedBox(height: 8),
          _buildShortcutRow('Ctrl+←/→', 'Jump ±30 seconds'),
          const SizedBox(height: 8),
          _buildShortcutRow('G', 'Toggle graphics mode'),
          const SizedBox(height: 8),
          _buildShortcutRow('1/2/3', 'Select tool (graphics mode)'),
          const SizedBox(height: 8),
          _buildShortcutRow('K', 'Toggle laser pointer'),
          const SizedBox(height: 8),
          _buildShortcutRow('C', 'Clear all drawings'),
          const SizedBox(height: 8),
          _buildShortcutRow('S', 'Set speed to 0.33x (slow)'),
          const SizedBox(height: 8),
          _buildShortcutRow('D', 'Set speed to 1.0x (normal)'),
          const SizedBox(height: 8),
          _buildShortcutRow('A', 'Jump back 5 seconds'),
          const SizedBox(height: 8),
          _buildShortcutRow('F (Hold)', '3x forward speed'),
          const SizedBox(height: 8),
          _buildShortcutRow('Scroll', 'Zoom in/out (when not drawing)'),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String key, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade600, width: 1),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
