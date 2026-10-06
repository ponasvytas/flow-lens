import 'package:flutter/foundation.dart';
import 'tracking_models.dart';

/// A portable configuration. Definitions are snapshots; observations never travel here.
@immutable
class TrackingTemplate {
  final String id;
  final int revision;
  final String sportId;
  final String name;
  final String description;
  final TrackingSubjectKind subjectKind;
  final List<TrackingDefinition> trackers;
  final String? sourceTemplateId;

  TrackingTemplate({
    required this.id,
    this.revision = 1,
    required this.sportId,
    required this.name,
    this.description = '',
    this.subjectKind = TrackingSubjectKind.player,
    required Iterable<TrackingDefinition> trackers,
    this.sourceTemplateId,
  }) : trackers = List.unmodifiable(trackers) {
    validate();
  }

  void validate() {
    if (id.isEmpty ||
        sportId.isEmpty ||
        name.trim().isEmpty ||
        name.length > 120 ||
        revision < 1) {
      throw const FormatException(
        'A template needs a name, sport and valid revision.',
      );
    }
    if (trackers.isEmpty ||
        trackers.length > 200 ||
        trackers.map((t) => t.id).toSet().length != trackers.length) {
      throw const FormatException('Choose 1–200 distinct trackers.');
    }
    for (final tracker in trackers) {
      if (tracker.id.isEmpty ||
          tracker.label.trim().isEmpty ||
          tracker.sportId != sportId ||
          (tracker.kind == TrackerKind.counter && tracker.timerMode != null)) {
        throw FormatException('Invalid tracker in template: ${tracker.label}');
      }
    }
  }

  TrackingTemplate copyWith({
    String? id,
    int? revision,
    String? name,
    Iterable<TrackingDefinition>? trackers,
    String? sourceTemplateId,
  }) => TrackingTemplate(
    id: id ?? this.id,
    revision: revision ?? this.revision,
    sportId: sportId,
    name: name ?? this.name,
    description: description,
    subjectKind: subjectKind,
    trackers: trackers ?? this.trackers,
    sourceTemplateId: sourceTemplateId ?? this.sourceTemplateId,
  );

  Map<String, dynamic> toJson() => {
    'documentType': 'trackingTemplate',
    'schemaVersion': 1,
    'id': id,
    'revision': revision,
    'sportId': sportId,
    'name': name,
    'description': description,
    'subjectKind': subjectKind.name,
    'trackers': trackers.map((t) => t.toJson()).toList(),
    if (sourceTemplateId != null) 'sourceTemplateId': sourceTemplateId,
  };

  factory TrackingTemplate.fromJson(Map<String, dynamic> json) {
    if (json['documentType'] != 'trackingTemplate' ||
        json['schemaVersion'] != 1) {
      throw const FormatException(
        'Choose a supported tracking template file, not a session.',
      );
    }
    if (json.keys.any(
      (key) => !{
        'documentType',
        'schemaVersion',
        'id',
        'revision',
        'sportId',
        'name',
        'description',
        'subjectKind',
        'trackers',
        'sourceTemplateId',
      }.contains(key),
    )) {
      throw const FormatException(
        'This template contains unsupported configuration.',
      );
    }
    final kind = TrackingSubjectKind.values
        .where((k) => k.name == json['subjectKind'])
        .firstOrNull;
    if (kind == null) {
      throw const FormatException('Unsupported template subject role.');
    }
    return TrackingTemplate(
      id: json['id'] as String,
      revision: json['revision'] as int,
      sportId: json['sportId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      subjectKind: kind,
      trackers: (json['trackers'] as List).map(
        (t) => TrackingDefinition.fromJson(Map<String, dynamic>.from(t as Map)),
      ),
      sourceTemplateId: json['sourceTemplateId'] as String?,
    );
  }
}

/// Bundled templates reference definitions in their containing sport taxonomy.
@immutable
class SportTrackingTemplate {
  final String id;
  final String name;
  final String description;
  final int revision;
  final TrackingSubjectKind subjectKind;
  final List<String> trackerIds;

  SportTrackingTemplate({
    required this.id,
    required this.name,
    required this.description,
    this.revision = 1,
    required this.subjectKind,
    required Iterable<String> trackerIds,
  }) : trackerIds = List.unmodifiable(trackerIds);

  factory SportTrackingTemplate.fromJson(Map<String, dynamic> json) =>
      SportTrackingTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        revision: json['revision'] as int? ?? 1,
        subjectKind: TrackingSubjectKind.values.byName(
          json['subjectKind'] as String,
        ),
        trackerIds: (json['trackerIds'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'revision': revision,
    'subjectKind': subjectKind.name,
    'trackerIds': trackerIds,
  };

  TrackingTemplate resolve(
    String sportId,
    List<TrackingDefinition> definitions,
  ) {
    final byId = {
      for (final definition in definitions) definition.id: definition,
    };
    return TrackingTemplate(
      id: id,
      revision: revision,
      sportId: sportId,
      name: name,
      description: description,
      subjectKind: subjectKind,
      trackers: trackerIds.map(
        (id) =>
            byId[id] ??
            (throw FormatException('Unknown template tracker: $id')),
      ),
    );
  }
}
