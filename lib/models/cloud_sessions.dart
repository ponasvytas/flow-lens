import 'dart:collection';

import 'game_event.dart';
import 'tracking_models.dart';

enum VideoSourceKind { none, localFile, externalUrl }

class VideoSourceMetadata {
  const VideoSourceMetadata({
    required this.kind,
    this.displayName,
    this.externalUrl,
    this.durationMs,
  });

  static const none = VideoSourceMetadata(kind: VideoSourceKind.none);

  factory VideoSourceMetadata.fromSource(String? source, {Duration? duration}) {
    if (source == null || source.isEmpty) {
      return VideoSourceMetadata(
        kind: VideoSourceKind.none,
        durationMs: duration?.inMilliseconds,
      );
    }
    final uri = Uri.tryParse(source);
    final isExternal =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final segments = uri?.pathSegments
        .where((part) => part.isNotEmpty)
        .toList();
    final localName = source.replaceAll('\\', '/').split('/').last;
    final displayName = isExternal
        ? (segments == null || segments.isEmpty ? 'Video' : segments.last)
        : (localName.isEmpty ? 'Video' : localName);
    return VideoSourceMetadata(
      kind: isExternal
          ? VideoSourceKind.externalUrl
          : VideoSourceKind.localFile,
      displayName: displayName,
      externalUrl: isExternal ? source : null,
      durationMs: duration?.inMilliseconds,
    );
  }

  final VideoSourceKind kind;
  final String? displayName;
  final String? externalUrl;
  final int? durationMs;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (displayName != null) 'displayName': displayName,
    if (externalUrl != null) 'externalUrl': externalUrl,
    if (durationMs != null) 'durationMs': durationMs,
  };

  factory VideoSourceMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VideoSourceMetadata.none;
    return VideoSourceMetadata(
      kind: VideoSourceKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => VideoSourceKind.none,
      ),
      displayName: json['displayName'] as String?,
      externalUrl: json['externalUrl'] as String?,
      durationMs: json['durationMs'] as int?,
    );
  }
}

class EventSessionDraft {
  EventSessionDraft({
    required this.title,
    required this.sportId,
    required this.taxonomyId,
    required this.taxonomyRevision,
    required Map<String, dynamic> taxonomySnapshot,
    required Iterable<GameEvent> events,
    this.sourceVideo = VideoSourceMetadata.none,
  }) : taxonomySnapshot = Map.unmodifiable(taxonomySnapshot),
       events = UnmodifiableListView(events.toList());

  final String title;
  final String sportId;
  final String taxonomyId;
  final int taxonomyRevision;
  final Map<String, dynamic> taxonomySnapshot;
  final UnmodifiableListView<GameEvent> events;
  final VideoSourceMetadata sourceVideo;

  Map<String, dynamic> toContentMap() => {
    'schemaVersion': 1,
    'title': title,
    'sportId': sportId,
    'taxonomyId': taxonomyId,
    'taxonomyRevision': taxonomyRevision,
    'taxonomySnapshot': taxonomySnapshot,
    'sourceVideo': sourceVideo.toJson(),
    'events': events.map((event) => event.toJson()).toList(),
  };
}

class CloudEventSession {
  CloudEventSession({
    required this.id,
    required this.schemaVersion,
    required this.title,
    required this.sportId,
    required this.taxonomyId,
    required this.taxonomyRevision,
    required Map<String, dynamic> taxonomySnapshot,
    required Iterable<GameEvent> events,
    required this.sourceVideo,
    required this.ownerType,
    required this.ownerId,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  }) : taxonomySnapshot = Map.unmodifiable(taxonomySnapshot),
       events = UnmodifiableListView(events.toList());

  final String id;
  final int schemaVersion;
  final String title;
  final String sportId;
  final String taxonomyId;
  final int taxonomyRevision;
  final Map<String, dynamic> taxonomySnapshot;
  final UnmodifiableListView<GameEvent> events;
  final VideoSourceMetadata sourceVideo;
  final String ownerType;
  final String ownerId;
  final String createdByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  EventSessionDraft toDraft({String? title}) => EventSessionDraft(
    title: title ?? this.title,
    sportId: sportId,
    taxonomyId: taxonomyId,
    taxonomyRevision: taxonomyRevision,
    taxonomySnapshot: taxonomySnapshot,
    events: events,
    sourceVideo: sourceVideo,
  );

