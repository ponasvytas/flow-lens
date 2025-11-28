import 'package:flutter/material.dart';

enum EventCategory {
  shot, // Offensive chances (Us)
  pass, // Puck movement
  battle, // 1v1, Hits, Board play
  defense, // Defensive plays / Shots Against
  teamPlay, // Macro: Breakouts, Entries, Regroups
  penalty, // Stoppages / Infractions
}

enum EventGrade {
  positive, // Good (Green)
  negative, // Bad (Red)
  neutral, // Neutral (Grey/White)
}

class GameEvent {
  final String id;
  final Duration timestamp;
  final EventCategory category;
  final EventGrade grade;
  final String label; // e.g., "Breakout", "Wrist Shot", "Goal"
  final String? detail; // Optional context e.g., "Intercepted", "Wide"

  GameEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    this.grade = EventGrade.neutral,
    required this.label,
    this.detail,
  });

  // Helper to determine color based on grade
  Color get color => switch (grade) {
    EventGrade.positive => Colors.green,
    EventGrade.negative => Colors.red,
    EventGrade.neutral => Colors.grey,
  };

  // CopyWith for immutability updates
  GameEvent copyWith({
    String? id,
    Duration? timestamp,
    EventCategory? category,
    EventGrade? grade,
    String? label,
    String? detail,
  }) {
    return GameEvent(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      grade: grade ?? this.grade,
      label: label ?? this.label,
      detail: detail ?? this.detail,
    );
  }
}
