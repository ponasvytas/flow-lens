import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';

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
import 'models/sport_profile.dart';
import 'widgets/video_progress_bar.dart';
import 'widgets/events_table_view.dart';
import 'services/event_storage_service.dart';
import 'services/taxonomy_repository.dart';
import 'services/settings_repository.dart';
import 'models/sport_taxonomy.dart';
import 'controllers/events_controller.dart';
import 'controllers/settings_controller.dart';
import 'widgets/settings_view.dart';

void main() {
  // 1. Initialize MediaKit (Crucial for the native video engine)
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const MaterialApp(home: HockeyAnalyzerScreen()));
}

enum _AltEntryStage {
  none,
  categories,
  labels,
  grades,
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
  final EventsController _eventsController = EventsController();
  final TaxonomyRepository _taxonomyRepository = TaxonomyRepository();
  SportTaxonomy? _taxonomy;
  SportProfile? _selectedSportProfile;

  // Settings
  final SettingsController _settingsController = SettingsController(
    SharedPreferencesSettingsRepository(),
  );

  // Shortcuts panel visibility and position
  bool _showShortcuts = false;
  double _shortcutsPanelX = 0.0; // Will be set to right side in initState
  double _shortcutsPanelY = 100.0;

  // Alt+number workflow state
  bool _isAltPressed = false;

  bool _isAltEntryActive = false;
  _AltEntryStage _altEntryStage = _AltEntryStage.none;

  // Speed control state for hold-to-speed shortcuts
  double _previousPlaybackSpeed = 1.0;
  bool _isSpeedShortcutActive = false;

  final EventStorageService _storageService = EventStorageService();

