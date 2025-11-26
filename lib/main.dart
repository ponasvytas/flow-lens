import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:html' as html show Blob, Url;
import 'dart:typed_data' show Uint8List;
import 'dart:math' show atan2, cos, sin;

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
  List<DrawingPoint> currentLaserStroke = [];
  Offset? laserCursorPosition;
  static const Duration laserDelayBeforeAnimation = Duration(seconds: 3);
  static const Duration laserAnimationDuration = Duration(seconds: 1);
  
  // Performance: throttle cursor updates
  DateTime? _lastCursorUpdate;
  DateTime? _lastDragUpdate;

  // Zoom/Pan state
  final TransformationController _transformationController = TransformationController();
  
  // Video loading state
  bool hasVideoLoaded = false;
  
  // Control bar position (will be centered on first build)
  Offset? _controlBarPosition;
  
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
      } else if (currentTool == DrawingTool.laser) {
        currentLaserStroke = [DrawingPoint(position, drawingColor, strokeWidth)];
      }
    });
  }

  void _updateDrawing(Offset position) {
    if (!isDrawingMode) return;
    setState(() {
      currentDrawPosition = position;
      if (currentTool == DrawingTool.freehand && currentStroke.isNotEmpty) {
        currentStroke.add(DrawingPoint(position, drawingColor, strokeWidth));
      } else if (currentTool == DrawingTool.laser && currentLaserStroke.isNotEmpty) {
        currentLaserStroke.add(DrawingPoint(position, drawingColor, strokeWidth));
      }
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
      } else if (currentTool == DrawingTool.laser && currentLaserStroke.isNotEmpty) {
        // Create laser trail and schedule animation
        final trail = LaserTrail(
          List.from(currentLaserStroke),
          drawingColor,
          strokeWidth,
          DateTime.now(),
        );
        laserTrails.add(trail);
        currentLaserStroke = [];
        _scheduleLaserAnimation(trail);
      }
      currentDrawPosition = null;
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
      currentLaserStroke = [];
    });
  }
  
  void _scheduleLaserAnimation(LaserTrail trail) {
    // Wait 3 seconds before starting animation
    Future.delayed(laserDelayBeforeAnimation, () {
      if (!mounted || !laserTrails.contains(trail)) return;
      
      trail.isAnimating = true;
      final startTime = DateTime.now();
      
      // Animate the erasure over 1 second
      void animate() {
        if (!mounted || !laserTrails.contains(trail)) return;
        
        final elapsed = DateTime.now().difference(startTime);
        final progress = (elapsed.inMilliseconds / laserAnimationDuration.inMilliseconds).clamp(0.0, 1.0);
        
        setState(() {
          trail.animationProgress = progress;
        });
        
        if (progress < 1.0) {
          Future.delayed(const Duration(milliseconds: 33), animate); // ~30fps for better performance
        } else {
          // Animation complete, remove trail
          setState(() {
            laserTrails.remove(trail);
          });
        }
      }
      
      animate();
    });
  }

  void _toggleDrawingMode() {
    setState(() {
      isDrawingMode = !isDrawingMode;
      // Clear laser cursor when exiting drawing mode
      if (!isDrawingMode) {
        laserCursorPosition = null;
      }
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

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Speed Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Speed: ', style: TextStyle(color: Colors.white)),
              ...[0.25, 0.5, 1.0, 2.0, 3.0].map((speed) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () => _changeSpeed(speed),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(50, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text('${speed}x'),
                ),
              )),
            ],
          ),
          const SizedBox(height: 8),
          // Jump Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Jump Backward
              IconButton(
                onPressed: () => _jumpBackward(const Duration(seconds: 10)),
                icon: const Icon(Icons.replay_10, color: Colors.white),
                tooltip: 'Back 10s (Large)',
              ),
              IconButton(
                onPressed: () => _jumpBackward(const Duration(seconds: 5)),
                icon: const Icon(Icons.replay_5, color: Colors.white),
                tooltip: 'Back 5s (Medium)',
              ),
              IconButton(
                onPressed: () => _jumpBackward(const Duration(seconds: 2)),
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fast_rewind, color: Colors.white, size: 20),
                    Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                tooltip: 'Back 2s (Small)',
              ),
              const SizedBox(width: 8),
              // Play/Pause Button
              StreamBuilder<bool>(
                stream: player.stream.playing,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data ?? false;
                  return IconButton(
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                  );
                },
              ),
              const SizedBox(width: 8),
              // Jump Forward
              IconButton(
                onPressed: () => _jumpForward(const Duration(seconds: 2)),
                icon: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('2', style: TextStyle(color: Colors.white, fontSize: 12)),
                    Icon(Icons.fast_forward, color: Colors.white, size: 20),
                  ],
                ),
                tooltip: 'Forward 2s (Small)',
              ),
              IconButton(
                onPressed: () => _jumpForward(const Duration(seconds: 5)),
                icon: const Icon(Icons.forward_5, color: Colors.white),
                tooltip: 'Forward 5s (Medium)',
              ),
              IconButton(
                onPressed: () => _jumpForward(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10, color: Colors.white),
                tooltip: 'Forward 10s (Large)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsPanel() {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Keyboard Shortcuts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: _toggleShortcutsPanel,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildShortcutRow('Space', 'Play/Pause video'),
          const SizedBox(height: 8),
          _buildShortcutRow('K', 'Toggle laser pointer'),
          const SizedBox(height: 8),
          _buildShortcutRow('C', 'Clear all drawings'),
          const SizedBox(height: 8),
          // Add more shortcuts here as you implement them
          const Text(
            'More shortcuts coming soon...',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow(String key, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade600, width: 1),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Initialize control bar position centered on first build
    _controlBarPosition ??= Offset(
      MediaQuery.of(context).size.width / 2 - 175,
      20,
    );

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
          
          // LAYER 1: The Video Player with Zoom/Pan (Bottom Layer)
          Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
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
                    
                    // Drawing layer (scales with zoom) - for non-laser tools
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !isDrawingMode || currentTool == DrawingTool.laser,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onDoubleTap: () {
                            if (isDrawingMode) {
                              _clearDrawing();
                            }
                          },
                          onPanStart: (details) {
                            if (currentTool != DrawingTool.laser) {
                              _startDrawing(details.localPosition);
                            }
                          },
                          onPanUpdate: (details) {
                            if (currentTool != DrawingTool.laser) {
                              _updateDrawing(details.localPosition);
                            }
                          },
                          onPanEnd: (details) {
                            if (currentTool != DrawingTool.laser) {
                              _endDrawing();
                            }
                          },
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // LAYER 2: Laser trails and cursor (No zoom scaling - overlay)
          if (hasVideoLoaded)
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.width * (9 / 16),
                child: IgnorePointer(
                  ignoring: currentTool != DrawingTool.laser || !isDrawingMode,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.none, // Hide system cursor in laser mode
                    onHover: (event) {
                      if (currentTool == DrawingTool.laser && isDrawingMode) {
                        // Throttle cursor updates to max 20 updates/sec for performance
                        final now = DateTime.now();
                        if (_lastCursorUpdate == null || 
                            now.difference(_lastCursorUpdate!) > const Duration(milliseconds: 50)) {
                          setState(() {
                            laserCursorPosition = event.localPosition;
                          });
                          _lastCursorUpdate = now;
                        }
                      }
                    },
                    onExit: (event) {
                      if (currentTool == DrawingTool.laser) {
                        setState(() {
                          laserCursorPosition = null;
                        });
                      }
                    },
                    child: GestureDetector(
                      onPanStart: (details) {
                        if (currentTool == DrawingTool.laser && isDrawingMode) {
                          setState(() {
                            laserCursorPosition = details.localPosition;
                          });
                          _startDrawing(details.localPosition);
                        }
                      },
                      onPanUpdate: (details) {
                        if (currentTool == DrawingTool.laser && isDrawingMode) {
                          // Throttle updates during drawing
                          final now = DateTime.now();
                          if (_lastDragUpdate == null ||
                              now.difference(_lastDragUpdate!) > const Duration(milliseconds: 16)) {
                            setState(() {
                              laserCursorPosition = details.localPosition;
                            });
                            _updateDrawing(details.localPosition);
                            _lastDragUpdate = now;
                          } else {
                            // Still update drawing points without setState for smoothness
                            _updateDrawing(details.localPosition);
                          }
                        }
                      },
                      onPanEnd: (details) {
                        if (currentTool == DrawingTool.laser && isDrawingMode) {
                          _endDrawing();
                        }
                      },
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: LaserPainter(
                            laserTrails,
                            currentLaserStroke,
                            laserCursorPosition,
                            drawingColor,
                            strokeWidth,
                            currentTool == DrawingTool.laser && isDrawingMode,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // LAYER 3: Playback Controls (Centered at top) - Draggable
          if (hasVideoLoaded)
            Positioned(
              left: _controlBarPosition!.dx,
              top: _controlBarPosition!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _controlBarPosition = Offset(
                      _controlBarPosition!.dx + details.delta.dx,
                      _controlBarPosition!.dy + details.delta.dy,
                    );
                  });
                },
                child: _buildControlBar(),
              ),
            ),
          
          // LAYER 4: Drawing Controls (Right Side)
          if (hasVideoLoaded)
            Positioned(
              top: 200,
              right: 20,
              child: Column(
                children: [
                  // Toggle Drawing Mode
                  FloatingActionButton(
                    onPressed: _toggleDrawingMode,
                    backgroundColor: isDrawingMode ? Colors.orange : Colors.grey,
                    child: Icon(
                      isDrawingMode ? Icons.draw : Icons.touch_app,
                    ),
                    tooltip: isDrawingMode ? 'Disable Drawing' : 'Enable Drawing',
                  ),
                  const SizedBox(height: 8),
                  // Reset Zoom
                  FloatingActionButton(
                    onPressed: _resetZoom,
                    backgroundColor: Colors.purple,
                    mini: true,
                    child: const Icon(Icons.zoom_out_map),
                    tooltip: 'Reset Zoom',
                  ),
                  // Only show drawing tools when drawing mode is enabled
                  if (isDrawingMode) ...[
                    const SizedBox(height: 8),
                    // Clear Drawing
                    FloatingActionButton(
                      onPressed: _clearDrawing,
                      backgroundColor: Colors.redAccent.shade700,
                      mini: true,
                      child: const Icon(Icons.clear),
                      tooltip: 'Clear Drawings',
                    ),
                    const SizedBox(height: 8),
                    // Tool Selection
                    // Freehand tool
                    FloatingActionButton(
                      onPressed: () => setState(() => currentTool = DrawingTool.freehand),
                      backgroundColor: currentTool == DrawingTool.freehand ? Colors.orange : Colors.grey.shade700,
                      mini: true,
                      child: const Icon(Icons.gesture, size: 20),
                      tooltip: 'Freehand',
                    ),
                    const SizedBox(height: 8),
                    // Line tool
                    FloatingActionButton(
                      onPressed: () => setState(() => currentTool = DrawingTool.line),
                      backgroundColor: currentTool == DrawingTool.line ? Colors.orange : Colors.grey.shade700,
                      mini: true,
                      child: const Icon(Icons.remove, size: 20),
                      tooltip: 'Line',
                    ),
                    const SizedBox(height: 8),
                    // Arrow tool
                    FloatingActionButton(
                      onPressed: () => setState(() => currentTool = DrawingTool.arrow),
                      backgroundColor: currentTool == DrawingTool.arrow ? Colors.orange : Colors.grey.shade700,
                      mini: true,
                      child: const Icon(Icons.arrow_forward, size: 20),
                      tooltip: 'Arrow',
                    ),
                    const SizedBox(height: 8),
                    // Laser pointer tool
                    FloatingActionButton(
                      onPressed: () => setState(() => currentTool = DrawingTool.laser),
                      backgroundColor: currentTool == DrawingTool.laser ? Colors.orange : Colors.grey.shade700,
                      mini: true,
                      child: const Icon(Icons.flash_on, size: 20),
                      tooltip: 'Laser Pointer',
                    ),
                    const SizedBox(height: 8),
                    // Color Options
                    ...[ 
                      Colors.red,
                      Colors.blue,
                      Colors.yellow,
                      Colors.green,
                      Colors.white,
                    ].map((color) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => drawingColor = color),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: drawingColor == color ? Colors.white : Colors.grey,
                              width: drawingColor == color ? 3 : 1,
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
          
          // LAYER 5: The Big Buttons (The "Controller")
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () => _logEvent("SHOT"),
              backgroundColor: Colors.redAccent,
              icon: const Icon(Icons.sports_hockey),
              label: const Text("SHOT ON GOAL"),
            ),
          ),
          
          Positioned(
            bottom: 40,
            left: 20,
            child: FloatingActionButton.extended(
              onPressed: () => _logEvent("TURNOVER"),
              backgroundColor: Colors.blueGrey,
              icon: const Icon(Icons.error_outline),
              label: const Text("TURNOVER"),
            ),
          ),

          // LAYER 6: Shortcuts Toggle Button
          if (hasVideoLoaded)
            Positioned(
              bottom: 110,
              left: 20,
              child: FloatingActionButton(
                onPressed: _toggleShortcutsPanel,
                backgroundColor: _showShortcuts ? Colors.blue : Colors.grey.shade700,
                mini: true,
                child: const Icon(Icons.keyboard),
                tooltip: 'Show Keyboard Shortcuts',
              ),
            ),

          // LAYER 7: Shortcuts Panel
          if (_showShortcuts && hasVideoLoaded)
            Positioned(
              top: 100,
              left: 20,
              child: Material(
                color: Colors.transparent,
                child: _buildShortcutsPanel(),
              ),
            ),

          // Pick Video Button (Centered if no video is playing)
          if (!hasVideoLoaded)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _pickVideo,
                    child: const Text("Select Game Video"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTestVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text("Load Test Video (URL)"),
                  ),
                ],
              ),
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
    return trails != oldDelegate.trails ||
        currentStroke != oldDelegate.currentStroke ||
        cursorPosition != oldDelegate.cursorPosition ||
        cursorColor != oldDelegate.cursorColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        showCursor != oldDelegate.showCursor;
  }
}