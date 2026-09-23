import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/drawing_controller.dart';
import 'package:flow_lens/models/drawing_models.dart';
import 'package:flow_lens/painters/drawing_painter.dart';
import 'package:flow_lens/utils/video_viewport.dart';

void main() {
  test(
    'resizing preserves zoom and relative pan without mutating the old view',
    () {
      final transform = Matrix4.identity()
        ..setEntry(0, 0, 2)
        ..setEntry(1, 1, 2)
        ..setEntry(0, 3, -80)
        ..setEntry(1, 3, -40);
      final resized = resizeVideoTransform(transform, 800, 400);
      expect(resized.entry(0, 3), -40);
      expect(resized.entry(1, 3), -20);
      expect(resized.entry(0, 0), 2);
      expect(transform.entry(0, 3), -80);
    },
  );
  test('drawing history orders mixed tools and makes clear reversible', () {
    final drawing = DrawingController();
    final stroke = DrawingStroke(
      [const DrawingPoint(Offset.zero, Colors.red, 3)],
      Colors.red,
      3,
    );
    final line = LineShape(Offset.zero, const Offset(20, 10), Colors.white, 5);
    final arrow = ArrowShape(
      Offset.zero,
      const Offset(10, 20),
      Colors.yellow,
      5,
    );
    drawing.addStroke(stroke);
    drawing.addLine(line);
    drawing.addArrow(arrow);
    drawing.addLaserTrail(
      LaserTrail(stroke.points, Colors.red, 3, DateTime.now()),
    );
    drawing.undo();
    expect(drawing.arrows, isEmpty);
    expect(drawing.lines.single, same(line));
    drawing.undo();
    expect(drawing.lines, isEmpty);
    drawing.redo();
    expect(drawing.lines.single, same(line));
    drawing.clearAll();
    expect(drawing.hasDrawing, isFalse);
    expect(drawing.laserTrails, isEmpty);
    drawing.undo();
    expect(drawing.strokes.single, same(stroke));
    expect(drawing.lines.single, same(line));
    expect(drawing.laserTrails, isEmpty);
    drawing.redo();
    expect(drawing.hasDrawing, isFalse);
    drawing.undo();
    drawing.addArrow(arrow);
    expect(drawing.canRedo, isFalse);
    drawing.resetForVideo();
    expect(drawing.canUndo, isFalse);
    expect(drawing.canRedo, isFalse);
    expect(drawing.hasDrawing, isFalse);
    drawing.dispose();
  });

  test('pointer preserves drawings and laser retains its own color', () {
    final drawing = DrawingController();
    drawing.setTool(DrawingTool.arrow);
    drawing.setColor(Colors.red);
    drawing.setTool(DrawingTool.laser);
    drawing.setColor(Colors.yellow);
    drawing.usePointer();
    expect(drawing.isDrawingMode, isFalse);
    drawing.setTool(DrawingTool.arrow);
    expect(drawing.drawingColor, Colors.red);
    expect(drawing.isDrawingMode, isTrue);
    drawing.toggleLaser();
    expect(drawing.drawingColor, Colors.yellow);
    drawing.dispose();
  });

  test(
    'completed drawing follows the video when its viewport doubles',
    () async {
      final line = LineShape(
        const Offset(20, 20),
        const Offset(80, 20),
        Colors.red,
        4,
        canvasSize: const Size(100, 50),
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      DrawingPainter(
        [],
        [line],
        [],
        [],
        null,
        null,
        Colors.red,
        4,
        DrawingTool.line,
      ).paint(canvas, const Size(200, 100));
      final picture = recorder.endRecording();
      final image = await picture.toImage(200, 100);
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(pixels.getUint8((40 * 200 + 100) * 4), 244);
      expect(pixels.getUint8((20 * 200 + 50) * 4 + 3), 0);
      image.dispose();
      picture.dispose();
    },
  );
}
