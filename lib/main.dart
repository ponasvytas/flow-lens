import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html show Blob, Url;
import 'dart:typed_data' show Uint8List;
import 'dart:math' show atan2, cos, sin;

import 'widgets/event_buttons.dart';
import 'widgets/shortcuts_panel.dart';
import 'widgets/video_picker.dart';
import 'widgets/control_bar.dart';
import 'widgets/drawing_tools_panel.dart';
import 'widgets/laser_pointer_overlay.dart';
import 'widgets/video_canvas.dart';

void main() {
  // 1. Initialize MediaKit (Crucial for the native video engine)
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  
  runApp(const MaterialApp(home: HockeyAnalyzerScreen()));
}

class HockeyAnalyzerScreen extends StatefulWidget {
  const HockeyAnalyzerScreen({super.key});

  @override
  State<HockeyAnalyzerScreen> createState() => _HockeyAnalyzerScreenState();
}

// Drawing data structures
enum DrawingTool { freehand, line, arrow, laser }

class DrawingPoint {
  final Offset offset;
  final Color color;
  final double strokeWidth;

  DrawingPoint(this.offset, this.color, this.strokeWidth);
}

class DrawingStroke {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;

  DrawingStroke(this.points, this.color, this.strokeWidth);
}

class LineShape {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  LineShape(this.start, this.end, this.color, this.strokeWidth);
}

class ArrowShape {
  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  ArrowShape(this.start, this.end, this.color, this.strokeWidth);
}

class LaserTrail {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final DateTime startTime;
  double animationProgress; // 0.0 to 1.0, how much has been erased
  bool isAnimating;

  LaserTrail(this.points, this.color, this.strokeWidth, this.startTime)
      : animationProgress = 0.0,
        isAnimating = false;
}

class _HockeyAnalyzerScreenState extends State<HockeyAnalyzerScreen> {
  // Create the Player and Controller
  late final Player player;
  late final VideoController controller;

  // Drawing state
  List<DrawingStroke> drawingStrokes = [];
  List<LineShape> lineShapes = [];
  List<ArrowShape> arrowShapes = [];
  List<DrawingPoint> currentStroke = [];
  Offset? lineStart;
  Offset? currentDrawPosition;
  bool isDrawingMode = false;
  DrawingTool currentTool = DrawingTool.freehand;
  Color drawingColor = Colors.red;
  double strokeWidth = 5.0;
  
  // Laser pointer state
  List<LaserTrail> laserTrails = [];
  static const Duration laserDelayBeforeAnimation = Duration(seconds: 3);
  static const Duration laserAnimationDuration = Duration(seconds: 1);

  // Zoom/Pan state
  final TransformationController _transformationController = TransformationController();
  
  // Video loading state
  bool hasVideoLoaded = false;
  
  // Shortcuts panel visibility
  bool _showShortcuts = false;

  @override
  void initState() {
    super.initState();
    // 2. Configure the player with web-friendly and performance settings
    player = Player(
      configuration: PlayerConfiguration(
        title: 'Hockey Analyzer',
        // Enable GPU acceleration for better performance
        // Try multiple video output backends, fallback to gpu if wgpu not available
        vo: kIsWeb ? 'gpu,wgpu' : 'gpu',
        // Enable logging for debugging
        logLevel: MPVLogLevel.info,
      ),
    );
    controller = VideoController(player);
  }

  @override
  void dispose() {
    player.dispose(); // Always clean up video memory!
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
    );

