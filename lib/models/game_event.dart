import 'package:flutter/material.dart';

enum EventGrade {
  positive, // Good (Green)
  negative, // Bad (Red)
  neutral, // Neutral (Grey/White)
}

class GameEvent {
  final String id;
  final Duration timestamp;
  final EventGrade? grade;
  final String label; // e.g., "Breakout", "Wrist Shot", "Goal"
  final String? detail; // Optional context e.g., "Intercepted", "Wide"
  
  final String sportId;
  final String categoryId;
  final String? eventTypeId;

  GameEvent({
    required this.id,
    required this.timestamp,
    this.grade,
    required this.label,
    this.detail,
    this.sportId = 'hockey',
    required this.categoryId,
    this.eventTypeId,
  });

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
    Duration? timestamp,
    EventGrade? grade,
    String? label,
    String? detail,
    String? sportId,
    String? categoryId,
    String? eventTypeId,
  }) {
    return GameEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      grade: grade ?? this.grade,
      label: label ?? this.label,
      detail: detail ?? this.detail,
      sportId: sportId ?? this.sportId,
      categoryId: categoryId ?? this.categoryId,
      eventTypeId: eventTypeId ?? this.eventTypeId,
    );
  }

  // JSON Serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.inMilliseconds,
      'grade': grade?.name,
      'label': label,
      'detail': detail,
      'sportId': sportId,
      'categoryId': categoryId,
      if (eventTypeId != null) 'eventTypeId': eventTypeId,
    };
  }

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
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
    );
  }
}
