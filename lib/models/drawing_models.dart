import 'dart:collection';

import 'package:flutter/material.dart';

enum DrawingTool { freehand, line, arrow, laser }

class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  const DrawingPoint(this.offset, this.color, this.strokeWidth);
}

class DrawingStroke {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final Path path;

  DrawingStroke(List<DrawingPoint> points, this.color, this.strokeWidth)
    : points = List<DrawingPoint>.unmodifiable(points),
      path = buildDrawingPath(points);
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

  LaserTrail(
    List<DrawingPoint> points,
    this.color,
    this.strokeWidth,
    this.startTime,
  ) : points = List<DrawingPoint>.unmodifiable(points);
}

Path buildDrawingPath(Iterable<DrawingPoint> points) {
  final iterator = points.iterator;
  final path = Path();
  if (!iterator.moveNext()) return path;
  path.moveTo(iterator.current.offset.dx, iterator.current.offset.dy);
  while (iterator.moveNext()) {
    path.lineTo(iterator.current.offset.dx, iterator.current.offset.dy);
  }
  return path;
}

/// Mutable, repaint-only capture state used while a pointer is down.
///
/// Accepted points are appended in place and the path is extended
/// incrementally. Widget state does not need to rebuild for each point.
class DrawingCaptureBuffer extends ChangeNotifier {
  DrawingCaptureBuffer({this.minDistance = 5.0});

  final double minDistance;
  final List<DrawingPoint> _points = <DrawingPoint>[];
  late final UnmodifiableListView<DrawingPoint> _pointsView =
      UnmodifiableListView<DrawingPoint>(_points);
  Path _path = Path();

  UnmodifiableListView<DrawingPoint> get points => _pointsView;
  Path get path => _path;
  bool get isEmpty => _points.isEmpty;
  DrawingPoint? get lastPoint => _points.isEmpty ? null : _points.last;

  void start(DrawingPoint point) {
    _points
      ..clear()
      ..add(point);
    _path = Path()..moveTo(point.offset.dx, point.offset.dy);
    notifyListeners();
  }

  bool add(DrawingPoint point, {bool force = false}) {
    if (_points.isEmpty) {
      start(point);
      return true;
    }
    final previous = _points.last;
    if (!force && (point.offset - previous.offset).distance < minDistance) {
      return false;
    }
    if (point.offset == previous.offset) return false;
    _points.add(point);
    _path.lineTo(point.offset.dx, point.offset.dy);
    notifyListeners();
    return true;
  }

  DrawingStroke? finish(Offset finalPosition, Color color, double strokeWidth) {
    if (_points.isEmpty) return null;
    add(DrawingPoint(finalPosition, color, strokeWidth), force: true);
    final stroke = DrawingStroke(_points, color, strokeWidth);
    clear();
    return stroke;
  }

  List<DrawingPoint> finishPoints(
    Offset finalPosition,
    Color color,
    double strokeWidth,
  ) {
    if (_points.isEmpty) return const <DrawingPoint>[];
    add(DrawingPoint(finalPosition, color, strokeWidth), force: true);
    final result = List<DrawingPoint>.unmodifiable(_points);
    clear();
    return result;
  }

  void clear() {
    if (_points.isEmpty) return;
    _points.clear();
    _path = Path();
    notifyListeners();
  }
}
