import 'package:flutter/material.dart';
import '../main.dart'; // For DrawingPoint, LaserTrail, LaserPainter

/// Laser pointer overlay with cursor tracking and trail drawing
/// Manages its own cursor position state to avoid parent rebuilds
class LaserPointerOverlay extends StatefulWidget {
  final bool isActive;
  final bool isDrawingMode;
  final List<LaserTrail> trails;
  final Color color;
  final double strokeWidth;
  final Function(List<DrawingPoint>) onCompleteDrawing;

  const LaserPointerOverlay({
    required this.isActive,
    required this.isDrawingMode,
    required this.trails,
    required this.color,
    required this.strokeWidth,
    required this.onCompleteDrawing,
    super.key,
  });

  @override
  State<LaserPointerOverlay> createState() => _LaserPointerOverlayState();
}

class _LaserPointerOverlayState extends State<LaserPointerOverlay> {
  Offset? _cursorPosition;
  List<DrawingPoint> _currentStroke = [];
  DateTime? _lastCursorUpdate;
  DateTime? _lastDragUpdate;

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return const SizedBox.shrink();
    }

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * (9 / 16),
        child: IgnorePointer(
          ignoring: !widget.isDrawingMode,
          child: MouseRegion(
            cursor: SystemMouseCursors.none, // Hide system cursor in laser mode
            onHover: (event) {
              if (widget.isDrawingMode) {
                // Throttle cursor updates to max 20 updates/sec for performance
                final now = DateTime.now();
                if (_lastCursorUpdate == null ||
                    now.difference(_lastCursorUpdate!) > const Duration(milliseconds: 50)) {
                  setState(() {
                    // ⭐ Only rebuilds THIS widget, not parent!
                    _cursorPosition = event.localPosition;
                  });
                  _lastCursorUpdate = now;
                }
              }
            },
            onExit: (event) {
              setState(() {
                _cursorPosition = null;
              });
            },
            child: GestureDetector(
              onPanStart: (details) {
                if (widget.isDrawingMode) {
                  setState(() {
                    _cursorPosition = details.localPosition;
                    _currentStroke = [DrawingPoint(
                      details.localPosition,
                      widget.color,
                      widget.strokeWidth,
                    )];
                  });
                }
              },
              onPanUpdate: (details) {
                if (widget.isDrawingMode) {
                  // Throttle setState updates during drawing for performance
                  final now = DateTime.now();
                  if (_lastDragUpdate == null ||
                      now.difference(_lastDragUpdate!) > const Duration(milliseconds: 16)) {
                    setState(() {
                      _cursorPosition = details.localPosition;
                      _currentStroke.add(DrawingPoint(
                        details.localPosition,
                        widget.color,
                        widget.strokeWidth,
                      ));
                    });
                    _lastDragUpdate = now;
                  } else {
                    // Still update stroke without setState for smoothness
                    _currentStroke.add(DrawingPoint(
                      details.localPosition,
                      widget.color,
                      widget.strokeWidth,
                    ));
                  }
                }
              },
              onPanEnd: (details) {
                if (widget.isDrawingMode && _currentStroke.isNotEmpty) {
                  // Pass complete stroke to parent
                  widget.onCompleteDrawing(List.from(_currentStroke));
                  setState(() {
                    _currentStroke = [];
                  });
                }
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: LaserPainter(
                    widget.trails,
                    _currentStroke,
                    _cursorPosition,
                    widget.color,
                    widget.strokeWidth,
                    widget.isDrawingMode,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
