import 'package:flutter/material.dart';
import '../models/drawing_models.dart';
import 'dockable_panel.dart';

/// Drawing tools panel with tool selection, color picker, and controls.
/// Adapts layout based on dock edge: horizontal row for top/bottom,
/// vertical column for left/right sides.
class DrawingToolsPanel extends StatefulWidget {
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final Color drawingColor;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onResetZoom;
  final VoidCallback onClearDrawing;
  final Function(DrawingTool) onToolChange;
  final Function(Color) onColorChange;
  final PanelDockEdge dockEdge; // NEW

  const DrawingToolsPanel({
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingColor,
    required this.onToggleDrawingMode,
    required this.onResetZoom,
    required this.onClearDrawing,
    required this.onToolChange,
    required this.onColorChange,
    required this.dockEdge,
    super.key,
  });

  @override
  State<DrawingToolsPanel> createState() => _DrawingToolsPanelState();
}

class _DrawingToolsPanelState extends State<DrawingToolsPanel> {
  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.dockEdge == PanelDockEdge.top ||
        widget.dockEdge == PanelDockEdge.bottom;

    // Content only — DockLayout handles positioning
    return Padding(
      padding: isHorizontal
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: isHorizontal ? _buildHorizontal() : _buildVertical(),
    );
  }

  /// Horizontal layout for top/bottom dock — scrollable row
  Widget _buildHorizontal() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: _buildToolButtons(Axis.horizontal),
        ),
      ),
    );
  }

  /// Vertical layout for left/right dock — tight column, no extra width
  Widget _buildVertical() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: _buildToolButtons(Axis.vertical),
    );
  }

  /// Shared tool button builder
  List<Widget> _buildToolButtons(Axis axis) {
    final spacing = axis == Axis.horizontal
        ? const SizedBox(width: 6)
        : const SizedBox(height: 6);

    final buttons = <Widget>[
      // Toggle Drawing Mode
      _IconButtonWrap(
        icon: Icons.draw,
        label: 'Draw',
        active: widget.isDrawingMode,
        onPressed: widget.onToggleDrawingMode,
        axis: axis,
        size: 36,
      ),
      spacing,
      // Reset Zoom
      _IconButtonWrap(
        icon: Icons.zoom_out_map,
        label: 'Zoom',
        onPressed: widget.onResetZoom,
        axis: axis,
        size: 32,
      ),
    ];

    if (widget.isDrawingMode) {
      buttons.addAll([
        spacing,
        // Clear Drawing
        _IconButtonWrap(
          icon: Icons.clear,
          label: 'Clear',
          color: Colors.redAccent.shade700,
          onPressed: widget.onClearDrawing,
          axis: axis,
          size: 32,
          shortcut: 'C',
        ),
        spacing,
        // Tool selectors
        _IconButtonWrap(
          icon: Icons.gesture,
          label: 'Freehand',
          active: widget.currentTool == DrawingTool.freehand,
          onPressed: () => widget.onToolChange(DrawingTool.freehand),
          axis: axis,
          size: 32,
          shortcut: '1',
        ),
        spacing,
        _IconButtonWrap(
          icon: Icons.remove,
          label: 'Line',
          active: widget.currentTool == DrawingTool.line,
          onPressed: () => widget.onToolChange(DrawingTool.line),
          axis: axis,
          size: 32,
          shortcut: '2',
        ),
        spacing,
        _IconButtonWrap(
          icon: Icons.arrow_forward,
          label: 'Arrow',
          active: widget.currentTool == DrawingTool.arrow,
          onPressed: () => widget.onToolChange(DrawingTool.arrow),
          axis: axis,
          size: 32,
          shortcut: '3',
        ),
        spacing,
        _IconButtonWrap(
          icon: Icons.flash_on,
          label: 'Laser',
          active: widget.currentTool == DrawingTool.laser,
          onPressed: () => widget.onToolChange(DrawingTool.laser),
          axis: axis,
          size: 32,
          shortcut: 'K',
        ),
        spacing,
      ]);

      // Color options
      final colors = [
        const Color(0xFF753b8f),
        Colors.red,
        Colors.blue,
        Colors.yellow,
        Colors.white,
      ];

      for (int i = 0; i < colors.length; i++) {
        if (i > 0) buttons.add(spacing);
        buttons.add(
          _ColorSwatch(
            color: colors[i],
            isSelected: widget.drawingColor == colors[i],
            onTap: () => widget.onColorChange(colors[i]),
            axis: axis,
          ),
        );
      }
    }

    return buttons;
  }
}

/// Simple icon button wrapper with optional label/shortcut
class _IconButtonWrap extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onPressed;
  final Axis axis;
  final double size;
  final String? shortcut;
  final Color? color;

  const _IconButtonWrap({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.axis,
    required this.size,
    this.active = false,
    this.shortcut,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? (active ? Colors.orange : Colors.grey.shade700);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: shortcut != null ? '$label ($shortcut)' : label,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(8),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
        if (shortcut != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                shortcut!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Color swatch selector
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final Axis axis;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.axis,
  });

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: 'Color',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.grey.shade600,
              width: isSelected ? 2.5 : 1,
            ),
          ),
        ),
      ),
    );
  }
}
