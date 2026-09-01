import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/drawing_models.dart';

class LaserPainter extends CustomPainter {
  final List<LaserTrail> trails;
  final List<DrawingPoint> currentStroke;
  final Offset? cursorPosition;
  final Color cursorColor;
  final double strokeWidth;
  final bool showCursor;
  final DrawingCaptureBuffer? activeCapture;
  final Map<LaserTrail, Animation<double>> trailAnimations;

  LaserPainter(
    this.trails,
    this.currentStroke,
    this.cursorPosition,
    this.cursorColor,
    this.strokeWidth,
    this.showCursor, {
    this.activeCapture,
    this.trailAnimations = const <LaserTrail, Animation<double>>{},
  }) : super(
         repaint: Listenable.merge(<Listenable>[
           ?activeCapture,
           ...trailAnimations.values,
         ]),
       );

  @override
  void paint(Canvas canvas, Size size) {
    for (final trail in trails) {
      if (trail.points.isEmpty) continue;
      final paint = Paint()
        ..color = trail.color
        ..strokeWidth = trail.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final progress = trailAnimations[trail]?.value ?? 0.0;
      final firstVisible = (trail.points.length * progress).floor();
      if (firstVisible >= trail.points.length - 1) continue;
      final path = Path()
        ..moveTo(
          trail.points[firstVisible].offset.dx,
          trail.points[firstVisible].offset.dy,
        );
      for (var index = firstVisible + 1; index < trail.points.length; index++) {
        path.lineTo(
          trail.points[index].offset.dx,
          trail.points[index].offset.dy,
        );
      }
      canvas.drawPath(path, paint);
    }

    final activePoints = activeCapture?.points ?? currentStroke;
    if (activePoints.isNotEmpty) {
      final paint = Paint()
        ..color = activePoints.first.color
        ..strokeWidth = activePoints.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        activeCapture?.path ?? buildDrawingPath(activePoints),
        paint,
      );
    }

    if (showCursor && cursorPosition != null) {
      canvas.drawCircle(
        cursorPosition!,
        12,
        Paint()..color = cursorColor.withValues(alpha: 0.3),
      );
      canvas.drawCircle(cursorPosition!, 8, Paint()..color = cursorColor);
      canvas.drawCircle(cursorPosition!, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(LaserPainter oldDelegate) {
    return trails.length != oldDelegate.trails.length ||
        activeCapture != oldDelegate.activeCapture ||
        currentStroke.length != oldDelegate.currentStroke.length ||
        cursorPosition != oldDelegate.cursorPosition ||
        cursorColor != oldDelegate.cursorColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        showCursor != oldDelegate.showCursor;
  }
}

/// Lightweight cursor-only layer. Pointer movement schedules paint directly
/// without rebuilding widgets or repainting fading trails.
class LaserCursorPainter extends CustomPainter {
  LaserCursorPainter({
    required this.position,
    required this.color,
    required this.visible,
  }) : _glowPaint = Paint()..color = color.withValues(alpha: 0.3),
       _cursorPaint = Paint()..color = color,
       _centerPaint = Paint()..color = Colors.white,
       super(repaint: position);

  final ValueListenable<Offset?> position;
  final Color color;
  final bool visible;
  final Paint _glowPaint;
  final Paint _cursorPaint;
  final Paint _centerPaint;

  @override
  void paint(Canvas canvas, Size size) {
    final point = position.value;
    if (!visible || point == null) return;
    canvas.drawCircle(point, 12, _glowPaint);
    canvas.drawCircle(point, 8, _cursorPaint);
    canvas.drawCircle(point, 3, _centerPaint);
  }

  @override
  bool shouldRepaint(LaserCursorPainter oldDelegate) =>
      position != oldDelegate.position ||
      color != oldDelegate.color ||
      visible != oldDelegate.visible;
}
