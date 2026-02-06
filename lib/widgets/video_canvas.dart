import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/drawing_models.dart';
import '../painters/drawing_painter.dart';
import 'drawing_interaction_overlay.dart';

/// Widget that intercepts scroll events and prevents them from propagating
class _ScrollInterceptor extends StatelessWidget {
  final void Function(PointerScrollEvent) onScroll;

  const _ScrollInterceptor({required this.onScroll});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          // Resolve/claim this scroll event so it doesn't propagate
          GestureBinding.instance.pointerSignalResolver.register(
            event,
            (event) => onScroll(event as PointerScrollEvent),
          );
        }
      },
      child: const SizedBox.expand(),
    );
  }
}

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

  void _handlePointerSignal(PointerSignalEvent event, BuildContext context) {
    if (isDrawingMode) return; // Don't zoom when drawing

    if (event is PointerScrollEvent) {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final localPosition = renderBox.globalToLocal(event.position);
      final currentScale = transformationController.value.getMaxScaleOnAxis();

      // Determine zoom direction and calculate new scale
      const zoomFactor = 0.1;
      double newScale;
      if (event.scrollDelta.dy < 0) {
        // Scroll up = zoom in
        newScale = (currentScale * (1 + zoomFactor)).clamp(1.0, 10.0);
      } else {
        // Scroll down = zoom out
        newScale = (currentScale * (1 - zoomFactor)).clamp(1.0, 10.0);
      }

      if (newScale == currentScale) return;

      // Calculate the focal point for zoom
      final scaleChange = newScale / currentScale;
      final focalPoint = localPosition;

      // Apply the transformation
      final matrix = transformationController.value.clone();

      // Translate to focal point, scale, then translate back
      matrix.translate(focalPoint.dx, focalPoint.dy);
      matrix.scale(scaleChange);
      matrix.translate(-focalPoint.dx, -focalPoint.dy);

      transformationController.value = matrix;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: transformationController,
        panEnabled: !isDrawingMode, // Disable pan when drawing
        scaleEnabled:
            !isDrawingMode, // Enable pinch-to-zoom for trackpad gestures
        minScale: 1.0,
        maxScale: 6.0, // Increased max zoom
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * (9 / 16),
          child: Stack(
            children: [
              // Video layer - no built-in controls (we have our own UI)
              Video(
                controller: controller,
                controls: NoVideoControls, // Disable all built-in controls
              ),

              // Scroll intercept layer - captures scroll events for zoom
              // and prevents them from reaching video controls (which use scroll for volume)
              if (!isDrawingMode)
                Positioned.fill(
                  child: _ScrollInterceptor(
                    onScroll: (event) => _handlePointerSignal(event, context),
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
