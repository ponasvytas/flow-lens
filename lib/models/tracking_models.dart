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
enum TrackingAction { increment, decrement, timerStart, timerStop, timerCancel }

enum TrackingSubjectKind { player, team, goalie }

// ---------------------------------------------------------------------------
// TrackingSubject — the entity being tracked (player, team, etc.)
// ---------------------------------------------------------------------------

class TrackingSubject {
  final String id;
  final String label;
  final String? number;
  final String? teamId;
  final int colorValue;
  final TrackingSubjectKind kind;

  const TrackingSubject({
    required this.id,
    required this.label,
    this.number,
    this.teamId,
    this.colorValue = 0xFF2196F3,
    this.kind = TrackingSubjectKind.player,
  });

  TrackingSubject copyWith({
    String? id,
    String? label,
    String? number,
    String? teamId,
    int? colorValue,
    TrackingSubjectKind? kind,
  }) {
    return TrackingSubject(
      id: id ?? this.id,
      label: label ?? this.label,
      number: number ?? this.number,
      teamId: teamId ?? this.teamId,
      colorValue: colorValue ?? this.colorValue,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      if (number != null) 'number': number,
      if (teamId != null) 'teamId': teamId,
      'colorValue': colorValue,
      'kind': kind.name,
    };
  }

  factory TrackingSubject.fromJson(Map<String, dynamic> json) {
    return TrackingSubject(
      id: json['id'] as String,
      label: json['label'] as String,
      number: json['number'] as String?,
      teamId: json['teamId'] as String?,
      colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
      kind: TrackingSubjectKind.values.byName(
        json['kind'] as String? ?? 'player',
      ),
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
          other.colorValue == colorValue &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(id, label, number, teamId, colorValue, kind);

  @override
  String toString() =>
      'TrackingSubject($label${number != null ? ' #$number' : ''})';
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
  final String? eventTypeId;
  final String? definition;
  final String? taxonomyRevision;

  const TrackingDefinition({
    required this.id,
    required this.label,
    required this.kind,
    this.timerMode,
    this.sportId = 'hockey',
    this.categoryId,
    this.isBuiltIn = false,
    this.eventTypeId,
    this.definition,
    this.taxonomyRevision,
  });

  TrackingDefinition copyWith({
    String? id,
    String? label,
    TrackerKind? kind,
    TimerMode? timerMode,
    String? sportId,
    String? categoryId,
    bool? isBuiltIn,
    String? eventTypeId,
    String? definition,
    String? taxonomyRevision,
  }) {
    return TrackingDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      timerMode: timerMode ?? this.timerMode,
      sportId: sportId ?? this.sportId,
      categoryId: categoryId ?? this.categoryId,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      definition: definition ?? this.definition,
      taxonomyRevision: taxonomyRevision ?? this.taxonomyRevision,
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
      if (eventTypeId != null) 'eventTypeId': eventTypeId,
      if (definition != null) 'definition': definition,
      if (taxonomyRevision != null) 'taxonomyRevision': taxonomyRevision,
    };
  }

  factory TrackingDefinition.fromJson(Map<String, dynamic> json) {
    return TrackingDefinition(
      id: json['id'] as String,
      label: json['label'] as String,
      kind: _parseTrackerKind(json['kind']),
      timerMode: json['timerMode'] != null
          ? _parseTimerMode(json['timerMode'])
          : null,
      sportId: json['sportId'] as String? ?? 'hockey',
      categoryId: json['categoryId'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      eventTypeId: json['eventTypeId'] as String?,
      definition: json['definition'] as String?,
      taxonomyRevision: json['taxonomyRevision'] as String?,
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
          other.isBuiltIn == isBuiltIn &&
          other.eventTypeId == eventTypeId &&
          other.definition == definition &&
          other.taxonomyRevision == taxonomyRevision;

  @override
  int get hashCode => Object.hash(
    id,
    label,
    kind,
    timerMode,
    sportId,
    categoryId,
    isBuiltIn,
    eventTypeId,
    definition,
    taxonomyRevision,
  );

  @override
  String toString() => 'TrackingDefinition($label, $kind)';
}

TrackerKind _parseTrackerKind(Object? value) => switch (value) {
  'counter' => TrackerKind.counter,
  'timer' => TrackerKind.timer,
  _ => throw FormatException('Unsupported tracker kind: $value'),
};

TimerMode _parseTimerMode(Object? value) => switch (value) {
  'hold' => TimerMode.hold,
  'toggle' => TimerMode.toggle,
  _ => throw FormatException('Unsupported timer mode: $value'),
};

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
  final String? videoIdentity;
  final String? sportId;
  final String? taxonomyRevision;
  final DateTime createdAt;
  final List<TrackingSubject> subjects;
  final List<TrackingDefinition> trackers;
  final List<TrackingEvent> events;
  final List<String> visibleTrackerIds;
  final Set<String> hiddenSubjectIds;
  final Map<String, List<String>> trackerSubjects;
  final String? templateId;
  final int? templateRevision;

  /// Hotkey bindings: key = "subjectId:trackerId", value = keyboard key label.
  final Map<String, String> hotkeys;

  TrackingSession({
    required this.id,
    this.videoSource,
    this.videoIdentity,
    String? sportId,
    this.taxonomyRevision,
    DateTime? createdAt,
    List<TrackingSubject>? subjects,
    List<TrackingDefinition>? trackers,
    List<TrackingEvent>? events,
    Map<String, String>? hotkeys,
    List<String>? visibleTrackerIds,
    Set<String>? hiddenSubjectIds,
    Map<String, List<String>> trackerSubjects = const {},
    this.templateId,
    this.templateRevision,
  }) : createdAt = createdAt ?? DateTime.now(),
       sportId = sportId ?? _inferSport(trackers ?? []),
       subjects = List.unmodifiable(subjects ?? []),
       trackers = List.unmodifiable(trackers ?? []),
       events = List.unmodifiable(events ?? []),
       hotkeys = Map.unmodifiable(hotkeys ?? {}),
       visibleTrackerIds = List.unmodifiable(
         visibleTrackerIds ?? trackers?.map((t) => t.id) ?? [],
       ),
       hiddenSubjectIds = Set.unmodifiable(hiddenSubjectIds ?? {}),
       trackerSubjects = Map.unmodifiable(
         trackerSubjects.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       );

  static String? _inferSport(List<TrackingDefinition> trackers) {
    final sports = trackers.map((t) => t.sportId).toSet();
    return sports.length == 1 ? sports.single : null;
  }

  bool get hasConsistentSport =>
      sportId != null &&
      trackers.every((tracker) => tracker.sportId == sportId);

  TrackingSession copyWith({
    String? sportId,
    String? videoIdentity,
    String? taxonomyRevision,
    List<TrackingSubject>? subjects,
    List<TrackingDefinition>? trackers,
    List<TrackingEvent>? events,
    Map<String, String>? hotkeys,
    List<String>? visibleTrackerIds,
    Set<String>? hiddenSubjectIds,
    Map<String, List<String>>? trackerSubjects,
    String? templateId,
    int? templateRevision,
    bool clearTemplate = false,
  }) => TrackingSession(
    id: id,
    videoSource: videoSource,
    videoIdentity: videoIdentity ?? this.videoIdentity,
    sportId: sportId ?? this.sportId,
    taxonomyRevision: taxonomyRevision ?? this.taxonomyRevision,
    createdAt: createdAt,
    subjects: subjects ?? this.subjects,
    trackers: trackers ?? this.trackers,
    events: events ?? this.events,
    hotkeys: hotkeys ?? this.hotkeys,
    visibleTrackerIds: visibleTrackerIds ?? this.visibleTrackerIds,
    hiddenSubjectIds: hiddenSubjectIds ?? this.hiddenSubjectIds,
    trackerSubjects: trackerSubjects ?? this.trackerSubjects,
    templateId: clearTemplate ? null : templateId ?? this.templateId,
    templateRevision: clearTemplate
        ? null
        : templateRevision ?? this.templateRevision,
  );

  Map<String, dynamic> toJson() {
    return {
      'documentType': 'trackingSession',
      'schemaVersion': 2,
      'id': id,
      if (videoSource != null) 'videoSource': videoSource,
      if (videoIdentity != null) 'videoIdentity': videoIdentity,
      if (sportId != null) 'sportId': sportId,
      if (taxonomyRevision != null) 'taxonomyRevision': taxonomyRevision,
      'createdAt': createdAt.toIso8601String(),
      'subjects': subjects.map((s) => s.toJson()).toList(),
      'trackers': trackers.map((t) => t.toJson()).toList(),
      'events': events.map((e) => e.toJson()).toList(),
      if (hotkeys.isNotEmpty) 'hotkeys': hotkeys,
      'visibleTrackerIds': visibleTrackerIds,
      'hiddenSubjectIds': hiddenSubjectIds.toList(),
      'trackerSubjects': trackerSubjects,
      if (templateId != null) 'templateId': templateId,
      if (templateRevision != null) 'templateRevision': templateRevision,
    };
  }

  factory TrackingSession.fromJson(Map<String, dynamic> json) {
    if ((json['documentType'] != null &&
            json['documentType'] != 'trackingSession') ||
        ![1, 2].contains(json['schemaVersion'] ?? 1)) {
      throw const FormatException('Unsupported tracking session file.');
    }
    return TrackingSession(
      id: json['id'] as String,
      videoSource: json['videoSource'] as String?,
      videoIdentity: json['videoIdentity'] as String?,
      sportId: json['sportId'] as String?,
      taxonomyRevision: json['taxonomyRevision'] as String?,
      visibleTrackerIds: (json['visibleTrackerIds'] as List?)?.cast<String>(),
      hiddenSubjectIds: (json['hiddenSubjectIds'] as List?)
          ?.cast<String>()
          .toSet(),
      trackerSubjects: (json['trackerSubjects'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(key, List<String>.from(value as List))),
      templateId: json['templateId'] as String?,
      templateRevision: json['templateRevision'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      subjects:
          (json['subjects'] as List<dynamic>?)
              ?.map((s) => TrackingSubject.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      trackers:
          (json['trackers'] as List<dynamic>?)
              ?.map(
                (t) => TrackingDefinition.fromJson(t as Map<String, dynamic>),
              )
              .toList() ??
          [],
      events:
          (json['events'] as List<dynamic>?)
              ?.map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hotkeys:
          (json['hotkeys'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {},
    );
  }

  @override
  String toString() =>
      'TrackingSession($id, ${subjects.length} subjects, ${trackers.length} trackers, ${events.length} events)';
}