  factory CloudEventSession.fromMap(String id, Map<String, dynamic> map) =>
      CloudEventSession(
        id: id,
        schemaVersion: map['schemaVersion'] as int? ?? 1,
        title: map['title'] as String,
        sportId: map['sportId'] as String,
        taxonomyId: map['taxonomyId'] as String,
        taxonomyRevision: map['taxonomyRevision'] as int? ?? 1,
        taxonomySnapshot: Map<String, dynamic>.from(
          map['taxonomySnapshot'] as Map? ?? const {},
        ),
        events: (map['events'] as List? ?? const []).map(
          (event) =>
              GameEvent.fromJson(Map<String, dynamic>.from(event as Map)),
        ),
        sourceVideo: VideoSourceMetadata.fromJson(
          map['sourceVideo'] == null
              ? null
              : Map<String, dynamic>.from(map['sourceVideo'] as Map),
        ),
        ownerType: map['ownerType'] as String? ?? 'user',
        ownerId: map['ownerId'] as String,
        createdByUserId: map['createdByUserId'] as String,
        updatedByUserId: map['updatedByUserId'] as String,
        createdAt: map['createdAt'] as DateTime,
        updatedAt: map['updatedAt'] as DateTime,
        archivedAt: map['archivedAt'] as DateTime?,
      );
}

class TrackingSessionDraft {
  const TrackingSessionDraft({
    required this.title,
    required this.sportId,
    required this.session,
    this.sourceVideo = VideoSourceMetadata.none,
  });

  final String title;
  final String sportId;
  final TrackingSession session;
  final VideoSourceMetadata sourceVideo;

  Map<String, dynamic> toContentMap() {
    final trackingData = Map<String, dynamic>.from(session.toJson())
      ..remove('videoSource');
    return {
      'schemaVersion': 1,
      'title': title,
      'sportId': sportId,
      'sourceVideo': sourceVideo.toJson(),
      'trackingSession': trackingData,
    };
  }
}

class CloudTrackingSession {
  const CloudTrackingSession({
    required this.id,
    required this.schemaVersion,
    required this.title,
    required this.sportId,
    required this.session,
    required this.sourceVideo,
    required this.ownerType,
    required this.ownerId,
    required this.createdByUserId,
    required this.updatedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final int schemaVersion;
  final String title;
  final String sportId;
  final TrackingSession session;
  final VideoSourceMetadata sourceVideo;
  final String ownerType;
  final String ownerId;
  final String createdByUserId;
  final String updatedByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  TrackingSessionDraft toDraft({String? title}) => TrackingSessionDraft(
    title: title ?? this.title,
    sportId: sportId,
    session: session,
    sourceVideo: sourceVideo,
  );

  factory CloudTrackingSession.fromMap(String id, Map<String, dynamic> map) =>
      CloudTrackingSession(
        id: id,
        schemaVersion: map['schemaVersion'] as int? ?? 1,
        title: map['title'] as String,
        sportId: map['sportId'] as String,
        session: TrackingSession.fromJson(
          Map<String, dynamic>.from(map['trackingSession'] as Map),
        ),
        sourceVideo: VideoSourceMetadata.fromJson(
          map['sourceVideo'] == null
              ? null
              : Map<String, dynamic>.from(map['sourceVideo'] as Map),
        ),
        ownerType: map['ownerType'] as String? ?? 'user',
        ownerId: map['ownerId'] as String,
        createdByUserId: map['createdByUserId'] as String,
        updatedByUserId: map['updatedByUserId'] as String,
        createdAt: map['createdAt'] as DateTime,
        updatedAt: map['updatedAt'] as DateTime,
        archivedAt: map['archivedAt'] as DateTime?,
      );
}
