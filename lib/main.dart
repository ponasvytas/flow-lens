import 'package:flutter/foundation.dart' show kIsWeb, mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:file_picker/file_picker.dart';

import 'app/app_bootstrap.dart';
import 'theme/flow_theme.dart';
import 'models/quick_event.dart';
import 'controllers/quick_events_controller.dart';
import 'services/quick_events_repository.dart';
import 'widgets/quick_events_panel.dart';
import 'app/app_composition.dart';
import 'utils/video_loader.dart';
import 'utils/player_config.dart';
import 'utils/native_player_helpers.dart';
import 'utils/perf.dart';
import 'utils/app_log.dart';
import 'models/drawing_models.dart';
import 'models/cloud_sessions.dart';
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
import 'services/taxonomy_repository.dart';
import 'services/event_import_export_service.dart';
import 'services/tracking_import_export_service.dart';
import 'services/event_session_repository.dart';
import 'services/tracking_session_repository.dart';
import 'models/sport_taxonomy.dart';
import 'controllers/events_controller.dart';
import 'controllers/event_entry_controller.dart';
import 'controllers/settings_controller.dart';
import 'controllers/ui_controller.dart';
import 'controllers/tracking_controller.dart';
import 'controllers/event_preview_coordinator.dart';
import 'controllers/account_controller.dart';
import 'models/app_mode.dart';
import 'models/dock_layout_state.dart';
import 'widgets/dock_layout.dart';
import 'widgets/dockable_panel.dart' show kAppTitleBarHeight;
import 'widgets/settings_view.dart';
import 'widgets/event_navigation_panel.dart';
import 'widgets/player_tracking_panel.dart';
import 'widgets/account_view.dart';
import 'widgets/cloud_sessions_view.dart';

