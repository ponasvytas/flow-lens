import 'package:flutter/material.dart';
import '../main.dart'; // For DrawingTool enum

/// Drawing tools panel with tool selection, color picker, and controls
class DrawingToolsPanel extends StatelessWidget {
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final Color drawingColor;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onResetZoom;
  final VoidCallback onClearDrawing;
  final Function(DrawingTool) onToolChange;
  final Function(Color) onColorChange;

  const DrawingToolsPanel({
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingColor,
    required this.onToggleDrawingMode,
    required this.onResetZoom,
    required this.onClearDrawing,
    required this.onToolChange,
    required this.onColorChange,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 200,
      right: 20,
      child: Column(
        children: [
          // Toggle Drawing Mode
          FloatingActionButton(
            onPressed: onToggleDrawingMode,
            backgroundColor: isDrawingMode ? Colors.orange : Colors.grey,
            tooltip: isDrawingMode ? 'Disable Drawing' : 'Enable Drawing',
            child: Icon(
              isDrawingMode ? Icons.draw : Icons.touch_app,
            ),
          ),
          const SizedBox(height: 8),
          // Reset Zoom
          FloatingActionButton(
            onPressed: onResetZoom,
            backgroundColor: Colors.purple,
            mini: true,
            tooltip: 'Reset Zoom',
            child: const Icon(Icons.zoom_out_map),
          ),
          // Only show drawing tools when drawing mode is enabled
          if (isDrawingMode) ...[
            const SizedBox(height: 8),
            // Clear Drawing
            Stack(
              clipBehavior: Clip.none,
              children: [
                FloatingActionButton(
                  onPressed: onClearDrawing,
                  backgroundColor: Colors.redAccent.shade700,
                  mini: true,
                  tooltip: 'Clear Drawings (C)',
                  child: const Icon(Icons.clear),
                ),
                // Shortcut badge
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Text(
                      'C',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Tool Selection
            _buildToolButton(DrawingTool.freehand, Icons.gesture, 'Freehand (1)', '1'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.line, Icons.remove, 'Line (2)', '2'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.arrow, Icons.arrow_forward, 'Arrow (3)', '3'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.laser, Icons.flash_on, 'Laser Pointer (K)', 'K'),
            const SizedBox(height: 8),
            // Color Options
            ...[
              const Color(0xFF753b8f),
              Colors.red,
              Colors.blue,
              Colors.yellow,
              Colors.white,
            ].map((color) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => onColorChange(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: drawingColor == color ? Colors.white : Colors.grey,
                      width: drawingColor == color ? 3 : 1,
                    ),
                  ),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildToolButton(DrawingTool tool, IconData icon, String tooltip, String? shortcut) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          onPressed: () => onToolChange(tool),
          backgroundColor: currentTool == tool ? Colors.orange : Colors.grey.shade700,
          mini: true,
          tooltip: tooltip,
          child: Icon(icon, size: 20),
        ),
        // Shortcut badge
        if (shortcut != null)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                shortcut,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
