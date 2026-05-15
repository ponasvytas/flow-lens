import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// The kind of tracker.
enum TrackerKind {
  /// Discrete increment/decrement counter.
  counter,

  /// Duration-based timer.
  timer,
}

/// How a timer tracker is activated.
enum TimerMode {
  /// Click/hotkey once to start, again to stop.
  toggle,

  /// Runs while button/key is held, stops on release.
  hold,
}

/// Atomic actions stored in the event stream.
enum TrackingAction {
  increment,
  decrement,
  timerStart,
  timerStop,
  timerCancel,
}

// ---------------------------------------------------------------------------
// TrackingSubject — the entity being tracked (player, team, etc.)
// ---------------------------------------------------------------------------

class TrackingSubject {
  final String id;
  final String label;
  final String? number;
  final String? teamId;
  final int colorValue;

  const TrackingSubject({
    required this.id,
    required this.label,
    this.number,
    this.teamId,
    this.colorValue = 0xFF2196F3,
  });

  TrackingSubject copyWith({
    String? id,
    String? label,
    String? number,
    String? teamId,
    int? colorValue,
  }) {
    return TrackingSubject(
      id: id ?? this.id,
      label: label ?? this.label,
      number: number ?? this.number,
      teamId: teamId ?? this.teamId,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      if (number != null) 'number': number,
      if (teamId != null) 'teamId': teamId,
      'colorValue': colorValue,
    };
  }