Future<void> main() async {
  // 1. Initialize MediaKit (Crucial for the native video engine)
  WidgetsFlutterBinding.ensureInitialized();
  Perf.install();
  MediaKit.ensureInitialized();

  final composition = await AppBootstrap.create();
  runApp(
    MaterialApp(
      theme: FlowTheme.dark,
      home: HockeyAnalyzerScreen(composition: composition),
    ),
  );
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

class HockeyAnalyzerScreen extends StatefulWidget {
  const HockeyAnalyzerScreen({super.key, this.composition});

  final AppComposition? composition;

  @override
  State<HockeyAnalyzerScreen> createState() => _HockeyAnalyzerScreenState();
}

class _HockeyAnalyzerScreenState extends State<HockeyAnalyzerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AppRuntime _runtime;

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
  String? _videoSourcePath;

  // Actual video aspect ratio (width / height). Defaults to 16:9 until the
  // real dimensions are reported by the player. Used to size the video canvas
  // and to normalize/denormalize zoom transforms so the export geometry
  // matches what is shown on screen.
  double _videoAspectRatio = 16 / 9;
  StreamSubscription<VideoParams>? _videoParamsSub;
  StreamSubscription<Duration>? _previewPositionSub;
  late final EventPreviewCoordinator _eventPreview;
  int _taxonomyRequestGeneration = 0;

  // Event Tracking State
  EventsController get _eventsController => _runtime.eventsController;
  AccountController get _accountController => _runtime.accountController;
  TaxonomyRepository get _taxonomyRepository => _runtime.taxonomyRepository;
  SportTaxonomy? _taxonomy;
  SportProfile? _selectedSportProfile;

  // Settings
  SettingsController get _settingsController => _runtime.settingsController;

  // UI mode & panel management
  UIController get _uiController => _runtime.uiController;

  // Player tracking
  TrackingController get _trackingController => _runtime.trackingController;
  TrackingImportExportService get _trackingImportExportService =>
      _runtime.trackingImportExportService;
  EventSessionRepository? get _eventSessionRepository =>
      _runtime.eventSessionRepository;
  TrackingSessionRepository? get _trackingSessionRepository =>
      _runtime.trackingSessionRepository;

  String? _activeEventCloudSessionId;
  String? _activeEventCloudSessionTitle;
  String? _activeTrackingCloudSessionId;
  String? _activeTrackingCloudSessionTitle;

  // Docked events panel
  bool _showDockedEvents = false;

  // Shortcuts panel visibility and position
  bool _showShortcuts = false;
  double _shortcutsPanelX = 0.0; // Will be set to right side in initState
  double _shortcutsPanelY = 100.0;

  // Alt+number workflow state
  final _altKey = EventEntryController();
  final _quickEvents = QuickEventsController(LocalQuickEventsRepository());
  final _lastQuickEvent = ValueNotifier<GameEvent?>(null);
  String? _videoIdentity;

  // Root focus node — lets us reclaim keyboard focus after dialogs / HUD.
  final FocusNode _rootFocus = FocusNode(debugLabel: 'rootShortcuts');

  // Speed control state for hold-to-speed shortcuts
  double _previousPlaybackSpeed = 1.0;
  double _previousVolume = 100.0;
  bool _isSpeedShortcutActive = false;

  EventImportExportService get _eventImportExportService =>
      _runtime.eventImportExportService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtime = (widget.composition ?? AppComposition.local()).createRuntime();

    // Initialize shortcuts panel position (right side after first frame)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _shortcutsPanelX =
              MediaQuery.of(context).size.width - 340; // 320 width + 20 margin
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
        logLevel: Perf.enabled ? MPVLogLevel.info : MPVLogLevel.warn,
      ),
    );

    // Native-only: enable hardware decoding and demuxer cache for faster seeking
    configureNativePlayer(player);

    controller = VideoController(player);

    _eventPreview = EventPreviewCoordinator(
      seek: player.seek,
      play: player.play,
      pause: player.pause,
      duration: () => player.state.duration,
      onError: (error, _) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Event preview failed: $error')));
      },
    );
    _previewPositionSub = player.stream.position.listen(
      _eventPreview.onPosition,
    );

    // Track the real video aspect ratio so the canvas matches the source
    // footage instead of assuming 16:9 (which letterboxes wider/narrower
    // footage with black bars).
    _videoParamsSub = player.stream.videoParams.listen((params) {
      final w = params.dw ?? params.w;
      final h = params.dh ?? params.h;
      if (w != null && h != null && w > 0 && h > 0) {
        final aspect = w / h;
        if ((aspect - _videoAspectRatio).abs() > 0.001 && mounted) {
          setState(() => _videoAspectRatio = aspect);
        }
      }
    });

    _initializeSettingsAndDeepLink();
  }

  Future<void> _initializeSettingsAndDeepLink() async {
    await Future.wait([
      _settingsController.loadSettings(),
      _uiController.loadDockLayouts(),
      _quickEvents.load(),
    ]);
    if (!mounted) return;
    _uiController.initializeRecommendedLayouts();
    await player.setRate(_settingsController.settings.defaultPlaybackSpeed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
  }

  /// Parse URL query parameters and auto-load a video if present.
  /// Supported params:
  ///   video : direct, URL-encoded media URL (e.g. https://cdn.example.com/game.mp4)
  ///   sport : sport profile name (e.g. "hockey"). Defaults to first enabled profile.
  ///   t     : initial playback position in seconds (int or float). Optional.
  void _handleDeepLink() {
    if (!mounted) return;
    final base = Uri.base;
    AppLog.debug('[DeepLink] Uri.base=$base');
    AppLog.debug('[DeepLink] queryParameters=${base.queryParameters}');
    final params = base.queryParameters;
    final videoUrl = params['video'];
    final sportName = params['sport'];
    final tParam = params['t'];
    AppLog.debug('[DeepLink] video=$videoUrl sport=$sportName t=$tParam');

    if (videoUrl == null || videoUrl.isEmpty) {
      AppLog.debug('[DeepLink] no video param, skipping auto-load');
      return;
    }

    // Select a sport profile (required before the player UI is shown).
    final wanted = sportName ?? 'hockey';
    final profile = SportProfile.availableProfiles.firstWhere(
      (p) => p.enabled && p.name == wanted,
      orElse: () => SportProfile.availableProfiles.firstWhere(
        (p) => p.enabled,
        orElse: () => SportProfile.availableProfiles.first,
      ),
    );
    _onSportSelected(profile);

    // Load the video, then seek to ?t= if requested.
    Duration? initialPosition;
    if (tParam != null) {
      final secs = double.tryParse(tParam);
      if (secs != null && secs > 0) {
        initialPosition = Duration(milliseconds: (secs * 1000).round());
      }
    }
    _loadUrl(videoUrl, initialPosition: initialPosition);
  }

  Future<void> _loadTaxonomy() async {
    if (_selectedSportProfile == null) return;
    final generation = ++_taxonomyRequestGeneration;
    final sportName = _selectedSportProfile!.name;
    try {
      final taxonomy = await _taxonomyRepository.loadSportTaxonomy(sportName);
      if (!mounted || generation != _taxonomyRequestGeneration) return;
      setState(() {
        _taxonomy = taxonomy;
      });
      if (_videoIdentity != null) {
        _quickEvents.selectGame(_videoIdentity!, taxonomy);
      }
    } catch (e) {
      AppLog.debug('Error loading taxonomy: $e');
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
    WidgetsBinding.instance.removeObserver(this);
    _taxonomyRequestGeneration++;
    _eventPreview.dispose();
    _previewPositionSub?.cancel();
    _rootFocus.dispose();
    _zoomAnimationController?.dispose();
    _videoParamsSub?.cancel();
    releaseVideoUrl(_videoSourcePath);
    player.dispose(); // Always clean up video memory!
    _runtime.dispose();
    _transformationController.dispose();
    _drawing.dispose();
    _altKey.dispose();
    _quickEvents.dispose();
    _lastQuickEvent.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      // Web: Use native HTML file picker to avoid loading file into memory
      // This allows files >2GB to be loaded
      final url = await pickVideoFileWeb();
      if (url != null) {
        await _replaceVideoSource(url);
      }
    } else {
      // Native platforms: Use file_picker with path
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null) {
        final String? path = result.files.single.path;
        if (path != null) {
          await _replaceVideoSource(
            path,
            identity: '${result.files.single.name}:${result.files.single.size}',
          );
        } else {
          AppLog.debug("Error: No file path available");
        }
      }
    }
  }

  Future<void> _saveEvents() async {
    try {
      await _eventImportExportService.saveEvents(_eventsController.allEvents);
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
      final events = await _eventImportExportService.loadEvents();
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
      await _trackingImportExportService.saveSession(
        _trackingController.session,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tracking session saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save tracking: $e')));
      }
    }
  }

  Future<void> _loadTrackingSession() async {
    try {
      final session = await _trackingImportExportService.loadSession();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tracking: $e')));
      }
    }
  }

  Future<void> _exportTrackingCsv() async {
    try {
      await _trackingImportExportService.exportCsv(_trackingController.session);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tracking CSV exported')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to export CSV: $e')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mode switching (stops active timers when leaving tracking mode)
  // ---------------------------------------------------------------------------

  void _changeMode(AppMode mode) {
    _restoreFastPlayback();
    _eventPreview.cancel();
    _altKey.exit();
    _eventsController.selectEvent(null);
    if (mode != AppMode.review && _drawing.isDrawingMode) {
      _drawing.toggleDrawingMode();
    }
    if (_uiController.currentMode == AppMode.tracking &&
        mode != AppMode.tracking) {
      _trackingController.stopAllTimers(timestamp: player.state.position);
    }
    _uiController.setMode(mode);
  }

  Future<void> _loadUrl(String url, {Duration? initialPosition}) async {
    await _replaceVideoSource(url, initialPosition: initialPosition);
  }

  Future<bool> _replaceVideoSource(
    String source, {
    Duration? initialPosition,
    String? identity,
  }) async {
    _eventPreview.cancel();
    final previousSource = _videoSourcePath;
    if (mounted) setState(() => hasVideoLoaded = false);
    try {
      try {
        await player.stop();
      } finally {
        releaseVideoUrl(previousSource);
        _videoSourcePath = null;
      }
      await player.open(Media(source));
      await player.setRate(_settingsController.settings.defaultPlaybackSpeed);
      if (initialPosition != null && initialPosition > Duration.zero) {
        await player.seek(initialPosition);
      }
      _videoSourcePath = source;
      final uri = Uri.tryParse(source);
      _videoIdentity =
          identity ??
          videoFileIdentity(source) ??
          (uri == null
              ? source
              : uri.replace(query: '', fragment: '').toString());
      if (_taxonomy != null) {
        _quickEvents.selectGame(_videoIdentity!, _taxonomy!);
      }
      _lastQuickEvent.value = null;
      if (mounted) setState(() => hasVideoLoaded = true);
      return true;
    } catch (e) {
      releaseVideoUrl(source);
      _videoSourcePath = null;
      if (mounted) setState(() => hasVideoLoaded = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load video: $e')));
      }
      return false;
    }
  }

  void _changeSpeed(double speed) {
    player.setRate(speed);
    AppLog.debug("Playback speed: ${speed}x");
  }

  void _jumpForward(Duration duration) {
    _eventPreview.cancel();
    final currentPosition = player.state.position;
    final newPosition = currentPosition + duration;
    // Pause video during seek for smoother experience
    final wasPlaying = player.state.playing;
    player.pause();
    player.seek(newPosition).then((_) {
      if (wasPlaying) player.play();
    });
    AppLog.debug(
      "Jumped forward ${duration.inSeconds}s to ${newPosition.toString()}",
    );
  }

  void _jumpBackward(Duration duration) {
    _eventPreview.cancel();
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
    AppLog.debug(
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
    _drawing.addLaserTrail(
      LaserTrail(
        strokePoints,
        _drawing.drawingColor,
        _drawing.strokeWidth,
        DateTime.now(),
      ),
    );
  }

  void _removeTrail(LaserTrail trail) {
    _drawing.removeTrail(trail);
  }

  void _clearDrawing() => _drawing.clearAll();

  void _toggleDrawingMode() {
    if (_uiController.currentMode != AppMode.review) return;
    _drawing.toggleDrawingMode();
  }

  double _videoSurfaceWidth = 1;
  double get _videoWidth => _videoSurfaceWidth;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _restoreFastPlayback();
  }

  void _restoreFastPlayback() {
    if (!_isSpeedShortcutActive) return;
    _isSpeedShortcutActive = false;
    player.setRate(_previousPlaybackSpeed);
    nativeResyncAfterFF(player, () => _isSpeedShortcutActive).then((_) {
      if (mounted && !_isSpeedShortcutActive) player.setVolume(_previousVolume);
    });
  }

  /// Normalize a pixel-based transform to be resolution-independent.
  /// Translations are stored as fractions of video width/height.
  Matrix4 _normalizeTransform(Matrix4 transform) {
    final w = _videoWidth;
    final h = w / _videoAspectRatio;
    final normalized = transform.clone();
    normalized.setEntry(0, 3, transform.entry(0, 3) / w);
    normalized.setEntry(1, 3, transform.entry(1, 3) / h);
    return normalized;
  }

  /// Convert a normalized transform back to pixel values for the current size.
  Matrix4 _denormalizeTransform(Matrix4 transform) {
    final w = _videoWidth;
    final h = w / _videoAspectRatio;
    final denormalized = transform.clone();
    denormalized.setEntry(0, 3, transform.entry(0, 3) * w);
    denormalized.setEntry(1, 3, transform.entry(1, 3) * h);
    return denormalized;
  }

  void _navigateToEvent(GameEvent event) {
    final leadIn = _settingsController.settings.leadIn;
    final leadOut = _settingsController.settings.leadOut;
    _eventsController.selectEvent(event);

    void startPreview() {
      _eventPreview.preview(
        eventTimestamp: event.timestamp,
        leadIn: leadIn,
        leadOut: leadOut,
      );
    }

    final targetTransform = event.viewTransform != null
        ? _denormalizeTransform(event.viewTransform!)
        : Matrix4.identity();
    final currentTransform = _transformationController.value.clone();

    // If zoom state is changing, animate it and stagger the seek
    if (currentTransform != targetTransform) {
      _animateZoomTo(
        targetTransform,
        onMidpoint: () {
          startPreview();
        },
      );
    } else {
      startPreview();
    }
  }

  void _animateZoomTo(Matrix4 target, {VoidCallback? onMidpoint}) {
    _zoomAnimationController?.dispose();

    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _zoomAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: target,
        ).animate(
          CurvedAnimation(
            parent: _zoomAnimationController!,
            curve: Curves.easeInOut,
          ),
        );

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
    _eventPreview.cancel();
    if (player.state.playing) {
      player.pause();
    } else {
      player.play();
    }
  }

  void _showEventsTable() {
    if (_taxonomy == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Loading taxonomy...')));
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
          videoSourcePath: _videoSourcePath,
          videoDuration: player.state.duration,
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
            videoSourcePath: _videoSourcePath,
            videoDuration: player.state.duration,
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
        builder: (context) => SettingsView(controller: _settingsController),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => SettingsView(controller: _settingsController),
        ),
      );
    }
  }

  void _showAccount() {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (context) => AccountView(controller: _accountController),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AccountView(controller: _accountController),
        ),
      );
    }
  }

  void _showCloudSessions() {
    if (!_accountController.capabilities.canSaveCloudSessions) {
      _showAccount();
      return;
    }
    final eventRepository = _eventSessionRepository;
    final trackingRepository = _trackingSessionRepository;
    if (eventRepository == null || trackingRepository == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud sessions are unavailable.')),
      );
      return;
    }

    final view = CloudSessionsView(
      eventRepository: eventRepository,
      trackingRepository: trackingRepository,
      onSaveEvents: _taxonomy == null ? null : _saveCloudEventSession,
      onSaveTracking: _saveCloudTrackingSession,
      onLoadEvents: _loadCloudEventSession,
      onLoadTracking: _loadCloudTrackingSession,
      activeEventSessionId: _activeEventCloudSessionId,
      activeEventTitle: _activeEventCloudSessionTitle,
      activeTrackingSessionId: _activeTrackingCloudSessionId,
      activeTrackingTitle: _activeTrackingCloudSessionTitle,
      onEventArchived: (id) {
        if (_activeEventCloudSessionId == id) {
          setState(() {
            _activeEventCloudSessionId = null;
            _activeEventCloudSessionTitle = null;
          });
        }
      },
      onTrackingArchived: (id) {
        if (_activeTrackingCloudSessionId == id) {
          setState(() {
            _activeTrackingCloudSessionId = null;
            _activeTrackingCloudSessionTitle = null;
          });
        }
      },
    );
    if (MediaQuery.sizeOf(context).width > 700) {
      showDialog(context: context, builder: (_) => view);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => view));
    }
  }

  Future<void> _saveCloudEventSession(String title, bool asNew) async {
    final repository = _eventSessionRepository;
    final taxonomy = _taxonomy;
    if (repository == null || taxonomy == null) return;
    final draft = EventSessionDraft(
      title: title,
      sportId: taxonomy.sportId,
      taxonomyId: 'built-in:${taxonomy.sportId}',
      taxonomyRevision: taxonomy.contentVersion,
      taxonomySnapshot: taxonomy.toJson(),
      events: _eventsController.allEvents,
      sourceVideo: VideoSourceMetadata.fromSource(
        _videoSourcePath,
        duration: player.state.duration,
      ),
    );
    final activeId = _activeEventCloudSessionId;
    final session = asNew || activeId == null
        ? await repository.create(draft)
        : await repository.update(activeId, draft);
    if (!mounted) return;
    setState(() {
      _activeEventCloudSessionId = session.id;
      _activeEventCloudSessionTitle = session.title;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event timeline saved to cloud.')),
    );
  }

  Future<void> _saveCloudTrackingSession(String title, bool asNew) async {
    final repository = _trackingSessionRepository;
    if (repository == null) return;
    final draft = TrackingSessionDraft(
      title: title,
      sportId: _selectedSportProfile?.id ?? 'hockey',
      session: _trackingController.session,
      sourceVideo: VideoSourceMetadata.fromSource(
        _videoSourcePath,
        duration: player.state.duration,
      ),
    );
    final activeId = _activeTrackingCloudSessionId;
    final session = asNew || activeId == null
        ? await repository.create(draft)
        : await repository.update(activeId, draft);
    if (!mounted) return;
    setState(() {
      _activeTrackingCloudSessionId = session.id;
      _activeTrackingCloudSessionTitle = session.title;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking session saved to cloud.')),
    );
  }

  void _loadCloudEventSession(CloudEventSession session) {
    final taxonomy = SportTaxonomy.fromJson(session.taxonomySnapshot);
    taxonomy.validate();
    final profile = SportProfile.availableProfiles.firstWhere(
      (profile) => profile.id == session.sportId,
      orElse: () => SportProfile.availableProfiles.first,
    );
    setState(() {
      _selectedSportProfile = profile;
      _taxonomy = taxonomy;
      _activeEventCloudSessionId = session.id;
      _activeEventCloudSessionTitle = session.title;
    });
    _eventsController.setEvents(session.events);
    _eventsController.selectEvent(null);
    _lastQuickEvent.value = null;
    _quickEvents.selectGame('cloud:${session.id}', taxonomy);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded “${session.title}” from cloud.')),
    );
  }

  void _loadCloudTrackingSession(CloudTrackingSession session) {
    _trackingController.loadSession(session.session);
    setState(() {
      _activeTrackingCloudSessionId = session.id;
      _activeTrackingCloudSessionTitle = session.title;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded “${session.title}” from cloud.')),
    );
  }

  void _toggleDockedEvents() {
    if (MediaQuery.sizeOf(context).width < 1100) {
      _showEventsTable();
      return;
    }
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
      _shortcutsPanelY = _shortcutsPanelY.clamp(
        64.0,
        screenHeight - panelHeight,
      ); // 64 for title bar
    });
  }

  void _resetShortcutsPanelPosition() {
    setState(() {
      final screenWidth = MediaQuery.of(context).size.width;
      _shortcutsPanelX =
          screenWidth - 320 - 20; // 320px panel width + 20px margin
      _shortcutsPanelY = 100.0;
    });
  }

  bool _createEventFromAltNumber(int number) {
    final taxonomy = _taxonomy;
    if (taxonomy == null) return false;

    final categories = taxonomy.captureCategories;

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

    if (!_altKey.isEntryActive) return;

    if (_altKey.stage == EventEntryStage.labels) {
      final didSelect = _selectTagByNumber(number);
      if (didSelect) {
        _altKey.setStage(EventEntryStage.grades);
      }
      return;
    }

    if (_altKey.stage == EventEntryStage.grades) {
      final didSelect = _selectGradeByNumber(number);
      if (didSelect) {
        _altKey.setStage(EventEntryStage.categories);
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
    final eventTypes =
        category?.captureEventTypes ?? const <EventTypeTaxonomy>[];

    if (number < 1 || number > eventTypes.length) {
      return false;
    }

    final eventType = eventTypes[number - 1];
    _updateEvent(
      activeEvent.copyWith(
        detail: eventType.name,
        eventTypeId: eventType.eventTypeId,
        grade: eventType.defaultImpact,
        clearGrade: eventType.defaultImpact == null,
        definition: eventType.definition,
        taxonomyRevision: taxonomy.revision,
        context: {...activeEvent.context, ...eventType.contextDefaults},
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
      case 0:
        grade = null;
        break;
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
    _updateEvent(activeEvent.copyWith(grade: grade, clearGrade: number == 0));

    return true;
  }

  void _saveAndCloseSmartHud() {
    final activeEvent = _eventsController.activeEvent;
    if (activeEvent == null) return;

    if (activeEvent.isComplete) {
      if (_altKey.isEntryActive) {
        _altKey.setStage(EventEntryStage.categories);
      }
      _dismissHUD();
    }
  }

  void _recordQuickEvent(QuickEvent item) {
    if (!hasVideoLoaded ||
        _taxonomy == null ||
        _uiController.currentMode != AppMode.record) {
      return;
    }
    final event = _quickEvents.createEvent(
      item,
      _taxonomy!,
      player.state.position,
    );
    if (event == null) return;
    final transform = _transformationController.value;
    final captured = transform.getMaxScaleOnAxis() > 1.01
        ? event.copyWith(viewTransform: _normalizeTransform(transform))
        : event;
    _altKey.exit();
    _eventsController.selectEvent(null);
    _eventsController.addEvent(captured);
    _lastQuickEvent.value = captured;
  }

  Future<void> _showFullEventMenu() async {
    if (_taxonomy == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'All events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close event menu',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      _eventsController,
                      _quickEvents,
                    ]),
                    builder: (context, _) {
                      final event = _eventsController.activeEvent;
                      if (event == null) {
                        return EventButtonsPanel(
                          taxonomy: _taxonomy,
                          dockEdge: PanelDockEdge.right,
                          onEventTriggered: _onEventTriggered,
                        );
                      }
                      return Column(
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _eventsController.selectEvent(null),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Categories'),
                          ),
                          SmartHUD(
                            event: event,
                            taxonomy: _taxonomy,
                            onUpdateEvent: _updateEvent,
                            onDeleteEvent: _deleteEvent,
                            onSave: () {
                              _saveAndCloseSmartHud();
                              Navigator.pop(context);
                            },
                            onDismiss: () =>
                                _eventsController.selectEvent(null),
                          ),
                          if (event.eventTypeId != null)
                            TextButton.icon(
                              onPressed:
                                  _quickEvents.items.any(
                                    (item) =>
                                        item.categoryId == event.categoryId &&
                                        item.eventTypeId == event.eventTypeId &&
                                        item.grade == event.grade &&
                                        mapEquals(item.context, event.context),
                                  )
                                  ? null
                                  : () => _quickEvents.add(
                                      QuickEvent(
                                        categoryId: event.categoryId,
                                        eventTypeId: event.eventTypeId!,
                                        grade: event.grade,
                                        slotId:
                                            'quick-${DateTime.now().microsecondsSinceEpoch}',
                                        taxonomyRevision:
                                            event.taxonomyRevision,
                                        categoryLabel: event.label,
                                        eventLabel: event.detail,
                                        definition: event.definition,
                                        context: event.context,
                                      ),
                                    ),
                              icon: const Icon(Icons.add),
                              label: Text(
                                _quickEvents.items.any(
                                      (item) =>
                                          item.categoryId == event.categoryId &&
                                          item.eventTypeId ==
                                              event.eventTypeId &&
                                          item.grade == event.grade &&
                                          mapEquals(
                                            item.context,
                                            event.context,
                                          ),
                                    )
                                    ? 'In quick menu'
                                    : 'Add to quick menu',
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) {
      _eventsController.selectEvent(null);
      _rootFocus.requestFocus();
    }
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
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sportId: taxonomy.sportId,
      taxonomyRevision: taxonomy.revision,
      timestamp: position,
      categoryId: categoryId,
      label: category.name,
      grade: null, // Start with no grade
      viewTransform: isZoomed ? _normalizeTransform(currentTransform) : null,
    );

    _eventsController.selectEvent(newEvent);
    if (_altKey.isEntryActive) {
      _altKey.setStage(EventEntryStage.labels);
    }

    AppLog.debug("EVENT DRAFTED: ${newEvent.label} at ${position.toString()}");
  }

  void _updateEvent(GameEvent updatedEvent) {
    // A selected sub-event is complete; grading is optional.
    final isComplete = updatedEvent.isComplete;

    if (isComplete) {
      final existingIndex = _eventsController.allEvents.indexWhere(
        (e) => e.id == updatedEvent.id,
      );
      if (existingIndex != -1) {
        // Update existing
        _eventsController.updateEvent(updatedEvent);
      } else {
        // Add new confirmed event
        _eventsController.addEvent(updatedEvent);
        AppLog.debug("EVENT CONFIRMED: ${updatedEvent.label}");
      }
    }

    // Always update active event state so HUD reflects changes
    _eventsController.selectEvent(updatedEvent);
    if (isComplete &&
        _altKey.isEntryActive &&
        _altKey.stage == EventEntryStage.labels) {
      _altKey.setStage(EventEntryStage.grades);
    }
    if (_lastQuickEvent.value?.id == updatedEvent.id) {
      _lastQuickEvent.value = updatedEvent;
    }
  }

  void _deleteEvent(GameEvent event) {
    _eventsController.deleteEvent(event);
    _eventsController.selectEvent(null);
    if (_lastQuickEvent.value?.id == event.id) _lastQuickEvent.value = null;
    AppLog.debug("EVENT DELETED: ${event.label}");
    // Reclaim keyboard focus — removing the SmartHUD can leave focus orphaned.
    _rootFocus.requestFocus();
  }

  void _dismissHUD() {
    _eventsController.selectEvent(null);
    if (_altKey.isEntryActive) {
      _altKey.setStage(EventEntryStage.categories);
    }
    // Reclaim keyboard focus — removing the SmartHUD can leave focus orphaned.
    _rootFocus.requestFocus();
  }

  Widget _buildVideoSurface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _videoSurfaceWidth = math.max(
          1,
          math.min(
            constraints.maxWidth,
            constraints.maxHeight * _videoAspectRatio,
          ),
        );
        return Center(
          child: SizedBox(
            width: _videoSurfaceWidth,
            height: _videoSurfaceWidth / _videoAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: _drawing,
                  builder: (context, _) => VideoCanvas(
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
                    videoAspectRatio: _videoAspectRatio,
                    onStrokeCompleted: _onStrokeCompleted,
                    onLineCompleted: _onLineCompleted,
                    onArrowCompleted: _onArrowCompleted,
                    onClearDrawing: _clearDrawing,
                  ),
                ),
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
                      videoAspectRatio: _videoAspectRatio,
                      onCompleteDrawing: _completeLaserDrawing,
                      onRemoveTrail: _removeTrail,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<DockPanelEntry> _buildDockPanels(BuildContext context) => [
    DockPanelEntry(
      id: PanelId.eventButtons,
      title: 'Quick events',
      fillSideDock: true,
      icon: Icons.bolt_rounded,
      defaultFloatingPosition: const Offset(360, 160),
      defaultFloatingSize: const Size(300, 480),
      horizontalDockWidth: 480,
      contentRevision: _taxonomy,
      builder: (dockEdge) => _taxonomy == null
          ? const SizedBox.shrink()
          : ListenableBuilder(
              listenable: _altKey,
              builder: (context, _) => _altKey.showCategoryNumbers
                  ? SingleChildScrollView(
                      child: EventButtonsPanel(
                        taxonomy: _taxonomy,
                        dockEdge: dockEdge,
                        showNumbers: true,
                        entryPage: _altKey.page,
                        onEntryPageChanged: (page) => _altKey.setPage(
                          page,
                          _taxonomy!.captureCategories.length,
                        ),
                        onEventTriggered: _onEventTriggered,
                      ),
                    )
                  : QuickEventsPanel(
                      controller: _quickEvents,
                      taxonomy: _taxonomy!,
                      onRecord: _recordQuickEvent,
                      onAllEvents: _showFullEventMenu,
                      vertical:
                          dockEdge != PanelDockEdge.top &&
                          dockEdge != PanelDockEdge.bottom,
                      feedback: ValueListenableBuilder<GameEvent?>(
                        valueListenable: _lastQuickEvent,
                        builder: (context, event, _) => event == null
                            ? const SizedBox.shrink()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Recorded ${event.label} ${event.detail}',
                                      style: const TextStyle(
                                        color: FlowTheme.accent,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${event.timestamp.inMinutes}:${(event.timestamp.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      color: FlowTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Wrap(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          _eventsController.deleteEvent(event);
                                          _lastQuickEvent.value = null;
                                        },
                                        icon: const Icon(Icons.undo, size: 18),
                                        label: const Text('Undo'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          _eventsController.selectEvent(event);
                                          _showFullEventMenu();
                                        },
                                        child: const Text('Edit'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
    ),
    DockPanelEntry(
      id: PanelId.playbackControls,
      title: 'Playback',
      icon: Icons.play_circle_outline,
      defaultFloatingPosition: const Offset(20, 16),
      defaultFloatingSize: const Size(320, 170),
      horizontalDockWidth: 620,
      builder: (dockEdge) => ListenableBuilder(
        listenable: _settingsController,
        builder: (context, _) => DraggableControlBar(
          settings: _settingsController.settings,
          player: player,
          onSpeedChange: _changeSpeed,
          onJumpForward: _jumpForward,
          onJumpBackward: _jumpBackward,
          onTogglePlayPause: _togglePlayPause,
          dockEdge: dockEdge,
        ),
      ),
    ),
    DockPanelEntry(
      id: PanelId.drawingTools,
      title: 'Drawing',
      icon: Icons.draw,
      defaultFloatingPosition: Offset(
        MediaQuery.sizeOf(context).width - 320,
        136,
      ),
      defaultFloatingSize: const Size(300, 250),
      horizontalDockWidth: 520,
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
    DockPanelEntry(
      id: PanelId.eventNavigation,
      title: 'Event Navigation',
      icon: Icons.search,
      defaultFloatingPosition: const Offset(20, 136),
      defaultFloatingSize: const Size(300, 180),
      horizontalDockWidth: 360,
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
    DockPanelEntry(
      id: PanelId.playerTracking,
      contentRevision: _taxonomy,
      title: 'Player Tracking',
      icon: Icons.people,
      defaultFloatingPosition: const Offset(20, 136),
      defaultFloatingSize: const Size(420, 520),
      horizontalDockWidth: 760,
      builder: (dockEdge) => PlayerTrackingPanel(
        controller: _trackingController,
        taxonomy: _taxonomy,
        player: player,
        dockEdge: dockEdge,
        onSave: _saveTrackingSession,
        onLoad: _loadTrackingSession,
        onExportCsv: _exportTrackingCsv,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Perf.rebuildCount('HockeyAnalyzerScreen');

    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onFocusChange: (focused) {
        if (!focused) _restoreFastPlayback();
      },
      onKeyEvent: (node, event) {
        // =====================================================================
        // Guard: detect whether a text field currently has focus.
        // When typing in a TextField / EditableText we must let letter keys
        // through to the field instead of treating them as shortcuts.
        // EditableText internally builds a child Focus widget, so
        // primaryFocus.context.widget is Focus, not EditableText.
        // We walk up ancestors to find EditableText above the focused node.
        // =====================================================================
        final isTextFieldFocused =
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<EditableText>() !=
            null;

        if (ModalRoute.of(context)?.isCurrent != true) {
          return KeyEventResult.ignored;
        }
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

          // Alt key TAP: toggle latched alt-entry workflow (record mode).
          // Latched so the user does NOT hold Alt while pressing numbers.
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            if (mode == AppMode.record &&
                !isTextFieldFocused &&
                !isCtrlPressed &&
                !HardwareKeyboard.instance.isMetaPressed) {
              _altKey.toggle();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }

          // Entry-mode Esc: exit the latched workflow (and cancel any draft).
          if (mode == AppMode.record &&
              _altKey.isEntryActive &&
              !isTextFieldFocused &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            if (_eventsController.activeEvent != null) {
              _dismissHUD();
            }
            _altKey.exit();
            return KeyEventResult.handled;
          }

          if (_altKey.isEntryActive &&
              mode == AppMode.record &&
              !isTextFieldFocused &&
              !hasModifier &&
              !isShiftPressed &&
              !HardwareKeyboard.instance.isMetaPressed &&
              !_drawing.isDrawingMode) {
            final optionsCount = _altKey.stage == EventEntryStage.categories
                ? (_taxonomy?.captureCategories.length ?? 0)
                : (_taxonomy
                          ?.getCategoryById(
                            _eventsController.activeEvent?.categoryId ?? '',
                          )
                          ?.captureEventTypes
                          .length ??
                      0);
            if (_altKey.stage != EventEntryStage.grades &&
                (event.logicalKey == LogicalKeyboardKey.pageDown ||
                    event.logicalKey == LogicalKeyboardKey.pageUp)) {
              _altKey.setPage(
                _altKey.page +
                    (event.logicalKey == LogicalKeyboardKey.pageDown ? 1 : -1),
                optionsCount,
              );
              return KeyEventResult.handled;
            }
            final digit = EventEntryController.digitFor(event.logicalKey);
            if (digit != null) {
              if (_altKey.stage == EventEntryStage.grades) {
                _handleSmartHudNumber(digit);
              } else {
                final index = _altKey.selectionIndex(
                  event.logicalKey,
                  optionsCount,
                );
                if (index != null) {
                  if (_altKey.stage == EventEntryStage.categories &&
                      hasVideoLoaded) {
                    if (_createEventFromAltNumber(index + 1)) {
                      _altKey.setStage(EventEntryStage.labels);
                    }
                  } else if (_altKey.stage == EventEntryStage.labels) {
                    _handleSmartHudNumber(index + 1);
                  }
                }
              }
              return KeyEventResult.handled;
            }
          }

          // -----------------------------------------------------------------
          // 2. SmartHUD Enter/Esc (HUD active, not text-field)
          // -----------------------------------------------------------------
          if (_eventsController.activeEvent != null &&
              !_drawing.isDrawingMode &&
              !isTextFieldFocused) {
            if (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              _saveAndCloseSmartHud();
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              _dismissHUD();
              _altKey.exit();
              return KeyEventResult.handled;
            }
          }

          // -----------------------------------------------------------------
          // 3. Tracking hotkeys (tracking mode, NOT in text fields)
          //    Modified keys belong to system/app shortcuts.
          // -----------------------------------------------------------------
          if (mode == AppMode.tracking &&
              !isTextFieldFocused &&
              !isAltPressed &&
              !isCtrlPressed &&
              !isShiftPressed &&
              !HardwareKeyboard.instance.isMetaPressed) {
            final keyLabel = event.logicalKey.keyLabel.toLowerCase();
            if (keyLabel.isNotEmpty &&
                _trackingController.handleHotkeyDown(
                  keyLabel,
                  player.state.position,
                )) {
              return KeyEventResult.handled;
            }
          }

          // =================================================================
          // STOP HERE if a text field is focused — no bare-key shortcuts below
          // should fire while the user is typing.
          // =================================================================
          if (isTextFieldFocused) {
            return KeyEventResult.ignored;
          }

          // -----------------------------------------------------------------
          // 4. Global playback shortcuts (all modes)
          // -----------------------------------------------------------------

          if (mode == AppMode.record &&
              hasVideoLoaded &&
              !_altKey.isEntryActive &&
              !hasModifier &&
              !isShiftPressed &&
              !HardwareKeyboard.instance.isMetaPressed) {
            final key = event.logicalKey.keyLabel.toLowerCase();
            final item = _quickEvents.items
                .where((item) => item.hotkey == key)
                .firstOrNull;
            if (item != null) {
              _recordQuickEvent(item);
              return KeyEventResult.handled;
            }
          }

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
            AppLog.debug("Playback speed set to ${slowSpeed}x (slow)");
            return KeyEventResult.handled;
          }

          // 'D' key: Default playback speed
          if (event.logicalKey == LogicalKeyboardKey.keyD) {
            final defaultSpeed =
                _settingsController.settings.defaultPlaybackSpeed;
            player.setRate(defaultSpeed);
            AppLog.debug("Playback speed set to ${defaultSpeed}x (default)");
            return KeyEventResult.handled;
          }

          // Hold 'F': Fast forward
          if (event.logicalKey == LogicalKeyboardKey.keyF &&
              !_isSpeedShortcutActive) {
            _previousPlaybackSpeed = player.state.rate;
            _previousVolume = player.state.volume;
            _isSpeedShortcutActive = true;
            final fastSpeed = _settingsController.settings.fastPlaySpeed;
            player.setVolume(0);
            nativeMutePlayer(player);
            player.setRate(fastSpeed);
            AppLog.debug(
              "Fast forward: ${fastSpeed}x speed (previous: ${_previousPlaybackSpeed}x)",
            );
            return KeyEventResult.handled;
          }

          // 'M' key: Toggle mute/unmute
          if (event.logicalKey == LogicalKeyboardKey.keyM) {
            final currentVolume = player.state.volume;
            if (currentVolume > 0) {
              player.setVolume(0);
              AppLog.debug("Muted");
            } else {
              player.setVolume(100);
              AppLog.debug("Unmuted");
            }
            return KeyEventResult.handled;
          }

          // -----------------------------------------------------------------
          // 5. Drawing / annotation shortcuts (record + review modes only)
          // -----------------------------------------------------------------
          if (mode == AppMode.review) {
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
          if (mode == AppMode.tracking &&
              !isTextFieldFocused &&
              !isAltPressed &&
              !isCtrlPressed) {
            final keyLabel = event.logicalKey.keyLabel.toLowerCase();
            if (keyLabel.isNotEmpty &&
                _trackingController.handleHotkeyUp(
                  keyLabel,
                  player.state.position,
                )) {
              return KeyEventResult.handled;
            }
          }

          // Alt key released — entry mode is latched, so state is unchanged.
          // Consume in record mode to suppress the browser/OS menu activation.
          if (event.logicalKey == LogicalKeyboardKey.altLeft ||
              event.logicalKey == LogicalKeyboardKey.altRight) {
            if (mode == AppMode.record) {
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          }

          // Release 'F' to restore previous speed
          if (!isTextFieldFocused &&
              event.logicalKey == LogicalKeyboardKey.keyF &&
              _isSpeedShortcutActive) {
            _restoreFastPlayback();
            AppLog.debug("Speed restored to ${_previousPlaybackSpeed}x");
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Row(
            children: [
              // Main content area (video + overlays)
              Expanded(
                child: Stack(
                  children: [
                    // LAYER 0: Branded Title Bar (Top)
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _uiController,
                        _accountController,
                      ]),
                      builder: (context, _) => Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: BrandedTitleBar(
                          onResetLayout: _uiController.resetLayout,
                          onShowShortcuts: _toggleShortcutsPanel,
                          showShortcuts: _showShortcuts,
                          currentMode: _uiController.currentMode,
                          onModeChanged: _changeMode,
                          onSaveEvents: hasVideoLoaded ? _saveEvents : null,
                          onLoadEvents: hasVideoLoaded ? _loadEvents : null,
                          onShowEventsTable: hasVideoLoaded
                              ? _showEventsTable
                              : null,
                          onShowSettings: hasVideoLoaded ? _showSettings : null,
                          onShowAccount: _showAccount,
                          onShowCloudSessions: _showCloudSessions,
                          isSignedIn: _accountController.isSignedIn,
                          hasPremium:
                              _accountController.capabilities.canSyncSettings,
                          onToggleDockedEvents: hasVideoLoaded
                              ? _toggleDockedEvents
                              : null,
                          showDockedEvents: _showDockedEvents,
                        ),
                      ),
                    ),

                    // Video canvas is hosted by DockLayout after a video loads.
                    if (!hasVideoLoaded)
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
                            videoAspectRatio: _videoAspectRatio,
                            onStrokeCompleted: _onStrokeCompleted,
                            onLineCompleted: _onLineCompleted,
                            onArrowCompleted: _onArrowCompleted,
                            onClearDrawing: _clearDrawing,
                          ),
                        ),
                      ),

                    // LAYER 2: Laser trails and cursor (No zoom scaling - overlay)
                    // Only show when laser is active or there are trails to display
                    if (!hasVideoLoaded)
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
                            videoAspectRatio: _videoAspectRatio,
                            onCompleteDrawing: _completeLaserDrawing,
                            onRemoveTrail: _removeTrail,
                          );
                        },
                      ),

                    // LAYER 3–5c: All dockable panels via DockLayout
                    if (hasVideoLoaded)
                      ListenableBuilder(
                        listenable: _uiController,
                        builder: (context, _) => Padding(
                          padding: const EdgeInsets.only(
                            top: kAppTitleBarHeight,
                            bottom: 70,
                          ),
                          child: DockLayout(
                            adaptive: true,
                            uiController: _uiController,
                            panels: _buildDockPanels(context),
                            child: _buildVideoSurface(),
                          ),
                        ),
                      ),

                    // SmartHUD stays over the video while event buttons use the dock.
                    if (hasVideoLoaded)
                      ListenableBuilder(
                        listenable: Listenable.merge([
                          _uiController,
                          _eventsController,
                          _altKey,
                        ]),
                        builder: (context, _) {
                          if (!_uiController.panelVisible(
                                PanelId.eventButtons,
                              ) ||
                              _eventsController.activeEvent == null) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            top: kAppTitleBarHeight,
                            bottom: 80,
                            left: 0,
                            right: 0,
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: SmartHUD(
                                event: _eventsController.activeEvent!,
                                onUpdateEvent: _updateEvent,
                                onDeleteEvent: _deleteEvent,
                                onDismiss: _dismissHUD,
                                onSave: _saveAndCloseSmartHud,
                                isAltPressed: _altKey.isEntryActive,
                                showTagNumbers: _altKey.showLabelNumbers,
                                entryPage: _altKey.page,
                                onEntryPageChanged: (page) => _altKey.setPage(
                                  page,
                                  _taxonomy!
                                      .getCategoryById(
                                        _eventsController
                                            .activeEvent!
                                            .categoryId,
                                      )!
                                      .captureEventTypes
                                      .length,
                                ),
                                showGradeNumbers: _altKey.showGradeNumbers,
                                taxonomy: _taxonomy,
                              ),
                            ),
                          );
                        },
                      ),

                    // LAYER 6: Video Progress Bar
                    if (hasVideoLoaded)
                      ListenableBuilder(
                        listenable: _eventsController.dataRevision,
                        builder: (context, _) => VideoProgressBar(
                          player: player,
                          events: _eventsController.filteredEvents,
                          onEventTap: _navigateToEvent,
                          onScrubStart: _eventPreview.cancel,
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
                      Positioned.fill(
                        top: 64,
                        child: SingleChildScrollView(
                          child: VideoPicker(
                            onPickVideo: _pickVideo,
                            onLoadUrl: _loadUrl,
                            onSportSelected: _onSportSelected,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Docked Events Panel (right side)
              if (_showDockedEvents &&
                  hasVideoLoaded &&
                  MediaQuery.sizeOf(context).width >= 1100)
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
      ),
    );
  }
}

// Custom painter for drawing on video
// Moved to lib/painters/drawing_painter.dart

// Custom painter for laser pointer trails and cursor
// Moved to lib/painters/laser_painter.dart
