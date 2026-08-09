import 'dart:async';

import 'package:flutter/material.dart';

import '../models/drawing_models.dart';
import '../painters/laser_painter.dart';

class LaserPointerOverlay extends StatefulWidget {
  final bool isActive;
  final bool isDrawingMode;
  final List<LaserTrail> trails;
  final Color color;
  final double strokeWidth;
  final double videoAspectRatio;
  final Function(List<DrawingPoint>) onCompleteDrawing;
  final Function(LaserTrail) onRemoveTrail;

  const LaserPointerOverlay({
    required this.isActive,
    required this.isDrawingMode,
    required this.trails,
    required this.color,
    required this.strokeWidth,
    required this.videoAspectRatio,
    required this.onCompleteDrawing,
    required this.onRemoveTrail,
    super.key,
  });

  @override
  State<LaserPointerOverlay> createState() => _LaserPointerOverlayState();
}

class _LaserPointerOverlayState extends State<LaserPointerOverlay>
    with TickerProviderStateMixin {
  static const drawingThrottle = Duration(milliseconds: 16);
  static const trailDelay = Duration(milliseconds: 1500);
  static const trailFade = Duration(milliseconds: 1000);

  final DrawingCaptureBuffer _capture = DrawingCaptureBuffer();
  final ValueNotifier<Offset?> _cursorPosition = ValueNotifier<Offset?>(null);
  final Map<LaserTrail, AnimationController> _controllers = {};
  final Map<LaserTrail, Timer> _timers = {};
  Offset? _latestDrawPosition;
  DateTime? _lastTrailUpdate;

  @override
  void initState() {
    super.initState();
    for (final trail in widget.trails) {
      _schedule(trail);
    }
  }

  @override
  void didUpdateWidget(LaserPointerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (final trail in widget.trails) {
      if (!_controllers.containsKey(trail) && !_timers.containsKey(trail)) {
        _schedule(trail);
      }
    }
    final removed = <LaserTrail>{
      ..._controllers.keys,
      ..._timers.keys,
    }.where((trail) => !widget.trails.contains(trail));
    for (final trail in removed.toList()) {
      _timers.remove(trail)?.cancel();
      _controllers.remove(trail)?.dispose();
    }
  }

  void _schedule(LaserTrail trail) {
    _timers[trail] = Timer(trailDelay, () {
      _timers.remove(trail);
      if (!mounted || !widget.trails.contains(trail)) return;
      final controller = AnimationController(vsync: this, duration: trailFade);
      _controllers[trail] = controller;
      controller.addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        _controllers.remove(trail);
        controller.dispose();
        widget.onRemoveTrail(trail);
      });
      setState(() {});
      controller.forward();
    });
  }

  bool _mayCaptureTrailPoint() {
    final now = DateTime.now();
    if (_lastTrailUpdate != null &&
        now.difference(_lastTrailUpdate!) < drawingThrottle) {
      return false;
    }
    _lastTrailUpdate = now;
    return true;
  }

  @override
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _capture.dispose();
    _cursorPosition.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.sizeOf(context).width,
        height: MediaQuery.sizeOf(context).width / widget.videoAspectRatio,
        child: IgnorePointer(
          ignoring: !widget.isActive || !widget.isDrawingMode,
          child: MouseRegion(
            cursor: widget.isActive && widget.isDrawingMode
                ? SystemMouseCursors.none
                : SystemMouseCursors.basic,
            onHover: (event) {
              if (widget.isActive && widget.isDrawingMode) {
                _cursorPosition.value = event.localPosition;
              }
            },
            onExit: (_) {
              if (widget.isActive) _cursorPosition.value = null;
            },
            child: GestureDetector(
              onPanStart: (details) {
                if (!widget.isActive || !widget.isDrawingMode) return;
                _latestDrawPosition = details.localPosition;
                _lastTrailUpdate = DateTime.now();
                _capture.start(
                  DrawingPoint(
                    details.localPosition,
                    widget.color,
                    widget.strokeWidth,
                  ),
                );
                _cursorPosition.value = details.localPosition;
              },
              onPanUpdate: (details) {
                if (!widget.isActive || !widget.isDrawingMode) return;
                _latestDrawPosition = details.localPosition;
                _cursorPosition.value = details.localPosition;
                if (_mayCaptureTrailPoint()) {
                  _capture.add(
                    DrawingPoint(
                      details.localPosition,
                      widget.color,
                      widget.strokeWidth,
                    ),
                  );
                }
              },
              onPanEnd: (_) {
                if (!widget.isActive ||
                    !widget.isDrawingMode ||
                    _capture.isEmpty) {
                  return;
                }
                final points = _capture.finishPoints(
                  _latestDrawPosition ?? _capture.lastPoint!.offset,
                  widget.color,
                  widget.strokeWidth,
                );
                _latestDrawPosition = null;
                if (points.isNotEmpty) widget.onCompleteDrawing(points);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: LaserPainter(
                        widget.trails,
                        const <DrawingPoint>[],
                        null,
                        widget.color,
                        widget.strokeWidth,
                        false,
                        activeCapture: _capture,
                        trailAnimations: <LaserTrail, Animation<double>>{
                          for (final entry in _controllers.entries)
                            entry.key: entry.value,
                        },
                      ),
                    ),
                  ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: LaserCursorPainter(
                        position: _cursorPosition,
                        color: widget.color,
                        visible: widget.isActive && widget.isDrawingMode,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
