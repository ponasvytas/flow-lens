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

  DrawingPainter(
    this.strokes,
    this.lines,
    this.arrows,
    this.currentStroke,
    this.lineStart,
    this.lineEnd,
    this.drawingColor,
    this.strokeWidth,
    this.currentTool,
  );

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

      final path = Path();
      final points = _reducePoints(stroke.points.map((p) => p.offset).toList());

      if (points.isEmpty) continue;
      path.moveTo(points.first.dx, points.first.dy);

      // Use quadratic curves for smooth lines
      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final controlPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

        if (i == 1) {
          path.lineTo(controlPoint.dx, controlPoint.dy);
        } else {
          path.quadraticBezierTo(
            p0.dx,
            p0.dy,
            controlPoint.dx,
            controlPoint.dy,
          );
        }
      }
      // Draw final segment
      if (points.length > 1) {
        path.lineTo(points.last.dx, points.last.dy);
      }

      canvas.drawPath(path, paint);
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
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentStroke.first.color
        ..strokeWidth = currentStroke.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      final points = _reducePoints(currentStroke.map((p) => p.offset).toList());

      if (points.isEmpty) return;
      path.moveTo(points.first.dx, points.first.dy);

      // Use quadratic curves for smooth lines
      for (var i = 1; i < points.length; i++) {
        final p0 = points[i - 1];
        final p1 = points[i];
        final controlPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);

        if (i == 1) {
          path.lineTo(controlPoint.dx, controlPoint.dy);
        } else {
          path.quadraticBezierTo(
            p0.dx,
            p0.dy,
            controlPoint.dx,
            controlPoint.dy,
          );
        }
      }
      // Draw final segment
      if (points.length > 1) {
        path.lineTo(points.last.dx, points.last.dy);
      }

      canvas.drawPath(path, paint);
    }

    // Draw preview line/arrow while dragging
    if (lineStart != null && lineEnd != null) {
      final paint = Paint()
        ..color = drawingColor.withOpacity(0.7)
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

  // Reduce points by filtering out those too close together
  List<Offset> _reducePoints(List<Offset> points, {double minDistance = 5.0}) {
    if (points.length <= 2) return points;

    final reduced = <Offset>[points.first];

    for (var i = 1; i < points.length; i++) {
      final lastPoint = reduced.last;
      final currentPoint = points[i];
      final distance = (currentPoint - lastPoint).distance;

      if (distance >= minDistance) {
        reduced.add(currentPoint);
      }
    }

    // Always include the last point
    if (reduced.last != points.last) {
      reduced.add(points.last);
    }

    return reduced;
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        lines != oldDelegate.lines ||
        arrows != oldDelegate.arrows ||
        currentStroke != oldDelegate.currentStroke ||
        lineStart != oldDelegate.lineStart ||
        lineEnd != oldDelegate.lineEnd ||
        drawingColor != oldDelegate.drawingColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        currentTool != oldDelegate.currentTool;
  }
}
