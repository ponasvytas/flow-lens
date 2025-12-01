import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';
// Conditional imports for web
import 'dart:typed_data' show Uint8List;

import 'utils/video_loader.dart';
import 'models/drawing_models.dart';
import 'models/game_event.dart';
import 'widgets/video_canvas.dart';
import 'widgets/drawing_tools_panel.dart';
import 'widgets/event_buttons_panel.dart';
import 'widgets/smart_hud.dart';
import 'widgets/control_bar.dart';
import 'widgets/laser_pointer_overlay.dart';
import 'widgets/shortcuts_panel.dart';
import 'widgets/branded_title_bar.dart';
import 'widgets/video_picker.dart';
import 'widgets/video_progress_bar.dart';
import 'services/event_storage_service.dart';

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

class _HockeyAnalyzerScreenState extends State<HockeyAnalyzerScreen> {
  // Create the Player and Controller
  late final Player player;
  late final VideoController controller;

  // Drawing state
  List<DrawingStroke> drawingStrokes = [];
  List<LineShape> lineShapes = [];
  List<ArrowShape> arrowShapes = [];
  // Active drawing state moved to DrawingInteractionOverlay
  bool isDrawingMode = false;
  DrawingTool currentTool = DrawingTool.freehand;
  Color drawingColor = const Color(0xFF753b8f); // const Color(0xFF753b8f)
  double strokeWidth = 5.0;

  // Laser pointer state
  List<LaserTrail> laserTrails = [];

  // Zoom/Pan state
  final TransformationController _transformationController =
      TransformationController();

  // Video loading state
  bool hasVideoLoaded = false;

  // Event Tracking State
  List<GameEvent> gameEvents = [];
  GameEvent? _activeEvent; // The event currently being edited in the HUD

  // Shortcuts panel visibility
  bool _showShortcuts = false;

  // Speed control state for hold-to-speed shortcuts
  double _previousPlaybackSpeed = 1.0;
  bool _isSpeedShortcutActive = false;

  final EventStorageService _storageService = EventStorageService();

