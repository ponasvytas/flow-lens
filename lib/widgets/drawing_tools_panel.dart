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
            child: Icon(
              isDrawingMode ? Icons.draw : Icons.touch_app,
            ),
            tooltip: isDrawingMode ? 'Disable Drawing' : 'Enable Drawing',
          ),
          const SizedBox(height: 8),
          // Reset Zoom
          FloatingActionButton(
            onPressed: onResetZoom,
            backgroundColor: Colors.purple,
            mini: true,
            child: const Icon(Icons.zoom_out_map),
            tooltip: 'Reset Zoom',
          ),
          // Only show drawing tools when drawing mode is enabled
          if (isDrawingMode) ...[
            const SizedBox(height: 8),
            // Clear Drawing
            FloatingActionButton(
              onPressed: onClearDrawing,
              backgroundColor: Colors.redAccent.shade700,
              mini: true,
              child: const Icon(Icons.clear),
              tooltip: 'Clear Drawings',
            ),
            const SizedBox(height: 8),
            // Tool Selection
            _buildToolButton(DrawingTool.freehand, Icons.gesture, 'Freehand'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.line, Icons.remove, 'Line'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.arrow, Icons.arrow_forward, 'Arrow'),
            const SizedBox(height: 8),
            _buildToolButton(DrawingTool.laser, Icons.flash_on, 'Laser Pointer'),
            const SizedBox(height: 8),
            // Color Options
            ...[
              Colors.red,
              Colors.blue,
              Colors.yellow,
              Colors.green,
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

  Widget _buildToolButton(DrawingTool tool, IconData icon, String tooltip) {
    return FloatingActionButton(
      onPressed: () => onToolChange(tool),
      backgroundColor: currentTool == tool ? Colors.orange : Colors.grey.shade700,
      mini: true,
      child: Icon(icon, size: 20),
      tooltip: tooltip,
    );
  }
}
