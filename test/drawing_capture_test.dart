import 'package:flow_lens/models/drawing_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture reduces nearby points and flushes the final position', () {
    final capture = DrawingCaptureBuffer();
    capture.start(const DrawingPoint(Offset.zero, Colors.red, 4));
    expect(
      capture.add(const DrawingPoint(Offset(2, 0), Colors.red, 4)),
      isFalse,
    );
    expect(
      capture.add(const DrawingPoint(Offset(6, 0), Colors.red, 4)),
      isTrue,
    );

    final stroke = capture.finish(const Offset(7, 0), Colors.red, 4)!;
    expect(stroke.points.map((point) => point.offset), [
      Offset.zero,
      const Offset(6, 0),
      const Offset(7, 0),
    ]);
    expect(capture.isEmpty, isTrue);
  });
}
