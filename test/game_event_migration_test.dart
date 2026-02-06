import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_analyzer/models/game_event.dart';

void main() {
  group('GameEvent Migration', () {
    test('loads old JSON format without stable IDs', () {
      final oldJson = {
        'id': '123',
        'timestamp': 60000,
        'categoryId': 'shot',
        'grade': 'positive',
        'label': 'Goal',
        'detail': 'Top Shelf',
      };

      final event = GameEvent.fromJson(oldJson);

      expect(event.id, '123');
      expect(event.timestamp.inMilliseconds, 60000);
      expect(event.categoryId, 'shot');
      expect(event.grade, EventGrade.positive);
      expect(event.label, 'Goal');
      expect(event.detail, 'Top Shelf');
      expect(event.sportId, 'hockey');
      expect(event.eventTypeId, isNull);
    });

    test('loads new JSON format with stable IDs', () {
      final newJson = {
        'id': '456',
        'timestamp': 120000,
        'grade': 'negative',
        'label': 'Pass',
        'detail': 'Turnover',
        'sportId': 'hockey',
        'categoryId': 'pass',
        'eventTypeId': 'pass_turnover',
      };

      final event = GameEvent.fromJson(newJson);

      expect(event.id, '456');
      expect(event.sportId, 'hockey');
      expect(event.categoryId, 'pass');
      expect(event.eventTypeId, 'pass_turnover');
    });

    test('saves with stable IDs included', () {
      final event = GameEvent(
        id: '789',
        timestamp: const Duration(seconds: 30),
        grade: EventGrade.positive,
        label: 'Battle',
        detail: 'Won',
        sportId: 'hockey',
        categoryId: 'battle',
        eventTypeId: 'battle_won',
      );

      final json = event.toJson();

      expect(json['sportId'], 'hockey');
      expect(json['categoryId'], 'battle');
      expect(json['eventTypeId'], 'battle_won');
    });

    test('categoryId is required', () {
      final event = GameEvent(
        id: '999',
        timestamp: const Duration(seconds: 10),
        categoryId: 'defense',
        grade: EventGrade.neutral,
        label: 'Defense',
      );

      expect(event.categoryId, 'defense');
    });

    test('copyWith preserves stable IDs', () {
      final original = GameEvent(
        id: '111',
        timestamp: const Duration(seconds: 5),
        grade: EventGrade.neutral,
        label: 'Breakout',
        sportId: 'hockey',
        categoryId: 'teamPlay',
        eventTypeId: 'teamplay_breakout',
      );

      final updated = original.copyWith(grade: EventGrade.positive);

      expect(updated.sportId, 'hockey');
      expect(updated.categoryId, 'teamPlay');
      expect(updated.eventTypeId, 'teamplay_breakout');
      expect(updated.grade, EventGrade.positive);
    });
  });
}
