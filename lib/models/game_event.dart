import 'dart:typed_data';
import 'package:flutter/material.dart';

enum EventGrade {
  positive, // Good (Green)
  negative, // Bad (Red)
  neutral, // Neutral (Grey/White)
}

class GameEvent {
  final String id;
  final String? taxonomyRevision;
  final String? definition;
  final Map<String, String> context;
  final Duration timestamp;
  final EventGrade? grade;
  final String label; // e.g., "Breakout", "Wrist Shot", "Goal"
  final String? detail; // Optional context e.g., "Intercepted", "Wide"

  final String sportId;
  final String categoryId;
  final String? eventTypeId;
  final Matrix4? viewTransform;

  GameEvent({
    required this.id,
    this.taxonomyRevision,
    this.definition,
    Map<String, String> context = const {},
    required this.timestamp,
    this.grade,
    required this.label,
    this.detail,
    this.sportId = 'hockey',
    required this.categoryId,
    this.eventTypeId,
    this.viewTransform,
  }) : context = Map.unmodifiable(context);

  bool get isComplete =>
      eventTypeId?.isNotEmpty == true || detail?.trim().isNotEmpty == true;

  // Helper to determine color based on grade
  Color get color => switch (grade) {
    EventGrade.positive => Colors.green,
    EventGrade.negative => Colors.red,
    EventGrade.neutral => Colors.grey,
    null => Colors.white,
  };

  // CopyWith for immutability updates
  GameEvent copyWith({
    String? id,
    String? taxonomyRevision,
    String? definition,
    Map<String, String>? context,
    bool clearGrade = false,
    Duration? timestamp,
    EventGrade? grade,
    String? label,
    String? detail,
    String? sportId,
    String? categoryId,
    String? eventTypeId,
    Matrix4? viewTransform,
  }) {
    return GameEvent(
      id: id ?? this.id,
      taxonomyRevision: taxonomyRevision ?? this.taxonomyRevision,
      definition: definition ?? this.definition,
      context: context ?? this.context,
      timestamp: timestamp ?? this.timestamp,
      grade: clearGrade ? null : grade ?? this.grade,
      label: label ?? this.label,
      detail: detail ?? this.detail,
      sportId: sportId ?? this.sportId,
      categoryId: categoryId ?? this.categoryId,
      eventTypeId: eventTypeId ?? this.eventTypeId,
      viewTransform: viewTransform ?? this.viewTransform,
    );
  }

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (taxonomyRevision != null) 'taxonomyRevision': taxonomyRevision,
      if (definition != null) 'definition': definition,
      if (context.isNotEmpty) 'context': context,
      'timestamp': timestamp.inMilliseconds,
      'grade': grade?.name,
      'label': label,
      'detail': detail,
      'sportId': sportId,
      'categoryId': categoryId,
      if (eventTypeId != null) 'eventTypeId': eventTypeId,
      if (viewTransform != null)
        'viewTransform': viewTransform!.storage.toList(),
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      taxonomyRevision: json['taxonomyRevision'] as String?,
      definition: json['definition'] as String?,
      context: Map<String, String>.from(json['context'] as Map? ?? {}),
      timestamp: Duration(milliseconds: json['timestamp'] as int),
      grade: json['grade'] != null
          ? EventGrade.values.firstWhere(
              (e) => e.name == json['grade'],
              orElse: () => EventGrade.neutral,
            )
          : null,
      label: json['label'] as String,
      detail: json['detail'] as String?,
      sportId: json['sportId'] as String? ?? 'hockey',
      categoryId: json['categoryId'] as String,
      eventTypeId: json['eventTypeId'] as String?,
      viewTransform: json['viewTransform'] != null
          ? Matrix4.fromFloat64List(
              Float64List.fromList(
                (json['viewTransform'] as List)
                    .map((e) => (e as num).toDouble())
                    .toList(),
              ),
            )
          : null,
    );
  }
}
