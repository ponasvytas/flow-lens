import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/drawing_models.dart';

class DrawingController extends ChangeNotifier {
  bool isDrawingMode = false;
  DrawingTool currentTool = DrawingTool.freehand;
  Color _inkColor = const Color(0xFF753b8f);
  Color _laserColor = Colors.yellow;
  double strokeWidth = 5;
  int revision = 0;
  final List<DrawingStroke> _strokes = [];
  final List<LineShape> _lines = [];
  final List<ArrowShape> _arrows = [];
  final List<LaserTrail> _laserTrails = [];
  final List<_DrawingEdit> _undo = [];
  final List<_DrawingEdit> _redo = [];
  late final strokes = UnmodifiableListView(_strokes);
  late final lines = UnmodifiableListView(_lines);
  late final arrows = UnmodifiableListView(_arrows);
  late final laserTrails = UnmodifiableListView(_laserTrails);
  Color get drawingColor =>
      currentTool == DrawingTool.laser ? _laserColor : _inkColor;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasDrawing =>
      _strokes.isNotEmpty || _lines.isNotEmpty || _arrows.isNotEmpty;

  void usePointer() {
    if (!isDrawingMode) return;
    isDrawingMode = false;
    notifyListeners();
  }

  void toggleDrawingMode() {
    isDrawingMode = !isDrawingMode;
    notifyListeners();
  }

  void setTool(DrawingTool tool) {
    if (currentTool == tool && isDrawingMode) return;
    currentTool = tool;
    isDrawingMode = true;
    notifyListeners();
  }

  void toggleLaser() {
    if (currentTool == DrawingTool.laser && isDrawingMode) {
      usePointer();
    } else {
      setTool(DrawingTool.laser);
    }
  }

  void setColor(Color color) {
    if (drawingColor == color) return;
    if (currentTool == DrawingTool.laser) {
      _laserColor = color;
    } else {
      _inkColor = color;
    }
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    if (!width.isFinite || width <= 0 || strokeWidth == width) return;
    strokeWidth = width;
    notifyListeners();
  }

  void addStroke(DrawingStroke stroke) => _perform(
    _DrawingEdit(() => _strokes.add(stroke), () => _strokes.removeLast()),
  );
  void addLine(LineShape line) =>
      _perform(_DrawingEdit(() => _lines.add(line), () => _lines.removeLast()));
  void addArrow(ArrowShape arrow) => _perform(
    _DrawingEdit(() => _arrows.add(arrow), () => _arrows.removeLast()),
  );
  void _perform(_DrawingEdit edit) {
    edit.apply();
    _undo.add(edit);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    revision++;
    notifyListeners();
  }

  void undo() {
    if (!canUndo) return;
    final edit = _undo.removeLast();
    edit.revert();
    _redo.add(edit);
    revision++;
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final edit = _redo.removeLast();
    edit.apply();
    _undo.add(edit);
    revision++;
    notifyListeners();
  }

  void clearAll() {
    _laserTrails.clear();
    if (!hasDrawing) {
      notifyListeners();
      return;
    }
    final savedStrokes = List<DrawingStroke>.of(_strokes);
    final savedLines = List<LineShape>.of(_lines);
    final savedArrows = List<ArrowShape>.of(_arrows);
    _perform(
      _DrawingEdit(
        () {
          _strokes.clear();
          _lines.clear();
          _arrows.clear();
        },
        () {
          _strokes.addAll(savedStrokes);
          _lines.addAll(savedLines);
          _arrows.addAll(savedArrows);
        },
      ),
    );
  }

  void resetForVideo() {
    _strokes.clear();
    _lines.clear();
    _arrows.clear();
    _laserTrails.clear();
    _undo.clear();
    _redo.clear();
    isDrawingMode = false;
    revision++;
    notifyListeners();
  }

  void addLaserTrail(LaserTrail trail) {
    _laserTrails.add(trail);
    notifyListeners();
  }

  void removeTrail(LaserTrail trail) {
    if (_laserTrails.remove(trail)) notifyListeners();
  }
}

class _DrawingEdit {
  final VoidCallback apply;
  final VoidCallback revert;
  const _DrawingEdit(this.apply, this.revert);
}
