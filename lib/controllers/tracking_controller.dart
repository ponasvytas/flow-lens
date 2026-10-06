import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../models/tracking_template.dart';
import '../utils/app_hotkeys.dart';

/// Key for identifying a running timer: (subjectId, trackerId).
typedef _TimerKey = ({String subjectId, String trackerId});

@immutable
class TrackingCellStats {
  final int counterValue;
  final Duration timerDuration;
  final bool timerRunning;
  final Duration? timerStartedAt;

  const TrackingCellStats({
    this.counterValue = 0,
    this.timerDuration = Duration.zero,
    this.timerRunning = false,
    this.timerStartedAt,
  });

  TrackingCellStats copyWith({
    int? counterValue,
    Duration? timerDuration,
    bool? timerRunning,
    Duration? timerStartedAt,
    bool clearTimerStart = false,
  }) {
    return TrackingCellStats(
      counterValue: counterValue ?? this.counterValue,
      timerDuration: timerDuration ?? this.timerDuration,
      timerRunning: timerRunning ?? this.timerRunning,
      timerStartedAt: clearTimerStart
          ? null
          : timerStartedAt ?? this.timerStartedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TrackingCellStats &&
      counterValue == other.counterValue &&
      timerDuration == other.timerDuration &&
      timerRunning == other.timerRunning &&
      timerStartedAt == other.timerStartedAt;

  @override
  int get hashCode =>
      Object.hash(counterValue, timerDuration, timerRunning, timerStartedAt);
}

/// Holds the start timestamp for an active timer.
class _ActiveTimer {
  final Duration startTimestamp;

  const _ActiveTimer({required this.startTimestamp});
}

/// Central state controller for player tracking.
///
/// Owns the tracking session (subjects, tracker definitions, raw events)
/// and provides methods to record counter and timer actions.
///
/// All timestamps must be **video positions** (not wall-clock time) so that
/// playback speed and pauses do not count wall time. Finalize timers before seeks.
class TrackingController extends ChangeNotifier {
  TrackingSession _session;

  /// Currently active timers keyed by (subjectId, trackerId).
  final Map<_TimerKey, _ActiveTimer> _activeTimers = {};
  final Map<_TimerKey, TrackingCellStats> _cellStats = {};
  final Map<_TimerKey, ValueNotifier<TrackingCellStats>> _cellNotifiers = {};

  /// Optional: the currently "focused" subject for quick-action hotkeys.
  String? _activeSubjectId;

  int _nextEventId = 1;
  final Map<(String, String?), TrackingSession> _workspaces = {};
  TrackingSession? _configurationBefore;
  TrackingSession? _configurationAfter;
  Map<_TimerKey, _ActiveTimer>? _timersBefore;
  String? _subjectBefore;
  bool _batching = false;

  TrackingController({TrackingSession? session})
    : _session =
          session ??
          TrackingSession(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
          ) {
    _rebuildIndexes();
  }

  // -----------------------------------------------------------------------
  // Getters
  // -----------------------------------------------------------------------

  TrackingSession get session => _session;

  List<TrackingSubject> get subjects => _session.subjects
      .where((s) => !_session.hiddenSubjectIds.contains(s.id))
      .toList(growable: false);
  List<TrackingDefinition> get trackers {
    final byId = {for (final tracker in _session.trackers) tracker.id: tracker};
    return [
      for (final id in _session.visibleTrackerIds)
        if (byId[id] != null) byId[id]!,
    ];
  }

  List<TrackingDefinition> trackersForSubject(String subjectId) => trackers
      .where(
        (t) =>
            !_session.trackerSubjects.containsKey(t.id) ||
            _session.trackerSubjects[t.id]!.contains(subjectId),
      )
      .toList();
  List<TrackingEvent> get events => _session.events;

  String? get activeSubjectId => _activeSubjectId;

  /// Whether a timer is currently running for [subjectId] + [trackerId].
  bool isTimerRunning(String subjectId, String trackerId) {
    return _activeTimers.containsKey((
      subjectId: subjectId,
      trackerId: trackerId,
    ));
  }

  /// All currently active timer keys, useful for UI indicators.
  List<({String subjectId, String trackerId})> get activeTimerKeys =>
      _activeTimers.keys.toList();

  /// Start timestamp of a running timer (for live display).
  Duration? timerStartTimestamp(String subjectId, String trackerId) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    return _activeTimers[key]?.startTimestamp;
  }

  TrackingCellStats getCellStats(String subjectId, String trackerId) =>
      _cellStats[(subjectId: subjectId, trackerId: trackerId)] ??
      const TrackingCellStats();

  ValueListenable<TrackingCellStats> cellStatsListenable(
    String subjectId,
    String trackerId,
  ) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    return _cellNotifiers.putIfAbsent(
      key,
      () => ValueNotifier<TrackingCellStats>(
        _cellStats[key] ?? const TrackingCellStats(),
      ),
    );
  }

