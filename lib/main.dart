import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';

import 'utils/video_loader.dart';
import 'utils/player_config.dart';
import 'utils/perf.dart';
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
import 'widgets/docked_events_panel.dart';
import 'models/sport_profile.dart';
import 'widgets/video_progress_bar.dart';
import 'widgets/events_table_view.dart';
import 'services/event_storage_service.dart';
import 'services/tracking_storage_service.dart';
import 'services/taxonomy_repository.dart';
import 'services/settings_repository.dart';
import 'models/sport_taxonomy.dart';
import 'controllers/events_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/ui_controller.dart';
import 'controllers/tracking_controller.dart';
import 'models/app_mode.dart';
import 'widgets/dock_layout.dart';
import 'widgets/settings_view.dart';
import 'widgets/event_navigation_panel.dart';
import 'widgets/player_tracking_panel.dart';

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

// ---------------------------------------------------------------------------
// Scoped ChangeNotifiers — mutations here do NOT trigger a parent setState.
// ---------------------------------------------------------------------------

/// All drawing / annotation state in one notifier.
class _DrawingState extends ChangeNotifier {
  bool isDrawingMode = false;
  DrawingTool currentTool = DrawingTool.freehand;
  Color drawingColor = const Color(0xFF753b8f);
  double strokeWidth = 5.0;
  final List<DrawingStroke> strokes = [];
  final List<LineShape> lines = [];
  final List<ArrowShape> arrows = [];
  final List<LaserTrail> laserTrails = [];

  /// Monotonic counter for completed-strokes content changes.
  int revision = 0;

  void toggleDrawingMode() {
    isDrawingMode = !isDrawingMode;
    notifyListeners();
  }

  void setTool(DrawingTool tool) {
    if (tool == currentTool) return;
    currentTool = tool;
    notifyListeners();
  }

  void setColor(Color color) {
    if (color == drawingColor) return;
    drawingColor = color;
    notifyListeners();
  }

  void toggleLaser() {
    if (currentTool == DrawingTool.laser) {
      currentTool = DrawingTool.freehand;
    } else {
      currentTool = DrawingTool.laser;
      if (!isDrawingMode) isDrawingMode = true;
    }
    notifyListeners();
  }

  void addStroke(DrawingStroke stroke) {
    strokes.add(stroke);
    revision++;
    notifyListeners();
  }

  void addLine(LineShape line) {
    lines.add(line);
    revision++;
    notifyListeners();
  }

  void addArrow(ArrowShape arrow) {
    arrows.add(arrow);
    revision++;
    notifyListeners();
  }

  void addLaserTrail(LaserTrail trail) {
    laserTrails.add(trail);
    notifyListeners();
  }

  void removeTrail(LaserTrail trail) {
    laserTrails.remove(trail);
    notifyListeners();
  }

  void clearAll() {
    strokes.clear();
    lines.clear();
    arrows.clear();
    laserTrails.clear();
    revision++;
    notifyListeners();
  }
}

/// Alt+number workflow state — only consumed by event buttons / SmartHUD.
class _AltKeyState extends ChangeNotifier {
  bool isPressed = false;
  bool isEntryActive = false;
  _AltEntryStage stage = _AltEntryStage.none;

  bool get showCategoryNumbers =>
      isEntryActive && isPressed && stage == _AltEntryStage.categories;
  bool get showLabelNumbers =>
      isEntryActive && isPressed && stage == _AltEntryStage.labels;
  bool get showGradeNumbers =>
      isEntryActive && isPressed && stage == _AltEntryStage.grades;

  void onAltPressed() {
    isPressed = true;
    isEntryActive = true;
    stage = _AltEntryStage.categories;
    notifyListeners();
  }

  void onAltReleased() {
    isPressed = false;
    isEntryActive = false;
    stage = _AltEntryStage.none;
    notifyListeners();
  }

  void setStage(_AltEntryStage newStage) {
    stage = newStage;
    notifyListeners();
  }
}