    if (result != null) {
      setState(() {
        hasVideoLoaded = true;
      });
      
      if (kIsWeb) {
        // Web: Use bytes to create a blob URL
        final Uint8List? bytes = result.files.single.bytes;
        if (bytes != null) {
          final blob = html.Blob([bytes]);
          final url = html.Url.createObjectUrlFromBlob(blob);
          await player.open(Media(url));
          print("Loaded video from blob URL: $url");
        } else {
          print("Error: No bytes available from file picker on web");
        }
      } else {
        // Native platforms: Use file path
        final String? path = result.files.single.path;
        if (path != null) {
          await player.open(Media(path));
          print("Loaded video from path: $path");
        } else {
          print("Error: No file path available");
        }
      }
    }
  }

  Future<void> _loadTestVideo() async {
    setState(() {
      hasVideoLoaded = true;
    });
    
    try {
      // Using a reliable test video that works well on mobile browsers
      const testVideoUrl = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
      // Alternative: Your GitHub video
      // const testVideoUrl = "https://github.com/ponasvytas/hockey-video-analyst/releases/download/v0.0.1-alpha/part5.mp4";
      
      print("Loading test video from: $testVideoUrl");
      await player.open(Media(testVideoUrl));
      print("Successfully loaded test video");
    } catch (e) {
      print("Error loading test video: $e");
      setState(() {
        hasVideoLoaded = false;
      });
    }
  }

  void _changeSpeed(double speed) {
    player.setRate(speed);
    print("Playback speed: ${speed}x");
  }

  void _jumpForward(Duration duration) {
    final currentPosition = player.state.position;
    final newPosition = currentPosition + duration;
    player.seek(newPosition);
    print("Jumped forward ${duration.inSeconds}s to ${newPosition.toString()}");
  }

  void _jumpBackward(Duration duration) {
    final currentPosition = player.state.position;
    final newPosition = currentPosition - duration;
    player.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
    print("Jumped backward ${duration.inSeconds}s to ${newPosition.toString()}");
  }

  void _startDrawing(Offset position) {
    if (!isDrawingMode) return;
    setState(() {
      if (currentTool == DrawingTool.freehand) {
        currentStroke = [DrawingPoint(position, drawingColor, strokeWidth)];
      } else if (currentTool == DrawingTool.line || currentTool == DrawingTool.arrow) {
        lineStart = position;
      }
      // Laser tool handled by LaserPointerOverlay widget
    });
  }

  void _updateDrawing(Offset position) {
    if (!isDrawingMode) return;
    setState(() {
      currentDrawPosition = position;
      if (currentTool == DrawingTool.freehand && currentStroke.isNotEmpty) {
        currentStroke.add(DrawingPoint(position, drawingColor, strokeWidth));
      }
      // Laser tool handled by LaserPointerOverlay widget
      // For line/arrow tools, we don't update until drag ends
    });
  }

  void _endDrawing() {
    if (!isDrawingMode) return;
    setState(() {
      if (currentTool == DrawingTool.freehand && currentStroke.isNotEmpty) {
        drawingStrokes.add(DrawingStroke(List.from(currentStroke), drawingColor, strokeWidth));
        currentStroke = [];
      } else if (currentTool == DrawingTool.line && lineStart != null && currentDrawPosition != null) {
        lineShapes.add(LineShape(lineStart!, currentDrawPosition!, drawingColor, strokeWidth));
        lineStart = null;
      } else if (currentTool == DrawingTool.arrow && lineStart != null && currentDrawPosition != null) {
        arrowShapes.add(ArrowShape(lineStart!, currentDrawPosition!, drawingColor, strokeWidth));
        lineStart = null;
      }
      // Laser tool handled by LaserPointerOverlay widget
      currentDrawPosition = null;
    });
  }
  
  void _completeLaserDrawing(List<DrawingPoint> strokePoints) {
    if (strokePoints.isEmpty) return;
    setState(() {
      // Create laser trail and schedule animation
      final trail = LaserTrail(
        strokePoints,
        drawingColor,
        strokeWidth,
        DateTime.now(),
      );
      laserTrails.add(trail);
      _scheduleLaserAnimation(trail);
    });
  }

  void _clearDrawing() {
    setState(() {
      drawingStrokes.clear();
      lineShapes.clear();
      arrowShapes.clear();
      currentStroke = [];
      lineStart = null;
      laserTrails.clear();
    });
  }
  
  void _scheduleLaserAnimation(LaserTrail trail) {
    // Wait 3 seconds before starting animation
    Future.delayed(laserDelayBeforeAnimation, () {
      if (!mounted || !laserTrails.contains(trail)) return;
      
      trail.isAnimating = true;
      final startTime = DateTime.now();
      
      // Use WidgetsBinding to schedule frame callbacks for smooth animation
      void animate() {
        if (!mounted || !laserTrails.contains(trail)) return;
        
        final elapsed = DateTime.now().difference(startTime);
        final progress = (elapsed.inMilliseconds / laserAnimationDuration.inMilliseconds).clamp(0.0, 1.0);
        
        setState(() {
          trail.animationProgress = progress;
        });
        
        if (progress >= 1.0) {
          // Animation complete, remove trail
          setState(() {
            laserTrails.remove(trail);
          });
        } else {
          // Schedule next frame using WidgetsBinding to ensure continuous updates
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 33), animate);
          });
        }
      }
      
      // Start animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        animate();
      });
    });
  }

  void _toggleDrawingMode() {
    setState(() {
      isDrawingMode = !isDrawingMode;
    });
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _togglePlayPause() {
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void _toggleShortcutsPanel() {
    setState(() {
      _showShortcuts = !_showShortcuts;
      print('Shortcuts panel toggled: $_showShortcuts');
    });
  }

  void _logEvent(String eventType) {
    // This is where you would save the data to your database later
    final position = player.state.position;
    print("EVENT: $eventType at ${position.toString()}");
    
    // Visual feedback: Pause briefly to let user focus?
    // player.pause(); 
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle key press events
        if (event is KeyDownEvent) {
          // Toggle play/pause when spacebar is pressed
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }
          // Clear drawings when 'C' key is pressed
          if (event.logicalKey == LogicalKeyboardKey.keyC) {
            _clearDrawing();
            return KeyEventResult.handled;
          }
          // Toggle laser pointer when 'K' key is pressed
          if (event.logicalKey == LogicalKeyboardKey.keyK) {
            setState(() {
              if (currentTool == DrawingTool.laser) {
                currentTool = DrawingTool.freehand;
              } else {
                currentTool = DrawingTool.laser;
                if (!isDrawingMode) {
                  isDrawingMode = true;
                }
              }
            });
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        // The Stack widget allows us to layer items on top of each other
        children: [
          
          // LAYER 1: Video Canvas with Zoom/Pan and Drawing
          VideoCanvas(
            controller: controller,
            transformationController: _transformationController,
            isDrawingMode: isDrawingMode,
            currentTool: currentTool,
            drawingStrokes: drawingStrokes,
            lineShapes: lineShapes,
            arrowShapes: arrowShapes,
            currentStroke: currentStroke,
            lineStart: lineStart,
            currentDrawPosition: currentDrawPosition,
            drawingColor: drawingColor,
            strokeWidth: strokeWidth,
            onStartDrawing: _startDrawing,
            onUpdateDrawing: _updateDrawing,
            onEndDrawing: _endDrawing,
            onClearDrawing: _clearDrawing,
          ),
          
          // LAYER 2: Laser trails and cursor (No zoom scaling - overlay)
          if (hasVideoLoaded)
            LaserPointerOverlay(
              isActive: true,
              isDrawingMode: isDrawingMode,
              trails: laserTrails,
              color: drawingColor,
              strokeWidth: strokeWidth,
              onCompleteDrawing: _completeLaserDrawing,
            ),
          
          // LAYER 3: Playback Controls (Centered at top) - Draggable
          if (hasVideoLoaded)
            DraggableControlBar(
              player: player,
              onSpeedChange: _changeSpeed,
              onJumpForward: _jumpForward,
              onJumpBackward: _jumpBackward,
              onTogglePlayPause: _togglePlayPause,
            ),
          
          // LAYER 4: Drawing Controls (Right Side)
          if (hasVideoLoaded)
            DrawingToolsPanel(
              isDrawingMode: isDrawingMode,
              currentTool: currentTool,
              drawingColor: drawingColor,
              onToggleDrawingMode: _toggleDrawingMode,
              onResetZoom: _resetZoom,
              onClearDrawing: _clearDrawing,
              onToolChange: (tool) => setState(() => currentTool = tool),
              onColorChange: (color) => setState(() => drawingColor = color),
            ),
          
          // LAYER 5: Event Buttons (Shot/Turnover tracking)
          EventButtons(
            onShot: () => _logEvent("SHOT"),
            onTurnover: () => _logEvent("TURNOVER"),
          ),

          // LAYER 6 & 7: Shortcuts Panel with Toggle Button
          if (hasVideoLoaded)
            ShortcutsPanel(
              isVisible: _showShortcuts,
              onToggle: _toggleShortcutsPanel,
            ),

          // Video Picker (shown when no video is loaded)
          if (!hasVideoLoaded)
            VideoPicker(
              onPickVideo: _pickVideo,
              onLoadTestVideo: _loadTestVideo,
            ),
        ],
      ),
      ),
    );
  }
}

