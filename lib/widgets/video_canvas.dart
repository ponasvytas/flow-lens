import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/drawing_models.dart';
import '../painters/drawing_painter.dart';
import 'drawing_interaction_overlay.dart';

/// Video canvas with zoom/pan and drawing layer for non-laser tools
class VideoCanvas extends StatelessWidget {
  final VideoController controller;
  final TransformationController transformationController;
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final List<DrawingStroke> drawingStrokes;
  final List<LineShape> lineShapes;
  final List<ArrowShape> arrowShapes;
  final Color drawingColor;
  final double strokeWidth;
  final Function(DrawingStroke) onStrokeCompleted;
  final Function(LineShape) onLineCompleted;
  final Function(ArrowShape) onArrowCompleted;
  final VoidCallback onClearDrawing;

  const VideoCanvas({
    required this.controller,
    required this.transformationController,
    required this.isDrawingMode,
    required this.currentTool,
    required this.drawingStrokes,
    required this.lineShapes,
    required this.arrowShapes,
    required this.drawingColor,
    required this.strokeWidth,
    required this.onStrokeCompleted,
    required this.onLineCompleted,
    required this.onArrowCompleted,
    required this.onClearDrawing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: transformationController,
        panEnabled: !isDrawingMode, // Disable pan when drawing
        scaleEnabled:
            !isDrawingMode, // Enable default scroll zoom when not drawing
        minScale: 1.0,
        maxScale: 10.0, // Increased max zoom
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * (9 / 16),
          child: Stack(
            children: [
              // Video layer with built-in controls and progress bar
              MaterialVideoControlsTheme(
                normal: MaterialVideoControlsThemeData(
                  // Hide unwanted buttons
                  topButtonBar:
                      [], // Remove all top buttons (PIP, enhance, transcribe, etc.)
                  displaySeekBar: true,
                  automaticallyImplySkipNextButton: false,
                  automaticallyImplySkipPreviousButton: false,
                ),
                fullscreen: const MaterialVideoControlsThemeData(
                  topButtonBar: [], // Also hide in fullscreen
                ),
                child: Video(
                  controller: controller,
                  controls: MaterialDesktopVideoControls,
                ),
              ),

              // Drawing layer - always show existing drawings
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: DrawingPainter(
                        drawingStrokes,
                        lineShapes,
                        arrowShapes,
                        [],
                        null,
                        null,
                        drawingColor,
                        strokeWidth,
                        currentTool,
                      ),
                    ),
                  ),
                ),
              ),

              // Interaction Layer (Active drawing)
              if (isDrawingMode && currentTool != DrawingTool.laser)
                Positioned.fill(
                  child: DrawingInteractionOverlay(
                    isDrawingMode: isDrawingMode,
                    currentTool: currentTool,
                    drawingColor: drawingColor,
                    strokeWidth: strokeWidth,
                    onStrokeCompleted: onStrokeCompleted,
                    onLineCompleted: onLineCompleted,
                    onArrowCompleted: onArrowCompleted,
                    onClearDrawing: onClearDrawing,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
