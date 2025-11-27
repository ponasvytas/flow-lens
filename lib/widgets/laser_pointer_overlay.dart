import 'package:flutter/material.dart';
import '../main.dart'; // For DrawingPoint, LaserTrail, LaserPainter

/// Laser pointer overlay with cursor tracking and trail drawing
/// Manages its own cursor position state AND animations to avoid parent rebuilds
class LaserPointerOverlay extends StatefulWidget {
  final bool isActive;
  final bool isDrawingMode;
  final List<LaserTrail> trails;
  final Color color;
  final double strokeWidth;
  final Function(List<DrawingPoint>) onCompleteDrawing;
  final Function(LaserTrail) onRemoveTrail;

  const LaserPointerOverlay({
    required this.isActive,
    required this.isDrawingMode,
    required this.trails,
    required this.color,
    required this.strokeWidth,
    required this.onCompleteDrawing,
    required this.onRemoveTrail,
    super.key,
  });

  @override
  State<LaserPointerOverlay> createState() => _LaserPointerOverlayState();
}

class _LaserPointerOverlayState extends State<LaserPointerOverlay> 
    with TickerProviderStateMixin {
  Offset? _cursorPosition;
  List<DrawingPoint> _currentStroke = [];
  DateTime? _lastCursorUpdate;
  DateTime? _lastDragUpdate;
  
  // Animation management - each trail gets its own controller
  final Map<LaserTrail, AnimationController> _animationControllers = {};
  
  static const Duration _animationDelay = Duration(milliseconds: 2000);
  static const Duration _animationDuration = Duration(milliseconds: 500);

  @override
  void didUpdateWidget(LaserPointerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check for new trails that need animation
    for (var trail in widget.trails) {
      if (!_animationControllers.containsKey(trail) && !trail.isAnimating) {
        _scheduleAnimation(trail);
      }
    }
    
    // Clean up controllers for removed trails
    final removedTrails = _animationControllers.keys
        .where((trail) => !widget.trails.contains(trail))
        .toList();
    for (var trail in removedTrails) {
      _animationControllers[trail]?.dispose();
      _animationControllers.remove(trail);
    }
  }

  void _scheduleAnimation(LaserTrail trail) {
    // Mark as animating immediately to prevent duplicate scheduling
    trail.isAnimating = true;
    
    // Wait 3 seconds before starting animation
    Future.delayed(_animationDelay, () {
      if (!mounted || !widget.trails.contains(trail)) return;
      
      // Create AnimationController with vsync for smooth frame rendering
      final controller = AnimationController(
        vsync: this,
        duration: _animationDuration,
      );
      
      _animationControllers[trail] = controller;
      
      // Update trail progress on each animation frame
      controller.addListener(() {
        if (mounted) {
          setState(() {
            // ⭐ Only rebuilds LaserPointerOverlay, not parent!
            trail.animationProgress = controller.value;
          });
        }
      });
      
      // Remove trail when animation completes
      controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationControllers.remove(trail);
          controller.dispose();
          // Notify parent to remove trail from list
          widget.onRemoveTrail(trail);
        }
      });
      
      // Start the animation
      controller.forward();
    });
  }

  @override
  void dispose() {
    // Clean up all animation controllers
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    _animationControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * (9 / 16),
        child: IgnorePointer(
          ignoring: !widget.isActive || !widget.isDrawingMode,
          child: MouseRegion(
            cursor: widget.isActive && widget.isDrawingMode ? SystemMouseCursors.none : SystemMouseCursors.basic,
            onHover: (event) {
              if (widget.isActive && widget.isDrawingMode) {
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
              if (widget.isActive) {
                setState(() {
                  _cursorPosition = null;
                });
              }
            },
            child: GestureDetector(
              onPanStart: (details) {
                if (widget.isActive && widget.isDrawingMode) {
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
                if (widget.isActive && widget.isDrawingMode) {
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
                if (widget.isActive && widget.isDrawingMode && _currentStroke.isNotEmpty) {
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
                    widget.isActive && widget.isDrawingMode,
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