// Custom painter for drawing on video
class DrawingPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final List<LineShape> lines;
  final List<ArrowShape> arrows;
  final List<DrawingPoint> currentStroke;
  final Offset? lineStart;
  final Offset? lineEnd;
  final Color drawingColor;
  final double strokeWidth;
  final DrawingTool currentTool;

  DrawingPainter(
    this.strokes,
    this.lines,
    this.arrows,
    this.currentStroke,
    this.lineStart,
    this.lineEnd,
    this.drawingColor,
    this.strokeWidth,
    this.currentTool,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed freehand strokes
    for (var stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(stroke.points.first.offset.dx, stroke.points.first.offset.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].offset.dx, stroke.points[i].offset.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw completed lines
    for (var line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(line.start, line.end, paint);
    }

    // Draw completed arrows
    for (var arrow in arrows) {
      final paint = Paint()
        ..color = arrow.color
        ..strokeWidth = arrow.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Draw the line
      canvas.drawLine(arrow.start, arrow.end, paint);

      // Draw arrowhead
      _drawArrowhead(canvas, arrow.start, arrow.end, paint);
    }

    // Draw current freehand stroke being drawn
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentStroke.first.color
        ..strokeWidth = currentStroke.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentStroke.first.offset.dx, currentStroke.first.offset.dy);
      for (var i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].offset.dx, currentStroke[i].offset.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw preview line/arrow while dragging
    if (lineStart != null && lineEnd != null) {
      final paint = Paint()
        ..color = drawingColor.withOpacity(0.7)
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(lineStart!, lineEnd!, paint);

      // Draw preview arrowhead if arrow tool is selected
      if (currentTool == DrawingTool.arrow) {
        _drawArrowhead(canvas, lineStart!, lineEnd!, paint);
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Offset start, Offset end, Paint paint) {
    const arrowSize = 15.0;
    const arrowAngle = 25 * 3.1415926535 / 180; // 25 degrees in radians

    // Calculate direction vector
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = atan2(dy, dx);

    // Calculate arrowhead points
    final arrowPoint1 = Offset(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );
    final arrowPoint2 = Offset(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );

    // Draw arrowhead lines
    canvas.drawLine(end, arrowPoint1, paint);
    canvas.drawLine(end, arrowPoint2, paint);
  }

  @override
  bool shouldRepaint(DrawingPainter oldDelegate) {
    return strokes != oldDelegate.strokes ||
        lines != oldDelegate.lines ||
        arrows != oldDelegate.arrows ||
        currentStroke != oldDelegate.currentStroke ||
        lineStart != oldDelegate.lineStart ||
        lineEnd != oldDelegate.lineEnd ||
        drawingColor != oldDelegate.drawingColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        currentTool != oldDelegate.currentTool;
  }
}

// Custom painter for laser pointer trails and cursor
class LaserPainter extends CustomPainter {
  final List<LaserTrail> trails;
  final List<DrawingPoint> currentStroke;
  final Offset? cursorPosition;
  final Color cursorColor;
  final double strokeWidth;
  final bool showCursor;

  LaserPainter(
    this.trails,
    this.currentStroke,
    this.cursorPosition,
    this.cursorColor,
    this.strokeWidth,
    this.showCursor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed laser trails with animation
    for (var trail in trails) {
      if (trail.points.isEmpty) continue;
      
      final paint = Paint()
        ..color = trail.color
        ..strokeWidth = trail.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      // Calculate how many points to show based on animation progress
      final totalPoints = trail.points.length;
      final erasedPoints = (totalPoints * trail.animationProgress).floor();
      final visiblePoints = totalPoints - erasedPoints;
      
      if (visiblePoints > 1) {
        final path = Path();
        path.moveTo(trail.points[erasedPoints].offset.dx, trail.points[erasedPoints].offset.dy);
        
        for (var i = erasedPoints + 1; i < totalPoints; i++) {
          path.lineTo(trail.points[i].offset.dx, trail.points[i].offset.dy);
        }
        
        canvas.drawPath(path, paint);
      }
    }

    // Draw current stroke being drawn
    if (currentStroke.isNotEmpty) {
      final paint = Paint()
        ..color = currentStroke.first.color
        ..strokeWidth = currentStroke.first.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(currentStroke.first.offset.dx, currentStroke.first.offset.dy);
      for (var i = 1; i < currentStroke.length; i++) {
        path.lineTo(currentStroke[i].offset.dx, currentStroke[i].offset.dy);
      }
      canvas.drawPath(path, paint);
    }

    // Draw laser cursor dot
    if (showCursor && cursorPosition != null) {
      final cursorPaint = Paint()
        ..color = cursorColor
        ..style = PaintingStyle.fill;
      
      // Draw a glowing effect with multiple circles
      final glowPaint = Paint()
        ..color = cursorColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(cursorPosition!, 12, glowPaint);
      canvas.drawCircle(cursorPosition!, 8, cursorPaint);
      
      // Draw a white center for visibility
      final centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(cursorPosition!, 3, centerPaint);
    }
  }

  @override
  bool shouldRepaint(LaserPainter oldDelegate) {
    // Always repaint if trails exist (they might be animating)
    if (trails.isNotEmpty || oldDelegate.trails.isNotEmpty) {
      return true;
    }
    
    return currentStroke != oldDelegate.currentStroke ||
        cursorPosition != oldDelegate.cursorPosition ||
        cursorColor != oldDelegate.cursorColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        showCursor != oldDelegate.showCursor;
  }
}