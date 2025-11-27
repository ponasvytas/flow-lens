import 'package:flutter/material.dart';

enum DrawingTool { freehand, line, arrow, laser }

class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawingPoint(this.offset, this.color, this.strokeWidth);
}

class DrawingStroke {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke(this.points, this.color, this.strokeWidth);
}

class LineShape {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  LineShape(this.start, this.end, this.color, this.strokeWidth);
}

class ArrowShape {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  ArrowShape(this.start, this.end, this.color, this.strokeWidth);
}

class LaserTrail {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final DateTime startTime;
  double animationProgress; // 0.0 to 1.0, how much has been erased
  bool isAnimating;

  LaserTrail(this.points, this.color, this.strokeWidth, this.startTime)
    : animationProgress = 0.0,
      isAnimating = false;
}
