import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../main.dart'; // For DrawingTool, DrawingStroke, LineShape, ArrowShape, DrawingPoint, DrawingPainter

/// Video canvas with zoom/pan and drawing layer for non-laser tools
class VideoCanvas extends StatelessWidget {
  final VideoController controller;
  final TransformationController transformationController;
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final List<DrawingStroke> drawingStrokes;
  final List<LineShape> lineShapes;
  final List<ArrowShape> arrowShapes;
  final List<DrawingPoint> currentStroke;
  final Offset? lineStart;
  final Offset? currentDrawPosition;
  final Color drawingColor;
  final double strokeWidth;
  final Function(Offset) onStartDrawing;
  final Function(Offset) onUpdateDrawing;
  final VoidCallback onEndDrawing;
  final VoidCallback onClearDrawing;

  const VideoCanvas({
    required this.controller,
    required this.transformationController,
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingStrokes,
    required this.lineShapes,
    required this.arrowShapes,
    required this.currentStroke,
    required this.lineStart,
    required this.currentDrawPosition,
    required this.drawingColor,
    required this.strokeWidth,
    required this.onStartDrawing,
    required this.onUpdateDrawing,
    required this.onEndDrawing,
    required this.onClearDrawing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: transformationController,
        panEnabled: !isDrawingMode, // Disable pan when drawing
        scaleEnabled: !isDrawingMode, // Disable zoom when drawing
        minScale: 1.0,
        maxScale: 10.0, // Increased max zoom
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * (9 / 16),
          child: Stack(
            children: [
              // Video layer with RepaintBoundary for performance
              RepaintBoundary(
                child: Video(controller: controller),
              ),
              
              // Drawing layer - always show existing drawings
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: DrawingPainter(
                      drawingStrokes,
                      lineShapes,
                      arrowShapes,
                      currentStroke,
                      lineStart,
                      currentDrawPosition,
                      drawingColor,
                      strokeWidth,
                      currentTool,
                    ),
                  ),
                ),
              ),
              
              // Gesture layer - only for non-laser tools
              if (currentTool != DrawingTool.laser)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !isDrawingMode,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: () {
                        if (isDrawingMode) {
                          onClearDrawing();
                        }
                      },
                      onPanStart: (details) => onStartDrawing(details.localPosition),
                      onPanUpdate: (details) => onUpdateDrawing(details.localPosition),
                      onPanEnd: (details) => onEndDrawing(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