  factory TrackingSubject.fromJson(Map<String, dynamic> json) {
    return TrackingSubject(
      id: json['id'] as String,
      label: json['label'] as String,
      number: json['number'] as String?,
      teamId: json['teamId'] as String?,
      colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingSubject &&
          other.id == id &&
          other.label == label &&
          other.number == number &&
          other.teamId == teamId &&
          other.colorValue == colorValue;

  @override
  int get hashCode => Object.hash(id, label, number, teamId, colorValue);

  @override
  String toString() => 'TrackingSubject($label${number != null ? ' #$number' : ''})';
}

// ---------------------------------------------------------------------------
// TrackingDefinition — a configured tracker type (e.g. "Passes", "Time with
// puck"). Can be built-in or user-created.
// ---------------------------------------------------------------------------

class TrackingDefinition {
  final String id;
  final String label;
  final TrackerKind kind;
  final TimerMode? timerMode;
  final String sportId;
  final String? categoryId;
  final bool isBuiltIn;

  const TrackingDefinition({
    required this.id,
    required this.label,
    required this.kind,
    this.timerMode,
    this.sportId = 'hockey',
    this.categoryId,
    this.isBuiltIn = false,
  });

  TrackingDefinition copyWith({
    String? id,
    String? label,
    TrackerKind? kind,
    TimerMode? timerMode,
    String? sportId,
    String? categoryId,
    bool? isBuiltIn,
  }) {
    return TrackingDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      timerMode: timerMode ?? this.timerMode,
      sportId: sportId ?? this.sportId,
      categoryId: categoryId ?? this.categoryId,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'kind': kind.name,
      if (timerMode != null) 'timerMode': timerMode!.name,
      'sportId': sportId,
      if (categoryId != null) 'categoryId': categoryId,
      'isBuiltIn': isBuiltIn,
    };
  }

  factory TrackingDefinition.fromJson(Map<String, dynamic> json) {
    return TrackingDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      kind: TrackerKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => TrackerKind.counter,
      ),
      timerMode: json['timerMode'] != null
          ? TimerMode.values.firstWhere(
              (e) => e.name == json['timerMode'],
              orElse: () => TimerMode.toggle,
            )
          : null,
      sportId: json['sportId'] as String? ?? 'hockey',
      categoryId: json['categoryId'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingDefinition &&
          other.id == id &&
          other.label == label &&
          other.kind == kind &&
          other.timerMode == timerMode &&
          other.sportId == sportId &&
          other.categoryId == categoryId &&
          other.isBuiltIn == isBuiltIn;

  @override
  int get hashCode =>
      Object.hash(id, label, kind, timerMode, sportId, categoryId, isBuiltIn);

  @override
  String toString() => 'TrackingDefinition($label, $kind)';
}

// ---------------------------------------------------------------------------
// TrackingEvent — a single timestamped action in the raw event stream.
// ---------------------------------------------------------------------------

class TrackingEvent {
  final String id;

  /// Video position when this event was recorded.
  final Duration timestamp;

  /// The subject (player/team) this event is about.
  final String subjectId;

  /// The tracker definition this event belongs to.
  final String trackerId;

  /// What happened.
  final TrackingAction action;

  /// For counter events: the delta (+1 / -1). Ignored for timer events.
  final int delta;

  /// Optional free-form metadata.
  final Map<String, dynamic>? metadata;

  const TrackingEvent({
    required this.id,
    required this.timestamp,
    required this.subjectId,
    required this.trackerId,
    required this.action,
    this.delta = 0,
    this.metadata,
  });

  TrackingEvent copyWith({
    String? id,
    Duration? timestamp,
    String? subjectId,
    String? trackerId,
    TrackingAction? action,
    int? delta,
    Map<String, dynamic>? metadata,
  }) {
    return TrackingEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      subjectId: subjectId ?? this.subjectId,
      trackerId: trackerId ?? this.trackerId,
      action: action ?? this.action,
      delta: delta ?? this.delta,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.inMilliseconds,
      'subjectId': subjectId,
      'trackerId': trackerId,
      'action': action.name,
      'delta': delta,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory TrackingEvent.fromJson(Map<String, dynamic> json) {
    return TrackingEvent(
      id: json['id'] as String,
      timestamp: Duration(milliseconds: json['timestamp'] as int),
      subjectId: json['subjectId'] as String,
      trackerId: json['trackerId'] as String,
      action: TrackingAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => TrackingAction.increment,
      ),
      delta: json['delta'] as int? ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackingEvent &&
          other.id == id &&
          other.timestamp == timestamp &&
          other.subjectId == subjectId &&
          other.trackerId == trackerId &&
          other.action == action &&
          other.delta == delta &&
          mapEquals(other.metadata, metadata);

  @override
  int get hashCode =>
      Object.hash(id, timestamp, subjectId, trackerId, action, delta);

  @override
  String toString() =>
      'TrackingEvent($action, subject=$subjectId, tracker=$trackerId, @${timestamp.inMilliseconds}ms)';
}

// ---------------------------------------------------------------------------
// TrackingSession — a complete tracking session for a video.
// ---------------------------------------------------------------------------

class TrackingSession {
  final String id;
  final String? videoSource;
  final DateTime createdAt;
  final List<TrackingSubject> subjects;
  final List<TrackingDefinition> trackers;
  final List<TrackingEvent> events;

  /// Hotkey bindings: key = "subjectId:trackerId", value = keyboard key label.
  final Map<String, String> hotkeys;

  TrackingSession({
    required this.id,
    this.videoSource,
    DateTime? createdAt,
    List<TrackingSubject>? subjects,
    List<TrackingDefinition>? trackers,
    List<TrackingEvent>? events,
    Map<String, String>? hotkeys,
  })  : createdAt = createdAt ?? DateTime.now(),
        subjects = subjects ?? [],
        trackers = trackers ?? [],
        events = events ?? [],
        hotkeys = hotkeys ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (videoSource != null) 'videoSource': videoSource,
      'createdAt': createdAt.toIso8601String(),
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'trackers': trackers.map((t) => t.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      if (hotkeys.isNotEmpty) 'hotkeys': hotkeys,
    };
  }

  factory TrackingSession.fromJson(Map<String, dynamic> json) {
    return TrackingSession(
      id: json['id'] as String,
      videoSource: json['videoSource'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      subjects: (json['subjects'] as List<dynamic>?)
              ?.map((s) => TrackingSubject.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      trackers: (json['trackers'] as List<dynamic>?)
              ?.map(
                  (t) => TrackingDefinition.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hotkeys: (json['hotkeys'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as String)) ??
          {},
    );
  }

  @override
  String toString() =>
      'TrackingSession($id, ${subjects.length} subjects, ${trackers.length} trackers, ${events.length} events)';
}