  @override
  void initState() {
    super.initState();
    // 2. Configure the player with web-friendly and performance settings
    player = Player(
      configuration: PlayerConfiguration(
        title: 'Hockey Analyzer',
        // Enable GPU acceleration for better performance (Native only)
        // On Web, let the browser/media_kit handle the rendering backend
        vo: kIsWeb ? null : 'gpu',
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
          final url = await createUrlFromBytes(bytes);
          if (url != null) {
            try {
              // Open without auto-play to avoid immediate WakeLock/Play restrictions
              await player.open(Media(url), play: false);
              print("Loaded video from blob URL: $url");

              // Attempt to play
              await player.play();
            } catch (e) {
              print("Error opening/playing video: $e");
            }
          } else {
            print("Error: Failed to create URL from bytes");
          }
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

  Future<void> _saveEvents() async {
    try {
      await _storageService.saveEvents(gameEvents);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Events saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save events: $e')));
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await _storageService.loadEvents();
      if (events.isNotEmpty) {
        setState(() {
          gameEvents.clear();
          gameEvents.addAll(events);
          _activeEvent = null; // Clear active selection
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Loaded ${events.length} events')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load events: $e')));
      }
    }
  }

  Future<void> _loadTestVideo() async {
    setState(() {
      hasVideoLoaded = true;
    });

    try {
      // Using a reliable test video that works well on mobile browsers
      const testVideoUrl =
          "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
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
    // Pause video during seek for smoother experience
    final wasPlaying = player.state.playing;
    player.pause();
    player.seek(newPosition).then((_) {
      if (wasPlaying) player.play();
    });
    print("Jumped forward ${duration.inSeconds}s to ${newPosition.toString()}");
  }

  void _jumpBackward(Duration duration) {
    final currentPosition = player.state.position;
    final newPosition = currentPosition - duration;
    // Pause video during seek for smoother experience
    final wasPlaying = player.state.playing;
    player.pause();
    player.seek(newPosition > Duration.zero ? newPosition : Duration.zero).then(
      (_) {
        if (wasPlaying) player.play();
      },
    );
    print(
      "Jumped backward ${duration.inSeconds}s to ${newPosition.toString()}",
    );
  }

  void _onStrokeCompleted(DrawingStroke stroke) {
    setState(() {
      drawingStrokes.add(stroke);
    });
  }

  void _onLineCompleted(LineShape line) {
    setState(() {
      lineShapes.add(line);
    });
  }

  void _onArrowCompleted(ArrowShape arrow) {
    setState(() {
      arrowShapes.add(arrow);
    });
  }

  void _completeLaserDrawing(List<DrawingPoint> strokePoints) {
    if (strokePoints.isEmpty) return;
    setState(() {
      // Create laser trail - animation handled by LaserPointerOverlay
      final trail = LaserTrail(
        strokePoints,
        drawingColor,
        strokeWidth,
        DateTime.now(),
      );
      laserTrails.add(trail);
    });
  }

  void _removeTrail(LaserTrail trail) {
    setState(() {
      laserTrails.remove(trail);
    });
  }

  void _clearDrawing() {
    setState(() {
      drawingStrokes.clear();
      lineShapes.clear();
      arrowShapes.clear();
      laserTrails.clear();
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

  void _onEventTriggered(EventCategory category) {
    final position = player.state.position;
    final newEvent = GameEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: position,
      category: category,
      label: _getDefaultLabel(category),
      grade: null, // Start with no grade
    );

    setState(() {
      // Do NOT add to gameEvents yet. Wait for confirmation (detail + grade).
      _activeEvent = newEvent;
    });

    print("EVENT DRAFTED: ${newEvent.label} at ${position.toString()}");
  }

  void _updateEvent(GameEvent updatedEvent) {
    setState(() {
      // Check if the event is now "complete" (has detail and grade)
      final isComplete =
          updatedEvent.detail != null && updatedEvent.grade != null;

      if (isComplete) {
        final index = gameEvents.indexWhere((e) => e.id == updatedEvent.id);
        if (index != -1) {
          // Update existing
          gameEvents[index] = updatedEvent;
        } else {
          // Add new confirmed event
          gameEvents.add(updatedEvent);
          print("EVENT CONFIRMED: ${updatedEvent.label}");
        }
      }

      // Always update active event state so HUD reflects changes
      _activeEvent = updatedEvent;
    });
  }

  void _deleteEvent(GameEvent event) {
    setState(() {
      gameEvents.removeWhere((e) => e.id == event.id);
      _activeEvent = null; // Close HUD
    });
    print("EVENT DELETED: ${event.label}");
  }

  void _dismissHUD() {
    setState(() {
      // If the event wasn't saved (not in list), it's discarded
      _activeEvent = null;
    });
  }

  String _getDefaultLabel(EventCategory category) {
    return switch (category) {
      EventCategory.shot => "Shot",
      EventCategory.pass => "Pass",
      EventCategory.battle => "Battle",
      EventCategory.defense => "Defense",
      EventCategory.teamPlay => "Team Play",
      EventCategory.penalty => "Penalty",
    };
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle key press events
        if (event is KeyDownEvent) {
          // Toggle play/pause          // Space bar: Play/Pause
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }

          // 'G' key: Toggle graphics/drawing mode
          if (event.logicalKey == LogicalKeyboardKey.keyG) {
            _toggleDrawingMode();
            return KeyEventResult.handled;
          }

          // Tool shortcuts (only in graphics mode)
          if (isDrawingMode) {
            // '1' key: Freehand tool
            if (event.logicalKey == LogicalKeyboardKey.digit1) {
              setState(() => currentTool = DrawingTool.freehand);
              return KeyEventResult.handled;
            }
            // '2' key: Line tool
            if (event.logicalKey == LogicalKeyboardKey.digit2) {
              setState(() => currentTool = DrawingTool.line);
              return KeyEventResult.handled;
            }
            // '3' key: Arrow tool
            if (event.logicalKey == LogicalKeyboardKey.digit3) {
              setState(() => currentTool = DrawingTool.arrow);
              return KeyEventResult.handled;
            }
          }

          // 'C' key: Clear all drawings
          if (event.logicalKey == LogicalKeyboardKey.keyC) {
            _clearDrawing();
            return KeyEventResult.handled;
          }

          // 'K' key: Toggle laser pointer when 'K' key is pressed
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

          // Arrow key navigation shortcuts
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
          final isAltPressed = HardwareKeyboard.instance.isAltPressed;

          // Arrow Left: Jump backward
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (isCtrlPressed) {
              // Ctrl+Left: Jump backward 30s
              _jumpBackward(const Duration(seconds: 30));
            } else if (isAltPressed) {
              // Alt+Left: Jump backward 10s
              _jumpBackward(const Duration(seconds: 10));
            } else {
              // Left: Jump backward 3s
              _jumpBackward(const Duration(seconds: 3));
            }
            return KeyEventResult.handled;
          }

          // Arrow Right: Jump forward
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (isCtrlPressed) {
              // Ctrl+Right: Jump forward 30s
              _jumpForward(const Duration(seconds: 30));
            } else if (isAltPressed) {
              // Alt+Right: Jump forward 10s
              _jumpForward(const Duration(seconds: 10));
            } else {
              // Right: Jump forward 3s
              _jumpForward(const Duration(seconds: 3));
            }
            return KeyEventResult.handled;
          }

          // 'S' key: Set speed to 0.33x (slow motion)
          if (event.logicalKey == LogicalKeyboardKey.keyS) {
            player.setRate(0.33);
            print("Playback speed set to 0.33x (slow motion)");
            return KeyEventResult.handled;
          }

          // 'D' key: Set speed to 1.0x (normal)
          if (event.logicalKey == LogicalKeyboardKey.keyD) {
            player.setRate(1.0);
            print("Playback speed set to 1.0x (normal)");
            return KeyEventResult.handled;
          }

          // 'A' key: Jump backward 5 seconds
          if (event.logicalKey == LogicalKeyboardKey.keyA) {
            _jumpBackward(const Duration(seconds: 5));
            return KeyEventResult.handled;
          }

          // Hold 'F' for 3x forward speed
          if (event.logicalKey == LogicalKeyboardKey.keyF &&
              !_isSpeedShortcutActive) {
            _previousPlaybackSpeed = player.state.rate;
            _isSpeedShortcutActive = true;
            player.setRate(3.0);
            print(
              "Fast forward: 3x speed (previous: ${_previousPlaybackSpeed}x)",
            );
            return KeyEventResult.handled;
          }
        }
        // Handle key release events
        if (event is KeyUpEvent) {
          // Release 'F' to restore previous speed
          if (event.logicalKey == LogicalKeyboardKey.keyF &&
              _isSpeedShortcutActive) {
            player.setRate(_previousPlaybackSpeed);
            _isSpeedShortcutActive = false;
            print("Speed restored to ${_previousPlaybackSpeed}x");
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // LAYER 0: Branded Title Bar (Top)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BrandedTitleBar(
                onShowShortcuts: () =>
                    setState(() => _showShortcuts = !_showShortcuts),
                showShortcuts: _showShortcuts,
                onSaveEvents: hasVideoLoaded ? _saveEvents : null,
                onLoadEvents: hasVideoLoaded ? _loadEvents : null,
              ),
            ),

            // LAYER 1: Video Canvas with Zoom/Pan and Drawing (with top padding)
            Padding(
              padding: const EdgeInsets.only(top: 64),
              child: VideoCanvas(
                controller: controller,
                transformationController: _transformationController,
                isDrawingMode: isDrawingMode,
                currentTool: currentTool,
                drawingStrokes: drawingStrokes,
                lineShapes: lineShapes,
                arrowShapes: arrowShapes,
                drawingColor: drawingColor,
                strokeWidth: strokeWidth,
                onStrokeCompleted: _onStrokeCompleted,
                onLineCompleted: _onLineCompleted,
                onArrowCompleted: _onArrowCompleted,
                onClearDrawing: _clearDrawing,
              ),
            ),

            // LAYER 2: Laser trails and cursor (No zoom scaling - overlay)
            // Only show when laser is active or there are trails to display
            if (hasVideoLoaded &&
                (currentTool == DrawingTool.laser || laserTrails.isNotEmpty))
              LaserPointerOverlay(
                isActive: currentTool == DrawingTool.laser,
                isDrawingMode: isDrawingMode,
                trails: laserTrails,
                color: drawingColor,
                strokeWidth: strokeWidth,
                onCompleteDrawing: _completeLaserDrawing,
                onRemoveTrail: _removeTrail,
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

            // LAYER 5: Event Buttons (Centered above progress bar)
            if (hasVideoLoaded)
              Positioned(
                bottom: 110, // Positioned above the progress bar
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smart HUD (appears above buttons)
                      if (_activeEvent != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SmartHUD(
                            event: _activeEvent!,
                            onUpdateEvent: _updateEvent,
                            onDeleteEvent: _deleteEvent,
                            onDismiss: _dismissHUD,
                          ),
                        ),

                      // Event Buttons Row
                      EventButtonsPanel(onEventTriggered: _onEventTriggered),
                    ],
                  ),
                ),
              ),

            // LAYER 6: Video Progress Bar
            if (hasVideoLoaded)
              VideoProgressBar(
                player: player,
                events: gameEvents,
                onEventTap: (event) {
                  player.seek(event.timestamp);
                  setState(() {
                    _activeEvent = event;
                  });
                },
              ),

            // LAYER 7: Shortcuts Panel with Toggle Button
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
// Moved to lib/painters/drawing_painter.dart

// Custom painter for laser pointer trails and cursor
// Moved to lib/painters/laser_painter.dart