  /// Last action feedback — set briefly after a hotkey/button action so the UI
  /// can flash the affected cell. Cleared by [clearFeedback].
  ({String subjectId, String trackerId})? _lastFeedback;
  ({String subjectId, String trackerId})? get lastFeedback => _lastFeedback;

  void clearFeedback() {
    _lastFeedback = null;
    // No notifyListeners — the UI timer should handle its own rebuild.
  }

  // -----------------------------------------------------------------------
  // Session management
  // -----------------------------------------------------------------------

  void loadSession(TrackingSession session) {
    _rememberWorkspace();
    _session = session;
    _configurationAfter = null;
    _activeTimers.clear();
    _activeSubjectId = null;
    _rebuildIndexes();
    notifyListeners();
  }

  void clearSession() {
    _session = TrackingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sportId: _session.sportId,
      videoIdentity: _session.videoIdentity,
    );
    _activeTimers.clear();
    _activeSubjectId = null;
    _nextEventId = 1;
    _cellStats.clear();
    _syncAllCellNotifiers();
    notifyListeners();
  }

  void _rememberWorkspace() {
    final sport = _session.sportId;
    if (sport != null) _workspaces[(sport, _session.videoIdentity)] = _session;
  }

  void activateWorkspace({
    required String sportId,
    required String? videoIdentity,
    required Duration timestamp,
    String? taxonomyRevision,
  }) {
    if (_session.sportId == sportId &&
        _session.videoIdentity == videoIdentity) {
      return;
    }
    stopAllTimers(timestamp: timestamp);
    _rememberWorkspace();
    loadSession(
      _workspaces[(sportId, videoIdentity)] ??
          TrackingSession(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            sportId: sportId,
            videoIdentity: videoIdentity,
            taxonomyRevision: taxonomyRevision,
          ),
    );
  }

  void _validateDefinitions(
    List<TrackingDefinition> selected, {
    bool allowUpdate = false,
  }) {
    if (selected.map((t) => t.id).toSet().length != selected.length) {
      throw const FormatException('Choose each tracker once.');
    }
    final sports = {
      ..._session.trackers.map((t) => t.sportId),
      ...selected.map((t) => t.sportId),
      if (_session.sportId != null) _session.sportId!,
    };
    if (sports.length > 1) {
      throw StateError('Trackers must belong to the session sport.');
    }
    for (final tracker in selected) {
      final previous = _session.trackers
          .where((t) => t.id == tracker.id)
          .firstOrNull;
      if (!allowUpdate && previous != null && previous != tracker) {
        throw StateError(
          '“${tracker.label}” differs from the saved definition. Keep the session version or start a new session.',
        );
      }
    }
  }

  void _stopMatchingTimers(
    bool Function(_TimerKey) matches,
    Duration? timestamp,
  ) {
    for (final key in _activeTimers.keys.where(matches).toList()) {
      if (timestamp == null) {
        cancelTimer(
          subjectId: key.subjectId,
          trackerId: key.trackerId,
          timestamp: _activeTimers[key]!.startTimestamp,
        );
      } else {
        stopTimer(
          subjectId: key.subjectId,
          trackerId: key.trackerId,
          timestamp: timestamp,
        );
      }
    }
  }

  /// Changes visibility without deleting the definitions used by recorded data.
  void configureTrackers(
    List<TrackingDefinition> selected, {
    Duration? timestamp,
  }) {
    _validateDefinitions(selected);
    final ids = selected.map((t) => t.id).toList();
    if (listEquals(ids, _session.visibleTrackerIds)) return;
    _batching = true;
    try {
      _stopMatchingTimers((key) => !ids.contains(key.trackerId), timestamp);
      final known = _session.trackers.map((t) => t.id).toSet();
      _session = _session.copyWith(
        trackers: [
          ..._session.trackers,
          ...selected.where((t) => !known.contains(t.id)),
        ],
        visibleTrackerIds: ids,
        clearTemplate: true,
      );
      _rebuildIndexes(preserveActiveTimers: true);
    } finally {
      _batching = false;
    }
    notifyListeners();
  }

  void applyTemplate(
    TrackingTemplate template, {
    required String subjectId,
    required Duration timestamp,
    bool replaceVisible = false,
  }) {
    template.validate();
    if (!subjects.any((s) => s.id == subjectId)) {
      throw StateError('Choose a subject in this session.');
    }
    _validateDefinitions(template.trackers);
    if (_session.sportId != null && _session.sportId != template.sportId) {
      throw StateError('Choose a template for the current sport.');
    }
    final ids = template.trackers.map((t) => t.id).toList();
    final visible = replaceVisible
        ? ids
        : {..._session.visibleTrackerIds, ...ids}.toList();
    final bindings = Map<String, List<String>>.from(_session.trackerSubjects);
    for (final id in ids) {
      final existing = replaceVisible
          ? <String>[]
          : bindings[id] ??
                (_session.visibleTrackerIds.contains(id)
                    ? subjects.map((s) => s.id).toList()
                    : <String>[]);
      bindings[id] = {...existing, subjectId}.toList();
    }
    if (listEquals(visible, _session.visibleTrackerIds) &&
        ids.every(
          (id) => listEquals(bindings[id], _session.trackerSubjects[id]),
        ) &&
        _session.templateId == template.id &&
        _session.templateRevision == template.revision &&
        _activeSubjectId == subjectId) {
      return;
    }
    _configurationBefore = _session;
    _timersBefore = Map.of(_activeTimers);
    _subjectBefore = _activeSubjectId;
    _batching = true;
    try {
      _stopMatchingTimers(
        (key) =>
            !visible.contains(key.trackerId) ||
            (bindings.containsKey(key.trackerId) &&
                !bindings[key.trackerId]!.contains(key.subjectId)),
        timestamp,
      );
      final known = _session.trackers.map((t) => t.id).toSet();
      _session = _session.copyWith(
        sportId: template.sportId,
        trackers: [
          ..._session.trackers,
          ...template.trackers.where((t) => !known.contains(t.id)),
        ],
        visibleTrackerIds: visible,
        trackerSubjects: bindings,
        templateId: template.id,
        templateRevision: template.revision,
      );
      _activeSubjectId = subjectId;
      _rebuildIndexes(preserveActiveTimers: true);
      _configurationAfter = _session;
    } finally {
      _batching = false;
    }
    notifyListeners();
  }

  void applyTemplateToSubject(
    TrackingTemplate template, {
    String? subjectId,
    TrackingSubject? newSubject,
    required Duration timestamp,
    bool replaceVisible = false,
  }) {
    template.validate();
    _validateDefinitions(template.trackers);
    if ((subjectId == null) == (newSubject == null)) {
      throw StateError('Choose an existing subject or create one.');
    }
    final before = _session;
    final timers = Map<_TimerKey, _ActiveTimer>.of(_activeTimers);
    final focus = _activeSubjectId;
    if (newSubject != null) {
      _batching = true;
      addSubject(newSubject);
      _batching = false;
    }
    try {
      applyTemplate(
        template,
        subjectId: subjectId ?? newSubject!.id,
        timestamp: timestamp,
        replaceVisible: replaceVisible,
      );
      if (newSubject != null) {
        _configurationBefore = before;
        _timersBefore = timers;
        _subjectBefore = focus;
      }
    } catch (_) {
      _session = before;
      _activeTimers
        ..clear()
        ..addAll(timers);
      _activeSubjectId = focus;
      _rebuildIndexes(preserveActiveTimers: true);
      rethrow;
    }
  }

  bool get canUndoTemplate =>
      _configurationBefore != null && identical(_session, _configurationAfter);

  bool undoTemplate() {
    if (!canUndoTemplate) return false;
    _session = _configurationBefore!;
    _activeTimers
      ..clear()
      ..addAll(_timersBefore!);
    _activeSubjectId = _subjectBefore;
    _configurationAfter = null;
    _rebuildIndexes(preserveActiveTimers: true);
    notifyListeners();
    return true;
  }

  @override
  void notifyListeners() {
    if (!_batching) super.notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Subject management
  // -----------------------------------------------------------------------

  void addSubject(TrackingSubject subject) {
    final existing = _session.subjects
        .where((s) => s.id == subject.id)
        .firstOrNull;
    _session = _session.copyWith(
      subjects: existing == null
          ? [..._session.subjects, subject]
          : _session.subjects,
      hiddenSubjectIds: {..._session.hiddenSubjectIds}..remove(subject.id),
    );
    notifyListeners();
  }

  void removeSubject(String subjectId, {Duration? timestamp}) {
    _stopMatchingTimers((key) => key.subjectId == subjectId, timestamp);
    _session = _session.copyWith(
      hiddenSubjectIds: {..._session.hiddenSubjectIds, subjectId},
    );
    if (_activeSubjectId == subjectId) {
      _activeSubjectId = null;
    }
    notifyListeners();
  }

  void updateSubject(TrackingSubject updated) {
    final index = _session.subjects.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      _session = _session.copyWith(
        subjects: _session.subjects
            .map((s) => s.id == updated.id ? updated : s)
            .toList(),
      );
      notifyListeners();
    }
  }

  void restoreSubjects() {
    _session = _session.copyWith(hiddenSubjectIds: {});
    notifyListeners();
  }

  void setActiveSubject(String? subjectId) {
    _activeSubjectId = subjectId;
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Tracker definition management
  // -----------------------------------------------------------------------

  void addTracker(TrackingDefinition tracker) {
    configureTrackers([...trackers.where((t) => t.id != tracker.id), tracker]);
  }

  void removeTracker(String trackerId, {Duration? timestamp}) {
    configureTrackers(
      trackers.where((t) => t.id != trackerId).toList(),
      timestamp: timestamp,
    );
  }

  void updateTracker(TrackingDefinition updated) {
    final index = _session.trackers.indexWhere((t) => t.id == updated.id);
    if (index != -1) {
      if (_session.events.any((e) => e.trackerId == updated.id)) {
        throw StateError(
          'Recorded definitions cannot be changed. Use a new tracker ID.',
        );
      }
      _validateDefinitions([updated], allowUpdate: true);
      _session = _session.copyWith(
        trackers: _session.trackers
            .map((t) => t.id == updated.id ? updated : t)
            .toList(),
      );
      notifyListeners();
    }
  }

  // -----------------------------------------------------------------------
  // Counter actions
  // -----------------------------------------------------------------------

  /// Record a counter increment for [subjectId] + [trackerId] at the current
  /// video [timestamp].
  TrackingEvent incrementCounter({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
    int delta = 1,
  }) {
    final event = _createEvent(
      subjectId: subjectId,
      trackerId: trackerId,
      timestamp: timestamp,
      action: TrackingAction.increment,
      delta: delta,
    );
    _session = _session.copyWith(events: [..._session.events, event]);
    _updateCounter(subjectId, trackerId, delta);
    notifyListeners();
    return event;
  }

  /// Record a counter decrement. Convenience wrapper that logs negative delta.
  TrackingEvent decrementCounter({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
    int delta = 1,
  }) {
    final event = _createEvent(
      subjectId: subjectId,
      trackerId: trackerId,
      timestamp: timestamp,
      action: TrackingAction.decrement,
      delta: delta,
    );
    _session = _session.copyWith(events: [..._session.events, event]);
    _updateCounter(subjectId, trackerId, -delta);
    notifyListeners();
    return event;
  }

  // -----------------------------------------------------------------------
  // Timer actions
  // -----------------------------------------------------------------------

  /// Start a timer for [subjectId] + [trackerId] at the current video
  /// [timestamp]. If already running, this is a no-op.
  TrackingEvent? startTimer({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
  }) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    if (_activeTimers.containsKey(key)) return null; // already running

    _activeTimers[key] = _ActiveTimer(startTimestamp: timestamp);

    final event = _createEvent(
      subjectId: subjectId,
      trackerId: trackerId,
      timestamp: timestamp,
      action: TrackingAction.timerStart,
    );
    _session = _session.copyWith(events: [..._session.events, event]);
    _setCellStats(
      key,
      getCellStats(
        subjectId,
        trackerId,
      ).copyWith(timerRunning: true, timerStartedAt: timestamp),
    );
    notifyListeners();
    return event;
  }

  /// Stop a running timer for [subjectId] + [trackerId] at the current video
  /// [timestamp]. Returns null if the timer was not running.
  TrackingEvent? stopTimer({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
  }) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    if (!_activeTimers.containsKey(key)) return null; // not running

    final active = _activeTimers.remove(key)!;

    final event = _createEvent(
      subjectId: subjectId,
      trackerId: trackerId,
      timestamp: timestamp,
      action: TrackingAction.timerStop,
    );
    _session = _session.copyWith(events: [..._session.events, event]);
    final previous = getCellStats(subjectId, trackerId);
    final elapsed = timestamp >= active.startTimestamp
        ? timestamp - active.startTimestamp
        : Duration.zero;
    _setCellStats(
      key,
      previous.copyWith(
        timerDuration: previous.timerDuration + elapsed,
        timerRunning: false,
        clearTimerStart: true,
      ),
    );
    notifyListeners();
    return event;
  }

  /// Toggle a timer: start it if stopped, stop it if running.
  TrackingEvent? toggleTimer({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
  }) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    if (_activeTimers.containsKey(key)) {
      return stopTimer(
        subjectId: subjectId,
        trackerId: trackerId,
        timestamp: timestamp,
      );
    } else {
      return startTimer(
        subjectId: subjectId,
        trackerId: trackerId,
        timestamp: timestamp,
      );
    }
  }

  /// Cancel a running timer without recording the interval. Logs a
  /// [TrackingAction.timerCancel] event.
  TrackingEvent? cancelTimer({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
  }) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    if (!_activeTimers.containsKey(key)) return null;

    _activeTimers.remove(key);

    final event = _createEvent(
      subjectId: subjectId,
      trackerId: trackerId,
      timestamp: timestamp,
      action: TrackingAction.timerCancel,
    );
    _session = _session.copyWith(events: [..._session.events, event]);
    _setCellStats(
      key,
      getCellStats(
        subjectId,
        trackerId,
      ).copyWith(timerRunning: false, clearTimerStart: true),
    );
    notifyListeners();
    return event;
  }

  /// Stop all running timers (e.g. when leaving tracking mode or resetting).
  void stopAllTimers({required Duration timestamp}) {
    final keys = _activeTimers.keys.toList();
    for (final key in keys) {
      stopTimer(
        subjectId: key.subjectId,
        trackerId: key.trackerId,
        timestamp: timestamp,
      );
    }
  }

  // -----------------------------------------------------------------------
  // Derived stats (computed from the event stream)
  // -----------------------------------------------------------------------

  /// Sum of counter increments minus decrements for a given subject+tracker.
  int getCounterValue(String subjectId, String trackerId) {
    return getCellStats(subjectId, trackerId).counterValue;
  }

  /// Total accumulated timer duration for a given subject+tracker,
  /// computed from start/stop event pairs.
  Duration getTimerDuration(String subjectId, String trackerId) {
    return getCellStats(subjectId, trackerId).timerDuration;
  }

  /// Returns individual timer intervals as a list of (start, stop) pairs.
  List<({Duration start, Duration stop})> getTimerIntervals(
    String subjectId,
    String trackerId,
  ) {
    final intervals = <({Duration start, Duration stop})>[];
    Duration? lastStart;

    for (final event in _session.events) {
      if (event.subjectId != subjectId || event.trackerId != trackerId) {
        continue;
      }
      switch (event.action) {
        case TrackingAction.timerStart:
          lastStart = event.timestamp;
          break;
        case TrackingAction.timerStop:
          if (lastStart != null && event.timestamp >= lastStart) {
            intervals.add((start: lastStart, stop: event.timestamp));
          }
          lastStart = null;
          break;
        case TrackingAction.timerCancel:
          lastStart = null;
          break;
        default:
          break;
      }
    }
    return intervals;
  }

  /// All events for a specific subject, ordered by timestamp.
  List<TrackingEvent> getEventsForSubject(String subjectId) {
    return _session.events.where((e) => e.subjectId == subjectId).toList();
  }

  /// All events for a specific tracker across all subjects.
  List<TrackingEvent> getEventsForTracker(String trackerId) {
    return _session.events.where((e) => e.trackerId == trackerId).toList();
  }

  // -----------------------------------------------------------------------
  // Event editing
  // -----------------------------------------------------------------------

  /// Remove the last event (undo).
  TrackingEvent? undoLastEvent() {
    if (_session.events.isEmpty) return null;
    final removed = _session.events.last;
    _session = _session.copyWith(
      events: _session.events.sublist(0, _session.events.length - 1),
    );

    // If it was a timer start, also remove the active timer state
    if (removed.action == TrackingAction.timerStart) {
      final key = (subjectId: removed.subjectId, trackerId: removed.trackerId);
      _activeTimers.remove(key);
    }
    // If it was a timer stop, re-open the timer from the matching start
    if (removed.action == TrackingAction.timerStop) {
      // Find the last unmatched start
      for (int i = _session.events.length - 1; i >= 0; i--) {
        final e = _session.events[i];
        if (e.subjectId == removed.subjectId &&
            e.trackerId == removed.trackerId &&
            e.action == TrackingAction.timerStart) {
          final key = (
            subjectId: removed.subjectId,
            trackerId: removed.trackerId,
          );
          _activeTimers[key] = _ActiveTimer(startTimestamp: e.timestamp);
          break;
        }
      }
    }

    _rebuildIndexes(preserveActiveTimers: true);
    notifyListeners();
    return removed;
  }

  /// Delete a specific event by id.
  void deleteEvent(String eventId) {
    final before = _session.events.length;
    _session = _session.copyWith(
      events: _session.events.where((e) => e.id != eventId).toList(),
    );
    if (_session.events.length == before) return;
    _rebuildIndexes(preserveActiveTimers: true);
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Hotkey management
  // -----------------------------------------------------------------------

  Map<String, String> get hotkeys => _session.hotkeys;

  /// Get the hotkey for a subject+tracker pair.
  String? getHotkey(String subjectId, String trackerId) {
    return _session.hotkeys['$subjectId:$trackerId'];
  }

  String? hotkeyError(String subjectId, String trackerId, String key) {
    final error = trackingHotkeyError(key);
    if (error != null) return error;
    final normalized = key.toLowerCase();
    final target = '$subjectId:$trackerId';
    if (_session.hotkeys.entries.any(
      (entry) => entry.key != target && entry.value.toLowerCase() == normalized,
    )) {
      return 'This key is already assigned to another tracker.';
    }
    return null;
  }

  /// Invalid assignments leave both the current and other bindings intact.
  bool setHotkey(String subjectId, String trackerId, String key) {
    if (hotkeyError(subjectId, trackerId, key) != null) return false;
    _session = _session.copyWith(
      hotkeys: {
        ..._session.hotkeys,
        '$subjectId:$trackerId': key.toLowerCase(),
      },
    );
    notifyListeners();
    return true;
  }

  /// Remove a hotkey binding.
  void removeHotkey(String subjectId, String trackerId) {
    _session = _session.copyWith(
      hotkeys: {..._session.hotkeys}..remove('$subjectId:$trackerId'),
    );
    notifyListeners();
  }

  /// Find the subject+tracker pair bound to a given key label.
  ({String subjectId, String trackerId})? findByHotkey(String key) {
    // Older saved sessions may contain playback keys or unsupported bindings.
    if (trackingHotkeyError(key) != null) return null;
    for (final entry in _session.hotkeys.entries) {
      if (entry.value.toLowerCase() == key.toLowerCase()) {
        final parts = entry.key.split(':');
        if (parts.length == 2 && subjects.any((s) => s.id == parts[0])) {
          return (subjectId: parts[0], trackerId: parts[1]);
        }
      }
    }
    return null;
  }

  /// Process a hotkey press. Returns true if handled.
  bool handleHotkeyDown(String key, Duration videoTimestamp) {
    final binding = findByHotkey(key);
    if (binding == null) return false;

    final tracker = trackersForSubject(
      binding.subjectId,
    ).where((t) => t.id == binding.trackerId).firstOrNull;
    if (tracker == null) return false;

    _lastFeedback = binding;

    if (tracker.kind == TrackerKind.counter) {
      incrementCounter(
        subjectId: binding.subjectId,
        trackerId: binding.trackerId,
        timestamp: videoTimestamp,
      );
    } else if (tracker.kind == TrackerKind.timer) {
      if (tracker.timerMode == TimerMode.hold) {
        startTimer(
          subjectId: binding.subjectId,
          trackerId: binding.trackerId,
          timestamp: videoTimestamp,
        );
      } else {
        toggleTimer(
          subjectId: binding.subjectId,
          trackerId: binding.trackerId,
          timestamp: videoTimestamp,
        );
      }
    }
    return true;
  }

  /// Process a hotkey release. Only relevant for hold-mode timers.
  bool handleHotkeyUp(String key, Duration videoTimestamp) {
    final binding = findByHotkey(key);
    if (binding == null) return false;

    final tracker = trackersForSubject(
      binding.subjectId,
    ).where((t) => t.id == binding.trackerId).firstOrNull;
    if (tracker == null) return false;

    if (tracker.kind == TrackerKind.timer &&
        tracker.timerMode == TimerMode.hold) {
      stopTimer(
        subjectId: binding.subjectId,
        trackerId: binding.trackerId,
        timestamp: videoTimestamp,
      );
      return true;
    }
    return false;
  }

  // -----------------------------------------------------------------------
  // Inline add with same trackers
  // -----------------------------------------------------------------------

  /// Add a new subject and automatically assign the same trackers that
  /// [templateSubjectId] has (copies tracker list, not events).
  void addSubjectWithSameTrackers(
    TrackingSubject subject,
    String? templateSubjectId,
  ) {
    addSubject(subject);
    // Trackers are shared across all subjects (session-level), so nothing
    // extra to copy. The UI shows all session trackers for each subject.
    notifyListeners();
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  TrackingEvent _createEvent({
    required String subjectId,
    required String trackerId,
    required Duration timestamp,
    required TrackingAction action,
    int delta = 0,
  }) {
    return TrackingEvent(
      id: 'te_${_nextEventId++}',
      timestamp: timestamp,
      subjectId: subjectId,
      trackerId: trackerId,
      action: action,
      delta: delta,
    );
  }

  void _updateCounter(String subjectId, String trackerId, int change) {
    final key = (subjectId: subjectId, trackerId: trackerId);
    final previous = _cellStats[key] ?? const TrackingCellStats();
    _setCellStats(
      key,
      previous.copyWith(counterValue: previous.counterValue + change),
    );
  }

  void _setCellStats(_TimerKey key, TrackingCellStats value) {
    _cellStats[key] = value;
    final notifier = _cellNotifiers[key];
    if (notifier != null && notifier.value != value) notifier.value = value;
  }

  void _rebuildIndexes({bool preserveActiveTimers = false}) {
    final preserved = preserveActiveTimers
        ? Map<_TimerKey, _ActiveTimer>.from(_activeTimers)
        : <_TimerKey, _ActiveTimer>{};
    _cellStats.clear();
    final unmatchedStarts = <_TimerKey, Duration>{};
    var highestSuffix = 0;
    for (final event in _session.events) {
      final suffix = RegExp(r'^(?:te_)?(\d+)$').firstMatch(event.id);
      if (suffix != null) {
        final parsed = int.parse(suffix.group(1)!);
        if (parsed > highestSuffix) highestSuffix = parsed;
      }
      final key = (subjectId: event.subjectId, trackerId: event.trackerId);
      final previous = _cellStats[key] ?? const TrackingCellStats();
      switch (event.action) {
        case TrackingAction.increment:
          _cellStats[key] = previous.copyWith(
            counterValue: previous.counterValue + event.delta,
          );
          break;
        case TrackingAction.decrement:
          _cellStats[key] = previous.copyWith(
            counterValue: previous.counterValue - event.delta,
          );
          break;
        case TrackingAction.timerStart:
          unmatchedStarts[key] = event.timestamp;
          break;
        case TrackingAction.timerStop:
          final start = unmatchedStarts.remove(key);
          if (start != null && event.timestamp >= start) {
            _cellStats[key] = previous.copyWith(
              timerDuration: previous.timerDuration + (event.timestamp - start),
            );
          }
          break;
        case TrackingAction.timerCancel:
          unmatchedStarts.remove(key);
          break;
      }
    }
    _nextEventId = highestSuffix + 1;
    if (!preserveActiveTimers) _activeTimers.clear();
    _activeTimers.addAll(preserved);
    for (final entry in _activeTimers.entries) {
      final previous = _cellStats[entry.key] ?? const TrackingCellStats();
      _cellStats[entry.key] = previous.copyWith(
        timerRunning: true,
        timerStartedAt: entry.value.startTimestamp,
      );
    }
    _syncAllCellNotifiers();
  }

  void _syncAllCellNotifiers() {
    for (final entry in _cellNotifiers.entries) {
      entry.value.value = _cellStats[entry.key] ?? const TrackingCellStats();
    }
  }

  @override
  void dispose() {
    for (final notifier in _cellNotifiers.values) {
      notifier.dispose();
    }
    _cellNotifiers.clear();
    super.dispose();
  }
}
