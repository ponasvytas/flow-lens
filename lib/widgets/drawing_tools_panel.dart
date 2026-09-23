import 'package:flutter/material.dart';
import '../models/drawing_models.dart';
import 'tool_action_grid.dart';
import 'dockable_panel.dart';

class DrawingToolsPanel extends StatelessWidget {
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final Color drawingColor;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onClearDrawing;
  final ValueChanged<DrawingTool> onToolChange;
  final ValueChanged<Color> onColorChange;
  final PanelDockEdge dockEdge;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final double strokeWidth;
  final ValueChanged<double>? onWidthChange;

  const DrawingToolsPanel({
    super.key,
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingColor,
    required this.onToggleDrawingMode,
    required this.onClearDrawing,
    required this.onToolChange,
    required this.onColorChange,
    required this.dockEdge,
    this.onUndo,
    this.onRedo,
    this.strokeWidth = 5,
    this.onWidthChange,
  });

  static const _tools = [
    (DrawingTool.freehand, Icons.gesture, 'Pen', '1'),
    (DrawingTool.line, Icons.remove, 'Line', '2'),
    (DrawingTool.arrow, Icons.arrow_forward, 'Arrow', '3'),
    (DrawingTool.laser, Icons.highlight_alt, 'Laser', 'K'),
  ];
  static const _colors = [
    ('Purple', Color(0xFF753b8f)),
    ('Red', Colors.red),
    ('Blue', Colors.blue),
    ('Yellow', Colors.yellow),
    ('White', Colors.white),
  ];

  static final layout = ToolsetLayout.actions(
    List.filled(_tools.length + 5, ''),
  );

  @override
  Widget build(BuildContext context) {
    Widget button(
      IconData icon,
      String label,
      VoidCallback? onPressed, {
      bool selected = false,
      String? shortcut,
    }) => ToolActionButton(
      label: '',
      tooltip: shortcut == null ? label : '$label ($shortcut)',
      icon: icon,
      onPressed: onPressed,
      selected: selected,
    );
    final controls = <Widget>[
      button(
        Icons.near_me_outlined,
        'Pointer',
        () {
          if (isDrawingMode) onToggleDrawingMode();
        },
        selected: !isDrawingMode,
        shortcut: 'Esc',
      ),
      for (final (tool, icon, label, shortcut) in _tools)
        button(
          icon,
          label,
          () {
            if (!isDrawingMode) onToggleDrawingMode();
            onToolChange(tool);
          },
          selected: isDrawingMode && currentTool == tool,
          shortcut: shortcut,
        ),
      PopupMenuButton<Color>(
        tooltip: 'Drawing color',
        initialValue: drawingColor,
        onSelected: onColorChange,
        itemBuilder: (_) => [
          for (final (name, color) in _colors)
            CheckedPopupMenuItem(
              value: color,
              checked: color == drawingColor,
              child: Row(
                children: [
                  Icon(Icons.circle, color: color, size: 20),
                  const SizedBox(width: 12),
                  Text(name),
                ],
              ),
            ),
        ],
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.color_lens,
                color: drawingColor,
                size: ToolsetLayout.glyph,
              ),
            ],
          ),
        ),
      ),
      button(Icons.undo, 'Undo', onUndo, shortcut: 'Ctrl+Z'),
      button(Icons.redo, 'Redo', onRedo, shortcut: 'Ctrl+Shift+Z'),
      PopupMenuButton<String>(
        tooltip: 'Drawing options',
        icon: const Icon(Icons.more_horiz),
        onSelected: (action) {
          if (action == 'clear') onClearDrawing();
          if (action.startsWith('width:')) {
            onWidthChange?.call(double.parse(action.substring(6)));
          }
        },
        itemBuilder: (_) => [
          if (onWidthChange != null && currentTool != DrawingTool.laser) ...[
            for (final width in [3.0, 5.0, 8.0])
              CheckedPopupMenuItem(
                value: 'width:$width',
                checked: strokeWidth == width,
                child: Text('${width.toInt()} px stroke'),
              ),
            const PopupMenuDivider(),
          ],
          const PopupMenuItem(value: 'clear', child: Text('Clear drawings')),
        ],
      ),
    ];
    return ToolActionGrid(title: 'Drawing', layout: layout, children: controls);
  }
}