  @override
  void initState() {
    super.initState();
    
    // Initialize shortcuts panel position (right side after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _shortcutsPanelX = MediaQuery.of(context).size.width - 340; // 320 width + 20 margin
        });
      }
    });
    
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
    _eventsController.addListener(_onEventsChanged);

    _settingsController.loadSettings();
  }

  void _onEventsChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadTaxonomy() async {
    if (_selectedSportProfile == null) return;
    
    try {
      final taxonomy = await _taxonomyRepository.loadSportTaxonomy(_selectedSportProfile!.name);
      setState(() {
        _taxonomy = taxonomy;
      });
    } catch (e) {
      print('Error loading taxonomy: $e');
    }
  }

  void _onSportSelected(SportProfile profile) {
    setState(() {
      _selectedSportProfile = profile;
    });
    _loadTaxonomy();
  }

  @override
  void dispose() {
    player.dispose(); // Always clean up video memory!
    _eventsController.removeListener(_onEventsChanged);
    _eventsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      // Web: Use native HTML file picker to avoid loading file into memory
      // This allows files >2GB to be loaded
      final url = await pickVideoFileWeb();
      if (url != null) {
        setState(() {
          hasVideoLoaded = true;
        });
        try {
          await player.open(Media(url), play: false);
          print("Loaded video from blob URL: $url");
          player.setRate(_settingsController.settings.defaultPlaybackSpeed);
          await player.play();
        } catch (e) {
          print("Error opening/playing video: $e");
        }
      }
    } else {
      // Native platforms: Use file_picker with path
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null) {
        setState(() {
          hasVideoLoaded = true;
        });

        final String? path = result.files.single.path;
        if (path != null) {
          await player.open(Media(path));
          player.setRate(_settingsController.settings.defaultPlaybackSpeed);
          print("Loaded video from path: $path");
        } else {
          print("Error: No file path available");
        }
      }
    }
  }

  Future<void> _saveEvents() async {
    try {
      await _storageService.saveEvents(_eventsController.allEvents);
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
        _eventsController.setEvents(events);
        _eventsController.selectEvent(null);
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
          // "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4";
          "https://firebasestorage.googleapis.com/v0/b/flow-video-analyzer.firebasestorage.app/o/12U%20Storm%20Select%20vs%2012U%20Pelicans%20Mexico.mp4?alt=media&token=efa9d272-61e6-445c-972c-f444970d494e";
      // Alternative: Your GitHub video
      // const testVideoUrl = "https://github.com/ponasvytas/hockey-video-analyst/releases/download/v0.0.1-alpha/part5.mp4";

      print("Loading test video from: $testVideoUrl");
      await player.open(Media(testVideoUrl));
      player.setRate(_settingsController.settings.defaultPlaybackSpeed);
      print("Successfully loaded test video");
    } catch (e) {
      print("Error loading test video: $e");
      setState(() {
        hasVideoLoaded = false;
      });
    }
  }

  Future<void> _loadUrl(String url) async {
    setState(() {
      hasVideoLoaded = true;
    });

    try {
      print("Loading video from URL: $url");
      await player.open(Media(url));
      player.setRate(_settingsController.settings.defaultPlaybackSpeed);
      print("Successfully loaded video");
    } catch (e) {
      print("Error loading video: $e");
      setState(() {
        hasVideoLoaded = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
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

  void _showEventsTable() {
    if (_taxonomy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading taxonomy...')),
      );
      return;
    }

    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => EventsTableView(
          controller: _eventsController,
          taxonomy: _taxonomy!,
          onEventTap: (event) {
            final leadIn = _settingsController.settings.leadIn;
            final seekTime = event.timestamp - leadIn;
            player.seek(seekTime > Duration.zero ? seekTime : Duration.zero);
            _eventsController.selectEvent(event);
            Navigator.of(context).pop();
          },
          onClose: () => Navigator.of(context).pop(),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EventsTableView(
            controller: _eventsController,
            taxonomy: _taxonomy!,
            onEventTap: (event) {
              final leadIn = _settingsController.settings.leadIn;
              final seekTime = event.timestamp - leadIn;
              player.seek(seekTime > Duration.zero ? seekTime : Duration.zero);
              _eventsController.selectEvent(event);
              Navigator.of(context).pop();
            },
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      );
    }
  }

  void _showSettings() {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => SettingsView(
          controller: _settingsController,
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsView(
            controller: _settingsController,
          ),
        ),
      );
    }
  }

  void _toggleShortcutsPanel() {
    setState(() {
      _showShortcuts = !_showShortcuts;
    });
  }

  void _onShortcutsPanelDragged(double dx, double dy) {
    setState(() {
      // Get screen size for boundary constraints
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      
      // Panel dimensions (approximate)
      const panelWidth = 320.0;
      const panelHeight = 500.0; // Approximate height
      
      // Update position with delta
      _shortcutsPanelX += dx;
      _shortcutsPanelY += dy;
      
      // Constrain to screen boundaries
      _shortcutsPanelX = _shortcutsPanelX.clamp(0.0, screenWidth - panelWidth);
      _shortcutsPanelY = _shortcutsPanelY.clamp(64.0, screenHeight - panelHeight); // 64 for title bar
    });
  }

  void _resetShortcutsPanelPosition() {
    setState(() {
      final screenWidth = MediaQuery.of(context).size.width;
      _shortcutsPanelX = screenWidth - 320 - 20; // 320px panel width + 20px margin
      _shortcutsPanelY = 100.0;
    });
  }

  bool _createEventFromAltNumber(int number) {
    final taxonomy = _taxonomy;
    if (taxonomy == null) return false;

    final categories = taxonomy.categories;
    
    // Check if number is valid (1-based index)
    if (number < 1 || number > categories.length) {
      return false; // Invalid number, ignore
    }
    
    // Get category (convert to 0-based index)
    final categoryId = categories[number - 1].categoryId;
    
    // Create event using existing logic
    _onEventTriggered(categoryId);

    return true;
  }

  void _handleSmartHudNumber(int number) {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return;

    if (!_isAltEntryActive || !_isAltPressed) return;

    if (_altEntryStage == _AltEntryStage.labels) {
      final didSelect = _selectTagByNumber(number);
      if (didSelect) {
        setState(() {
          _altEntryStage = _AltEntryStage.grades;
        });
      }
      return;
    }

    if (_altEntryStage == _AltEntryStage.grades) {
      final didSelect = _selectGradeByNumber(number);
      if (didSelect) {
        setState(() {
          _altEntryStage = _AltEntryStage.categories;
        });

        _dismissHUD();
      }
    }
  }

  bool _selectTagByNumber(int number) {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return false;

    final taxonomy = _taxonomy;
    if (taxonomy == null) return false;

    final category = taxonomy.getCategoryById(activeEvent.categoryId);
    final eventTypes = category?.eventTypes ?? const <EventTypeTaxonomy>[];

    if (number < 1 || number > eventTypes.length) {
      return false;
    }

    final eventType = eventTypes[number - 1];
    _updateEvent(
      activeEvent.copyWith(
        detail: eventType.name,
        eventTypeId: eventType.eventTypeId,
        grade: eventType.defaultImpact ?? activeEvent.grade,
      ),
    );

    return true;
  }

  bool _selectGradeByNumber(int number) {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return false;

    // Map number to grade (1=Positive, 2=Neutral, 3=Negative)
    EventGrade? grade;
    switch (number) {
      case 1:
        grade = EventGrade.positive;
        break;
      case 2:
        grade = EventGrade.neutral;
        break;
      case 3:
        grade = EventGrade.negative;
        break;
      default:
        return false; // Invalid number, ignore
    }

    // Update event with selected grade
    _updateEvent(activeEvent.copyWith(grade: grade));

    return true;
  }

  void _saveAndCloseSmartHud() {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return;

    // If event has a grade, it's complete - just dismiss
    if (activeEvent.grade != null) {
      _dismissHUD();
    }
  }

  void _cancelAndCloseSmartHud() {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return;

    // Delete the event and close HUD
    _deleteEvent(activeEvent);
  }


  void _onEventTriggered(String categoryId) {
    final taxonomy = _taxonomy;
    if (taxonomy == null) return;

    final category = taxonomy.getCategoryById(categoryId);
    if (category == null) return;

    final position = player.state.position;
    final newEvent = GameEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: position,
      categoryId: categoryId,
      label: category.name,
      grade: null, // Start with no grade
    );

    _eventsController.selectEvent(newEvent);

    print("EVENT DRAFTED: ${newEvent.label} at ${position.toString()}");
  }

  void _updateEvent(GameEvent updatedEvent) {
    // Check if the event is now "complete" (has detail and grade)
    final isComplete =
        updatedEvent.detail != null && updatedEvent.grade != null;

    if (isComplete) {
      final existingIndex = _eventsController.allEvents.indexWhere((e) => e.id == updatedEvent.id);
      if (existingIndex != -1) {
        // Update existing
        _eventsController.updateEvent(updatedEvent);
      } else {
        // Add new confirmed event
        _eventsController.addEvent(updatedEvent);
        print("EVENT CONFIRMED: ${updatedEvent.label}");
      }
    }

    // Always update active event state so HUD reflects changes
    _eventsController.selectEvent(updatedEvent);
  }

  void _deleteEvent(GameEvent event) {
    _eventsController.deleteEvent(event);
    print("EVENT DELETED: ${event.label}");
  }

  void _dismissHUD() {
    _eventsController.selectEvent(null);
  }


  @override
  Widget build(BuildContext context) {
    final showCategoryNumbers = _isAltEntryActive && _isAltPressed && _altEntryStage == _AltEntryStage.categories;
    final showLabelNumbers = _isAltEntryActive && _isAltPressed && _altEntryStage == _AltEntryStage.labels;
    final showGradeNumbers = _isAltEntryActive && _isAltPressed && _altEntryStage == _AltEntryStage.grades;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Handle key press events
        if (event is KeyDownEvent) {
          final isAltPressed = HardwareKeyboard.instance.isAltPressed;

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

          // SmartHUD keyboard shortcuts (when HUD is active)
          if (_eventsController.activeEvent != null && !isDrawingMode) {
            // Alt+Number keys: staged selection only during Alt entry workflow
            if (_isAltEntryActive && isAltPressed) {
              if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                  event.logicalKey == LogicalKeyboardKey.numpad1) {
                _handleSmartHudNumber(1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                  event.logicalKey == LogicalKeyboardKey.numpad2) {
                _handleSmartHudNumber(2);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                  event.logicalKey == LogicalKeyboardKey.numpad3) {
                _handleSmartHudNumber(3);
                return KeyEventResult.handled;
              }
              if (_altEntryStage == _AltEntryStage.labels) {
                if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                    event.logicalKey == LogicalKeyboardKey.numpad4) {
                  _handleSmartHudNumber(4);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                    event.logicalKey == LogicalKeyboardKey.numpad5) {
                  _handleSmartHudNumber(5);
                  return KeyEventResult.handled;
                }
              }
            }

            // Enter: Save event and close HUD
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              _saveAndCloseSmartHud();
              return KeyEventResult.handled;
            }
            // Esc: Cancel and close HUD
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelAndCloseSmartHud();
              return KeyEventResult.handled;
            }
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

          // Alt key: Show category numbers and track state
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            setState(() {
              _isAltPressed = true;
              _isAltEntryActive = true;
              _altEntryStage = _AltEntryStage.categories;
            });
            return KeyEventResult.handled;
          }

          // Alt+number: Create event with category
          if (_isAltEntryActive &&
              isAltPressed &&
              _altEntryStage == _AltEntryStage.categories &&
              hasVideoLoaded &&
              !isDrawingMode) {
            if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                event.logicalKey == LogicalKeyboardKey.numpad1) {
              final didCreate = _createEventFromAltNumber(1);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                event.logicalKey == LogicalKeyboardKey.numpad2) {
              final didCreate = _createEventFromAltNumber(2);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                event.logicalKey == LogicalKeyboardKey.numpad3) {
              final didCreate = _createEventFromAltNumber(3);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.digit4 ||
                event.logicalKey == LogicalKeyboardKey.numpad4) {
              final didCreate = _createEventFromAltNumber(4);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.digit5 ||
                event.logicalKey == LogicalKeyboardKey.numpad5) {
              final didCreate = _createEventFromAltNumber(5);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.digit6 ||
                event.logicalKey == LogicalKeyboardKey.numpad6) {
              final didCreate = _createEventFromAltNumber(6);
              if (didCreate) {
                setState(() {
                  _altEntryStage = _AltEntryStage.labels;
                });
              }
              return KeyEventResult.handled;
            }
          }

          // Arrow key navigation shortcuts
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

          // Arrow Left: Jump backward
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (isCtrlPressed) {
              // Ctrl+Left: Jump backward 30s
              _jumpBackward(const Duration(seconds: 30));
            } else if (isShiftPressed) {
              // Shift+Left: Jump backward 10s
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
            } else if (isShiftPressed) {
              // Shift+Right: Jump forward 10s
              _jumpForward(const Duration(seconds: 10));
            } else {
              // Right: Jump forward 3s
              _jumpForward(const Duration(seconds: 3));
            }
            return KeyEventResult.handled;
          }

          // 'S' key: Set speed to slow playback speed (configurable in settings)
          if (event.logicalKey == LogicalKeyboardKey.keyS) {
            final slowSpeed = _settingsController.settings.slowPlaybackSpeed;
            player.setRate(slowSpeed);
            print("Playback speed set to ${slowSpeed}x (slow)");
            return KeyEventResult.handled;
          }

          // 'D' key: Set speed to default playback speed (configurable in settings)
          if (event.logicalKey == LogicalKeyboardKey.keyD) {
            final defaultSpeed = _settingsController.settings.defaultPlaybackSpeed;
            player.setRate(defaultSpeed);
            print("Playback speed set to ${defaultSpeed}x (default)");
            return KeyEventResult.handled;
          }

          // 'A' key: Jump backward 5 seconds
          if (event.logicalKey == LogicalKeyboardKey.keyA) {
            _jumpBackward(const Duration(seconds: 5));
            return KeyEventResult.handled;
          }

          // 'M' key: Toggle mute/unmute
          if (event.logicalKey == LogicalKeyboardKey.keyM) {
            final currentVolume = player.state.volume;
            if (currentVolume > 0) {
              player.setVolume(0);
              print("Muted");
            } else {
              player.setVolume(100);
              print("Unmuted");
            }
            return KeyEventResult.handled;
          }

          // Hold 'F' for fast forward speed (configurable in settings)
          if (event.logicalKey == LogicalKeyboardKey.keyF &&
              !_isSpeedShortcutActive) {
            _previousPlaybackSpeed = player.state.rate;
            _isSpeedShortcutActive = true;
            final fastSpeed = _settingsController.settings.fastPlaySpeed;
            player.setRate(fastSpeed);
            print(
              "Fast forward: ${fastSpeed}x speed (previous: ${_previousPlaybackSpeed}x)",
            );
            return KeyEventResult.handled;
          }
        }
        // Handle key release events
        if (event is KeyUpEvent) {
          // Alt key released: Update state
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            setState(() {
              _isAltPressed = false;
              _isAltEntryActive = false;
              _altEntryStage = _AltEntryStage.none;
            });
            return KeyEventResult.handled;
          }

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
                onShowShortcuts: _toggleShortcutsPanel,
                showShortcuts: _showShortcuts,
                onSaveEvents: hasVideoLoaded ? _saveEvents : null,
                onLoadEvents: hasVideoLoaded ? _loadEvents : null,
                onShowEventsTable: hasVideoLoaded ? _showEventsTable : null,
                onShowSettings: hasVideoLoaded ? _showSettings : null,
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

            // LAYER 5: Event Buttons with SmartHUD (Centered, lower position)
            if (hasVideoLoaded)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Smart HUD
                      if (_eventsController.activeEvent != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SmartHUD(
                            event: _eventsController.activeEvent!,
                            onUpdateEvent: _updateEvent,
                            onDeleteEvent: _deleteEvent,
                            onDismiss: _dismissHUD,
                            isAltPressed: _isAltPressed,
                            showTagNumbers: showLabelNumbers,
                            showGradeNumbers: showGradeNumbers,
                            taxonomy: _taxonomy,
                          ),
                        ),

                      // Event Buttons Row (with optional number badges)
                      EventButtonsPanel(
                        onEventTriggered: _onEventTriggered,
                        taxonomy: _taxonomy,
                        showNumbers: showCategoryNumbers,
                      ),
                    ],
                  ),
                ),
              ),

            // LAYER 6: Video Progress Bar
            if (hasVideoLoaded)
              VideoProgressBar(
                player: player,
                events: _eventsController.filteredEvents,
                onEventTap: (event) {
                  final leadIn = _settingsController.settings.leadIn;
                  final seekTime = event.timestamp - leadIn;
                  player.seek(seekTime > Duration.zero ? seekTime : Duration.zero);
                  _eventsController.selectEvent(event);
                },
              ),

            // LAYER 7: Shortcuts Panel (toggleable and draggable)
            if (hasVideoLoaded)
              ShortcutsPanel(
                isVisible: _showShortcuts,
                onToggle: _toggleShortcutsPanel,
                positionX: _shortcutsPanelX,
                positionY: _shortcutsPanelY,
                onPositionChanged: _onShortcutsPanelDragged,
                onResetPosition: _resetShortcutsPanelPosition,
              ),

            // Video Picker (shown when no video is loaded)
            if (!hasVideoLoaded)
              VideoPicker(
                onPickVideo: _pickVideo,
                onLoadTestVideo: _loadTestVideo,
                onLoadUrl: _loadUrl,
                onSportSelected: _onSportSelected,
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
