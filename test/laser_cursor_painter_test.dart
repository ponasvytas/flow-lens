import 'package:flow_lens/painters/laser_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cursor movement requests paint without replacing the painter', () {
    final position = ValueNotifier<Offset?>(Offset.zero);
    final painter = LaserCursorPainter(
      position: position,
      color: Colors.red,
      visible: true,
    );
    var repaintCount = 0;
    painter.addListener(() => repaintCount++);

    position.value = const Offset(1, 1);
    position.value = const Offset(2, 2);

    expect(repaintCount, 2);
    position.dispose();
  });
}
