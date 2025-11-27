import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

// Custom painter for laser pointer trails and cursor
class LaserPainter extends CustomPainter {
  final List<LaserTrail> trails;
  final List<DrawingPoint> currentStroke;
  final Offset? cursorPosition;
  final Color cursorColor;
  final double strokeWidth;
  final bool showCursor;

  LaserPainter(
    this.trails,
    this.currentStroke,
    this.cursorPosition,
    this.cursorColor,
    this.strokeWidth,
    this.showCursor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed laser trails with animation
    for (var trail in trails) {
      if (trail.points.isEmpty) continue;

      final paint = Paint()
        ..color = trail.color
        ..strokeWidth = trail.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Calculate how many points to show based on animation progress
      final totalPoints = trail.points.length;
      final erasedPoints = (totalPoints * trail.animationProgress).floor();
      final visiblePoints = totalPoints - erasedPoints;

      if (visiblePoints > 1) {
        final path = Path();
        path.moveTo(
          trail.points[erasedPoints].offset.dx,
          trail.points[erasedPoints].offset.dy,
        );

        for (var i = erasedPoints + 1; i < totalPoints; i++) {
          path.lineTo(trail.points[i].offset.dx, trail.points[i].offset.dy);
        }

        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke being drawn
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentStroke.first.color
        ..strokeWidth = currentStroke.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentStroke.first.offset.dx, currentStroke.first.offset.dy);
      for (var i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].offset.dx, currentStroke[i].offset.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw laser cursor dot
    if (showCursor && cursorPosition != null) {
      final cursorPaint = Paint()
        ..color = cursorColor
        ..style = PaintingStyle.fill;

      // Draw a glowing effect with multiple circles
      final glowPaint = Paint()
        ..color = cursorColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(cursorPosition!, 12, glowPaint);
      canvas.drawCircle(cursorPosition!, 8, cursorPaint);

      // Draw a white center for visibility
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(cursorPosition!, 3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(LaserPainter oldDelegate) {
    // Always repaint if trails exist (they might be animating)
    if (trails.isNotEmpty || oldDelegate.trails.isNotEmpty) {
      return true;
    }

    return currentStroke != oldDelegate.currentStroke ||
        cursorPosition != oldDelegate.cursorPosition ||
        cursorColor != oldDelegate.cursorColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        showCursor != oldDelegate.showCursor;
  }
}