class HockeyAnalyzerScreen extends StatefulWidget {
  const HockeyAnalyzerScreen({super.key});

  @override
  State<HockeyAnalyzerScreen> createState() => _HockeyAnalyzerScreenState();
}

class _HockeyAnalyzerScreenState extends State<HockeyAnalyzerScreen>
    with TickerProviderStateMixin {
  // Create the Player and Controller
  late final Player player;
  late final VideoController controller;

  // Drawing state
  final _drawing = _DrawingState();

  // Zoom/Pan state
  final TransformationController _transformationController =
      TransformationController();
  AnimationController? _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;

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

  // UI mode & panel management
  final UIController _uiController = UIController();

  // Player tracking
  final TrackingController _trackingController = TrackingController();
  final TrackingStorageService _trackingStorageService = TrackingStorageService();

  // Docked events panel
  bool _showDockedEvents = false;

  // Shortcuts panel visibility and position
  bool _showShortcuts = false;
  double _shortcutsPanelX = 0.0; // Will be set to right side in initState
  double _shortcutsPanelY = 100.0;

  // Alt+number workflow state
  final _altKey = _AltKeyState();

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
        title: 'Flow Lens',
        // Enable GPU acceleration for better performance (Native only)
        // On Web, let the browser/media_kit handle the rendering backend
        vo: kIsWeb ? null : 'gpu',
        // Enable logging for debugging
        logLevel: MPVLogLevel.info,
      ),
    );

    // Native-only: enable hardware decoding and demuxer cache for faster seeking
    configureNativePlayer(player);

    controller = VideoController(player);

    _settingsController.loadSettings();
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
    _zoomAnimationController?.dispose();
    player.dispose(); // Always clean up video memory!
    _eventsController.dispose();
    _uiController.dispose();
    _drawing.dispose();
    _altKey.dispose();
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

  // ---------------------------------------------------------------------------
  // Tracking session save / load / export
  // ---------------------------------------------------------------------------

  Future<void> _saveTrackingSession() async {
    try {
      await _trackingStorageService.saveSession(_trackingController.session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking session saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save tracking: $e')),
        );
      }
    }
  }

  Future<void> _loadTrackingSession() async {
    try {
      final session = await _trackingStorageService.loadSession();
      if (session != null) {
        _trackingController.loadSession(session);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Loaded tracking: ${session.subjects.length} players, '
                '${session.events.length} events',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tracking: $e')),
        );
      }
    }
  }

  Future<void> _exportTrackingCsv() async {
    try {
      await _trackingStorageService.exportCsv(_trackingController.session);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tracking CSV exported')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export CSV: $e')),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mode switching (stops active timers when leaving tracking mode)
  // ---------------------------------------------------------------------------

  void _changeMode(AppMode mode) {
    if (_uiController.currentMode == AppMode.tracking &&
        mode != AppMode.tracking) {
      _trackingController.stopAllTimers(
          timestamp: player.state.position);
    }
    _uiController.setMode(mode);
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
    _drawing.addStroke(stroke);
  }

  void _onLineCompleted(LineShape line) {
    _drawing.addLine(line);
  }

  void _onArrowCompleted(ArrowShape arrow) {
    _drawing.addArrow(arrow);
  }

  void _completeLaserDrawing(List<DrawingPoint> strokePoints) {
    if (strokePoints.isEmpty) return;
    _drawing.addLaserTrail(LaserTrail(
      strokePoints,
      _drawing.drawingColor,
      _drawing.strokeWidth,
      DateTime.now(),
    ));
  }

  void _removeTrail(LaserTrail trail) {
    _drawing.removeTrail(trail);
  }

  void _clearDrawing() {
    _drawing.clearAll();
  }

  void _toggleDrawingMode() {
    _drawing.toggleDrawingMode();
  }

  /// Current video container width (accounts for docked panel).
  double get _videoWidth {
    final screenWidth = MediaQuery.of(context).size.width;
    return _showDockedEvents ? screenWidth - 340 : screenWidth;
  }

  /// Normalize a pixel-based transform to be resolution-independent.
  /// Translations are stored as fractions of video width/height.
  Matrix4 _normalizeTransform(Matrix4 transform) {
    final w = _videoWidth;
    final h = w * 9 / 16;
    final normalized = transform.clone();
    normalized.setEntry(0, 3, transform.entry(0, 3) / w);
    normalized.setEntry(1, 3, transform.entry(1, 3) / h);
    return normalized;
  }

  /// Convert a normalized transform back to pixel values for the current size.
  Matrix4 _denormalizeTransform(Matrix4 transform) {
    final w = _videoWidth;
    final h = w * 9 / 16;
    final denormalized = transform.clone();
    denormalized.setEntry(0, 3, transform.entry(0, 3) * w);
    denormalized.setEntry(1, 3, transform.entry(1, 3) * h);
    return denormalized;
  }

  void _navigateToEvent(GameEvent event) {
    final leadIn = _settingsController.settings.leadIn;
    final seekTime = event.timestamp - leadIn;
    _eventsController.selectEvent(event);

    final targetTransform = event.viewTransform != null
        ? _denormalizeTransform(event.viewTransform!)
        : Matrix4.identity();
    final currentTransform = _transformationController.value.clone();

    // If zoom state is changing, animate it and stagger the seek
    if (currentTransform != targetTransform) {
      _animateZoomTo(targetTransform, onMidpoint: () {
        player.seek(seekTime > Duration.zero ? seekTime : Duration.zero);
      });
    } else {
      player.seek(seekTime > Duration.zero ? seekTime : Duration.zero);
    }
  }

  void _animateZoomTo(Matrix4 target, {VoidCallback? onMidpoint}) {
    _zoomAnimationController?.dispose();

    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: target,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController!,
      curve: Curves.easeInOut,
    ));

    bool seekFired = false;
    _zoomAnimationController!.addListener(() {
      _transformationController.value = _zoomAnimation!.value;
      // Fire seek at ~40% through the animation
      if (!seekFired && _zoomAnimationController!.value >= 0.4) {
        seekFired = true;
        onMidpoint?.call();
      }
    });

    _zoomAnimationController!.forward();
  }

  void _resetZoom() {
    _animateZoomTo(Matrix4.identity());
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
            _navigateToEvent(event);
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
            _navigateToEvent(event);
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

  void _toggleDockedEvents() {
    // Reset zoom — the transform is pixel-relative and invalid at new width
    _transformationController.value = Matrix4.identity();
    setState(() {
      _showDockedEvents = !_showDockedEvents;
    });
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

    if (!_altKey.isEntryActive || !_altKey.isPressed) return;

    if (_altKey.stage == _AltEntryStage.labels) {
      final didSelect = _selectTagByNumber(number);
      if (didSelect) {
        _altKey.setStage(_AltEntryStage.grades);
      }
      return;
    }

    if (_altKey.stage == _AltEntryStage.grades) {
      final didSelect = _selectGradeByNumber(number);
      if (didSelect) {
        _altKey.setStage(_AltEntryStage.categories);
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
    final currentTransform = _transformationController.value;
    final isZoomed = currentTransform.getMaxScaleOnAxis() > 1.01;
    final newEvent = GameEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: position,
      categoryId: categoryId,
      label: category.name,
      grade: null, // Start with no grade
      viewTransform: isZoomed ? _normalizeTransform(currentTransform) : null,
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
    Perf.rebuildCount('HockeyAnalyzerScreen');

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // =====================================================================
        // Guard: detect whether a text field currently has focus.
        // When typing in a TextField / EditableText we must let letter keys
        // through to the field instead of treating them as shortcuts.
        // EditableText internally builds a child Focus widget, so
        // primaryFocus.context.widget is Focus, not EditableText.
        // We walk up ancestors to find EditableText above the focused node.
        // =====================================================================
        final isTextFieldFocused = FocusManager.instance.primaryFocus
                ?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null;

        final mode = _uiController.currentMode;
        final isAltPressed = HardwareKeyboard.instance.isAltPressed;
        final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
        final hasModifier = isAltPressed || isCtrlPressed;

        // =====================================================================
        // KEY DOWN
        // =====================================================================
        if (event is KeyDownEvent) {

          // -----------------------------------------------------------------
          // 1. Modifier-based shortcuts (always active, even in text fields)
          // -----------------------------------------------------------------

          // Ctrl+M: Cycle through app modes
          if (event.logicalKey == LogicalKeyboardKey.keyM && isCtrlPressed) {
            final modes = AppMode.values;
            final nextIndex = (modes.indexOf(mode) + 1) % modes.length;
            _changeMode(modes[nextIndex]);
            return KeyEventResult.handled;
          }

          // Alt key press: begin alt-entry workflow (record mode)
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            if (mode == AppMode.record) {
              _altKey.onAltPressed();
            }
            return KeyEventResult.handled;
          }

          // Alt+number: Create event / SmartHUD grade (record mode only)
          if (isAltPressed && _altKey.isEntryActive && mode == AppMode.record) {
            // SmartHUD label/grade selection when HUD is active
            if (_eventsController.activeEvent != null &&
                !_drawing.isDrawingMode) {
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
              if (_altKey.stage == _AltEntryStage.labels) {
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

            // Alt+number: create event with category
            if (_altKey.stage == _AltEntryStage.categories &&
                hasVideoLoaded &&
                !_drawing.isDrawingMode) {
              KeyEventResult? _tryAltCreate(LogicalKeyboardKey a,
                  LogicalKeyboardKey b, int n) {
                if (event.logicalKey == a || event.logicalKey == b) {
                  final didCreate = _createEventFromAltNumber(n);
                  if (didCreate) _altKey.setStage(_AltEntryStage.labels);
                  return KeyEventResult.handled;
                }
                return null;
              }

              final result = _tryAltCreate(LogicalKeyboardKey.digit1,
                      LogicalKeyboardKey.numpad1, 1) ??
                  _tryAltCreate(LogicalKeyboardKey.digit2,
                      LogicalKeyboardKey.numpad2, 2) ??
                  _tryAltCreate(LogicalKeyboardKey.digit3,
                      LogicalKeyboardKey.numpad3, 3) ??
                  _tryAltCreate(LogicalKeyboardKey.digit4,
                      LogicalKeyboardKey.numpad4, 4) ??
                  _tryAltCreate(LogicalKeyboardKey.digit5,
                      LogicalKeyboardKey.numpad5, 5) ??
                  _tryAltCreate(LogicalKeyboardKey.digit6,
                      LogicalKeyboardKey.numpad6, 6);
              if (result != null) return result;
            }
          }

          // -----------------------------------------------------------------
          // 2. SmartHUD Enter/Esc (record mode, HUD active, not text-field)
          // -----------------------------------------------------------------
          if (mode == AppMode.record &&
              _eventsController.activeEvent != null &&
              !_drawing.isDrawingMode &&
              !isTextFieldFocused) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              _saveAndCloseSmartHud();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _cancelAndCloseSmartHud();
              return KeyEventResult.handled;
            }
          }

          // -----------------------------------------------------------------
          // 3. Tracking hotkeys (tracking mode, NOT in text fields)
          // -----------------------------------------------------------------
          if (mode == AppMode.tracking && !isTextFieldFocused) {
            final keyLabel = event.logicalKey.keyLabel.toLowerCase();
            if (keyLabel.isNotEmpty &&
                _trackingController.handleHotkeyDown(
                    keyLabel, player.state.position)) {
              return KeyEventResult.handled;
            }
          }

          // =================================================================
          // STOP HERE if a text field is focused — no bare-key shortcuts below
          // should fire while the user is typing.
          // =================================================================
          if (isTextFieldFocused && !hasModifier) {
            return KeyEventResult.ignored;
          }

          // -----------------------------------------------------------------
          // 4. Global playback shortcuts (all modes)
          // -----------------------------------------------------------------

          // Space: Play/Pause
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _togglePlayPause();
            return KeyEventResult.handled;
          }

          // Arrow Left: Jump backward
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (isCtrlPressed) {
              _jumpBackward(const Duration(seconds: 30));
            } else if (isShiftPressed) {
              _jumpBackward(const Duration(seconds: 10));
            } else {
              _jumpBackward(const Duration(seconds: 3));
            }
            return KeyEventResult.handled;
          }

          // Arrow Right: Jump forward
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (isCtrlPressed) {
              _jumpForward(const Duration(seconds: 30));
            } else if (isShiftPressed) {
              _jumpForward(const Duration(seconds: 10));
            } else {
              _jumpForward(const Duration(seconds: 3));
            }
            return KeyEventResult.handled;
          }

          // 'A' key: Jump backward 5s
          if (event.logicalKey == LogicalKeyboardKey.keyA) {
            _jumpBackward(const Duration(seconds: 5));
            return KeyEventResult.handled;
          }

          // 'S' key: Slow playback speed
          if (event.logicalKey == LogicalKeyboardKey.keyS) {
            final slowSpeed = _settingsController.settings.slowPlaybackSpeed;
            player.setRate(slowSpeed);
            print("Playback speed set to ${slowSpeed}x (slow)");
            return KeyEventResult.handled;
          }

          // 'D' key: Default playback speed
          if (event.logicalKey == LogicalKeyboardKey.keyD) {
            final defaultSpeed =
                _settingsController.settings.defaultPlaybackSpeed;
            player.setRate(defaultSpeed);
            print("Playback speed set to ${defaultSpeed}x (default)");
            return KeyEventResult.handled;
          }

          // Hold 'F': Fast forward
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

          // -----------------------------------------------------------------
          // 5. Drawing / annotation shortcuts (record + review modes only)
          // -----------------------------------------------------------------
          if (mode == AppMode.record || mode == AppMode.review) {
            // 'G' key: Toggle graphics/drawing mode
            if (event.logicalKey == LogicalKeyboardKey.keyG) {
              _toggleDrawingMode();
              return KeyEventResult.handled;
            }

            // 'C' key: Clear all drawings
            if (event.logicalKey == LogicalKeyboardKey.keyC) {
              _clearDrawing();
              return KeyEventResult.handled;
            }

            // 'K' key: Toggle laser pointer
            if (event.logicalKey == LogicalKeyboardKey.keyK) {
              _drawing.toggleLaser();
              return KeyEventResult.handled;
            }

            // Drawing tool shortcuts (only when drawing mode is active)
            if (_drawing.isDrawingMode) {
              if (event.logicalKey == LogicalKeyboardKey.digit1 ||
                  event.logicalKey == LogicalKeyboardKey.numpad1) {
                _drawing.setTool(DrawingTool.freehand);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit2 ||
                  event.logicalKey == LogicalKeyboardKey.numpad2) {
                _drawing.setTool(DrawingTool.line);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.digit3 ||
                  event.logicalKey == LogicalKeyboardKey.numpad3) {
                _drawing.setTool(DrawingTool.arrow);
                return KeyEventResult.handled;
              }
            }
          }

          // 'P' key: Dump perf stats (debug only, all modes)
          if (event.logicalKey == LogicalKeyboardKey.keyP) {
            Perf.dump();
            return KeyEventResult.handled;
          }
        }

        // =====================================================================
        // KEY UP
        // =====================================================================
        if (event is KeyUpEvent) {
          // Tracking hold-mode timer release (tracking mode, not text fields)
          if (mode == AppMode.tracking && !isTextFieldFocused) {
            final keyLabel = event.logicalKey.keyLabel.toLowerCase();
            if (keyLabel.isNotEmpty &&
                _trackingController.handleHotkeyUp(
                    keyLabel, player.state.position)) {
              return KeyEventResult.handled;
            }
          }

          // Alt key released
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            _altKey.onAltReleased();
            return KeyEventResult.handled;
          }

          // Release 'F' to restore previous speed
          if (!isTextFieldFocused &&
              event.logicalKey == LogicalKeyboardKey.keyF &&
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
        body: Row(
          children: [
            // Main content area (video + overlays)
            Expanded(
              child: Stack(
                children: [
            // LAYER 0: Branded Title Bar (Top)
            ListenableBuilder(
              listenable: _uiController,
              builder: (context, _) => Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: BrandedTitleBar(
                  onShowShortcuts: _toggleShortcutsPanel,
                  showShortcuts: _showShortcuts,
                  currentMode: _uiController.currentMode,
                  onModeChanged: _changeMode,
                  onSaveEvents: hasVideoLoaded ? _saveEvents : null,
                  onLoadEvents: hasVideoLoaded ? _loadEvents : null,
                  onShowEventsTable: hasVideoLoaded ? _showEventsTable : null,
                  onShowSettings: hasVideoLoaded ? _showSettings : null,
                  onToggleDockedEvents: hasVideoLoaded ? _toggleDockedEvents : null,
                  showDockedEvents: _showDockedEvents,
                ),
              ),
            ),

            // LAYER 1: Video Canvas with Zoom/Pan and Drawing (with top padding)
            ListenableBuilder(
              listenable: _drawing,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.only(top: 64),
                child: VideoCanvas(
                  controller: controller,
                  transformationController: _transformationController,
                  isDrawingMode: _drawing.isDrawingMode,
                  currentTool: _drawing.currentTool,
                  drawingStrokes: _drawing.strokes,
                  lineShapes: _drawing.lines,
                  arrowShapes: _drawing.arrows,
                  drawingColor: _drawing.drawingColor,
                  strokeWidth: _drawing.strokeWidth,
                  drawingRevision: _drawing.revision,
                  onStrokeCompleted: _onStrokeCompleted,
                  onLineCompleted: _onLineCompleted,
                  onArrowCompleted: _onArrowCompleted,
                  onClearDrawing: _clearDrawing,
                ),
              ),
            ),

            // LAYER 2: Laser trails and cursor (No zoom scaling - overlay)
            // Only show when laser is active or there are trails to display
            if (hasVideoLoaded)
              ListenableBuilder(
                listenable: _drawing,
                builder: (context, _) {
                  if (_drawing.currentTool != DrawingTool.laser &&
                      _drawing.laserTrails.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return LaserPointerOverlay(
                    isActive: _drawing.currentTool == DrawingTool.laser,
                    isDrawingMode: _drawing.isDrawingMode,
                    trails: _drawing.laserTrails,
                    color: _drawing.drawingColor,
                    strokeWidth: _drawing.strokeWidth,
                    onCompleteDrawing: _completeLaserDrawing,
                    onRemoveTrail: _removeTrail,
                  );
                },
              ),

            // LAYER 3–5c: All dockable panels via DockLayout
            if (hasVideoLoaded)
              ListenableBuilder(
                listenable: _uiController,
                builder: (context, _) => DockLayout(
                  uiController: _uiController,
                  panels: [
                  // Playback Controls
                  DockPanelEntry(
                    id: PanelId.playbackControls,
                    title: 'Playback',
                    icon: Icons.play_circle_outline,
                    defaultFloatingPosition: const Offset(20, 80),
                    builder: (dockEdge) => DraggableControlBar(
                      player: player,
                      onSpeedChange: _changeSpeed,
                      onJumpForward: _jumpForward,
                      onJumpBackward: _jumpBackward,
                      onTogglePlayPause: _togglePlayPause,
                      dockEdge: dockEdge,
                    ),
                  ),
                  // Drawing Tools
                  DockPanelEntry(
                    id: PanelId.drawingTools,
                    title: 'Drawing',
                    icon: Icons.draw,
                    defaultFloatingPosition: Offset(
                      MediaQuery.of(context).size.width - 240,
                      200,
                    ),
                    builder: (dockEdge) => ListenableBuilder(
                      listenable: _drawing,
                      builder: (context, _) => DrawingToolsPanel(
                        isDrawingMode: _drawing.isDrawingMode,
                        currentTool: _drawing.currentTool,
                        drawingColor: _drawing.drawingColor,
                        onToggleDrawingMode: _toggleDrawingMode,
                        onResetZoom: _resetZoom,
                        onClearDrawing: _clearDrawing,
                        onToolChange: _drawing.setTool,
                        onColorChange: _drawing.setColor,
                        dockEdge: dockEdge,
                      ),
                    ),
                  ),
                  // Event Navigation (Review mode)
                  DockPanelEntry(
                    id: PanelId.eventNavigation,
                    title: 'Event Navigation',
                    icon: Icons.search,
                    defaultFloatingPosition: const Offset(20, 200),
                    builder: (dockEdge) => StreamBuilder<Duration>(
                      stream: player.stream.position,
                      builder: (context, snapshot) => EventNavigationPanel(
                        controller: _eventsController,
                        onOpenEventsTable: _showEventsTable,
                        onNavigateTo: _navigateToEvent,
                        currentPosition: snapshot.data ?? player.state.position,
                      ),
                    ),
                  ),
                  // Player Tracking (Tracking mode)
                  DockPanelEntry(
                    id: PanelId.playerTracking,
                    title: 'Player Tracking',
                    icon: Icons.people,
                    defaultFloatingPosition: const Offset(20, 200),
                    builder: (dockEdge) => ListenableBuilder(
                      listenable: _trackingController,
                      builder: (context, _) => PlayerTrackingPanel(
                        controller: _trackingController,
                        player: player,
                        dockEdge: dockEdge,
                        onSave: _saveTrackingSession,
                        onLoad: _loadTrackingSession,
                        onExportCsv: _exportTrackingCsv,
                      ),
                    ),
                  ),
                ],
                ),
              ),

            // LAYER 5: Event Buttons with SmartHUD (Record mode)
            if (hasVideoLoaded)
              ListenableBuilder(
                listenable: Listenable.merge([_uiController, _eventsController, _altKey]),
                builder: (context, _) {
                  if (!_uiController.panelVisible(PanelId.eventButtons)) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
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
                                isAltPressed: _altKey.isPressed,
                                showTagNumbers: _altKey.showLabelNumbers,
                                showGradeNumbers: _altKey.showGradeNumbers,
                                taxonomy: _taxonomy,
                              ),
                            ),

                          // Event Buttons Row (with optional number badges)
                          EventButtonsPanel(
                            onEventTriggered: _onEventTriggered,
                            taxonomy: _taxonomy,
                            showNumbers: _altKey.showCategoryNumbers,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // LAYER 6: Video Progress Bar
            if (hasVideoLoaded)
              ListenableBuilder(
                listenable: _eventsController,
                builder: (context, _) => VideoProgressBar(
                  player: player,
                  events: _eventsController.filteredEvents,
                  onEventTap: _navigateToEvent,
                ),
              ),

            // LAYER 7: Shortcuts Panel (toggleable and draggable)
            if (hasVideoLoaded && _showShortcuts)
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

            // Docked Events Panel (right side)
            if (_showDockedEvents && hasVideoLoaded)
              ListenableBuilder(
                listenable: _eventsController,
                builder: (context, _) => StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, snapshot) => DockedEventsPanel(
                    controller: _eventsController,
                    taxonomy: _taxonomy,
                    onEventTap: _navigateToEvent,
                    onClose: _toggleDockedEvents,
                    currentPosition: snapshot.data ?? player.state.position,
                  ),
                ),
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
