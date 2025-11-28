import 'package:flutter/material.dart';
import '../models/drawing_models.dart';
import '../painters/drawing_painter.dart';

class DrawingInteractionOverlay extends StatefulWidget {
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final Color drawingColor;
  final double strokeWidth;
  final Function(DrawingStroke) onStrokeCompleted;
  final Function(LineShape) onLineCompleted;
  final Function(ArrowShape) onArrowCompleted;
  final VoidCallback onClearDrawing;

  const DrawingInteractionOverlay({
    super.key,
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingColor,
    required this.strokeWidth,
    required this.onStrokeCompleted,
    required this.onLineCompleted,
    required this.onArrowCompleted,
    required this.onClearDrawing,
  });

  @override
  State<DrawingInteractionOverlay> createState() =>
      _DrawingInteractionOverlayState();
}

class _DrawingInteractionOverlayState extends State<DrawingInteractionOverlay> {
  List<DrawingPoint> _currentStroke = [];
  Offset? _lineStart;
  Offset? _currentDrawPosition;

  void _onPanStart(DragStartDetails details) {
    if (!widget.isDrawingMode) return;
    setState(() {
      if (widget.currentTool == DrawingTool.freehand) {
        _currentStroke = [
          DrawingPoint(
            details.localPosition,
            widget.drawingColor,
            widget.strokeWidth,
          ),
        ];
      } else {
        _lineStart = details.localPosition;
        _currentDrawPosition = details.localPosition;
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isDrawingMode) return;
    setState(() {
      if (widget.currentTool == DrawingTool.freehand) {
        _currentStroke.add(
          DrawingPoint(
            details.localPosition,
            widget.drawingColor,
            widget.strokeWidth,
          ),
        );
      } else {
        _currentDrawPosition = details.localPosition;
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isDrawingMode) return;

    if (widget.currentTool == DrawingTool.freehand &&
        _currentStroke.isNotEmpty) {
      widget.onStrokeCompleted(
        DrawingStroke(
          List.from(_currentStroke),
          widget.drawingColor,
          widget.strokeWidth,
        ),
      );
      setState(() => _currentStroke = []);
    } else if (widget.currentTool == DrawingTool.line &&
        _lineStart != null &&
        _currentDrawPosition != null) {
      widget.onLineCompleted(
        LineShape(
          _lineStart!,
          _currentDrawPosition!,
          widget.drawingColor,
          widget.strokeWidth,
        ),
      );
      setState(() {
        _lineStart = null;
        _currentDrawPosition = null;
      });
    } else if (widget.currentTool == DrawingTool.arrow &&
        _lineStart != null &&
        _currentDrawPosition != null) {
      widget.onArrowCompleted(
        ArrowShape(
          _lineStart!,
          _currentDrawPosition!,
          widget.drawingColor,
          widget.strokeWidth,
        ),
      );
      setState(() {
        _lineStart = null;
        _currentDrawPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: widget.isDrawingMode ? widget.onClearDrawing : null,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: DrawingPainter(
            [], // No completed strokes here
            [], // No completed lines here
            [], // No completed arrows here
            _currentStroke,
            _lineStart,
            _currentDrawPosition,
            widget.drawingColor,
            widget.strokeWidth,
            widget.currentTool,
          ),
          child: Container(), // Fill space
        ),
      ),
    );
  }
}
