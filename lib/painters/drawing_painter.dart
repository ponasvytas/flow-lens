import 'package:flutter/material.dart';
import 'dart:math' show atan2, cos, sin;
import '../models/drawing_models.dart';

// Custom painter for drawing on video
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<LineShape> lines;
  final List<ArrowShape> arrows;
  final List<DrawingPoint> currentStroke;
  final Offset? lineStart;
  final Offset? lineEnd;
  final Color drawingColor;
  final double strokeWidth;
  final DrawingTool currentTool;
  final DrawingCaptureBuffer? activeCapture;

  /// Monotonically increasing counter — bump whenever content changes.
  /// Avoids unreliable list reference equality checks.
  final int revision;

  DrawingPainter(
    this.strokes,
    this.lines,
    this.arrows,
    this.currentStroke,
    this.lineStart,
    this.lineEnd,
    this.drawingColor,
    this.strokeWidth,
    this.currentTool, {
    this.revision = 0,
    this.activeCapture,
  }) : super(repaint: activeCapture);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed freehand strokes
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(stroke.path, paint);
    }

    // Draw completed lines
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(line.start, line.end, paint);
    }

    // Draw completed arrows
    for (var arrow in arrows) {
      final paint = Paint()
        ..color = arrow.color
        ..strokeWidth = arrow.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Draw the line
      canvas.drawLine(arrow.start, arrow.end, paint);

      // Draw arrowhead
      _drawArrowhead(canvas, arrow.start, arrow.end, paint);
    }

    // Draw current freehand stroke being drawn
    final activePoints = activeCapture?.points ?? currentStroke;
    if (activePoints.isNotEmpty) {
      final paint = Paint()
        ..color = activePoints.first.color
        ..strokeWidth = activePoints.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = activeCapture?.path ?? buildDrawingPath(activePoints);
      canvas.drawPath(path, paint);
    }

    // Draw preview line/arrow while dragging
    if (lineStart != null && lineEnd != null) {
      final paint = Paint()
        ..color = drawingColor.withValues(alpha: 0.7)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(lineStart!, lineEnd!, paint);

      // Draw preview arrowhead if arrow tool is selected
      if (currentTool == DrawingTool.arrow) {
        _drawArrowhead(canvas, lineStart!, lineEnd!, paint);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 15.0;
    const arrowAngle = 25 * 3.1415926535 / 180; // 25 degrees in radians

    // Calculate direction vector
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);

    // Calculate arrowhead points
    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );
    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );

    // Draw arrowhead lines
    canvas.drawLine(end, arrowPoint1, paint);
    canvas.drawLine(end, arrowPoint2, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return revision != oldDelegate.revision ||
        currentStroke.length != oldDelegate.currentStroke.length ||
        lineStart != oldDelegate.lineStart ||
        lineEnd != oldDelegate.lineEnd ||
        drawingColor != oldDelegate.drawingColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        currentTool != oldDelegate.currentTool;
  }
}
