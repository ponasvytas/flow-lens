import 'package:flow_lens/models/drawing_models.dart';
import 'package:flow_lens/widgets/drawing_interaction_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('double tap clears drawings immediately in drawing mode', (
    tester,
  ) async {
    var clearCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: DrawingInteractionOverlay(
              isDrawingMode: true,
              currentTool: DrawingTool.freehand,
              drawingColor: Colors.red,
              strokeWidth: 4,
              onStrokeCompleted: (_) {},
              onLineCompleted: (_) {},
              onArrowCompleted: (_) {},
              onClearDrawing: () => clearCount++,
            ),
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DrawingInteractionOverlay));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(clearCount, 1);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('double tap is ignored outside drawing mode', (tester) async {
    var clearCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: DrawingInteractionOverlay(
          isDrawingMode: false,
          currentTool: DrawingTool.freehand,
          drawingColor: Colors.red,
          strokeWidth: 4,
          onStrokeCompleted: (_) {},
          onLineCompleted: (_) {},
          onArrowCompleted: (_) {},
          onClearDrawing: () => clearCount++,
        ),
      ),
    );

    final center = tester.getCenter(find.byType(DrawingInteractionOverlay));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pump();

    expect(clearCount, 0);
    await tester.pump(const Duration(milliseconds: 500));
  });
}
