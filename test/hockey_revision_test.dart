import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/event_entry_controller.dart';
import 'package:flow_lens/controllers/quick_events_controller.dart';
import 'package:flow_lens/models/events_filter.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/quick_event.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/models/tracking_presets.dart';
import 'package:flow_lens/widgets/event_buttons_panel.dart';
import 'package:flow_lens/widgets/event_context_editor.dart';
import 'package:flow_lens/widgets/smart_hud.dart';
import 'quick_events_test.dart' show MemoryQuickRepository;

SportTaxonomy loadTaxonomy(String name) => SportTaxonomy.fromJson(
  jsonDecode(File('assets/sports/$name.json').readAsStringSync())
      as Map<String, dynamic>,
);

void main() {
  final taxonomy = loadTaxonomy('hockey');
  final legacy = loadTaxonomy('hockey_v1');

  test('v2 retains every historical pair and leaves old event data intact', () {
    var count = 0;
    for (final category in legacy.categories) {
      for (final type in category.eventTypes) {
        count++;
        expect(
          taxonomy
              .getCategoryById(category.categoryId)!
              .getEventTypeById(type.eventTypeId),
          isNotNull,
        );
        final event = GameEvent(
          id: '$count',
          timestamp: Duration(seconds: count),
          categoryId: category.categoryId,
          eventTypeId: type.eventTypeId,
          label: category.name,
          detail: type.name,
          grade: type.defaultImpact,
        );
        final restored = GameEvent.fromJson(
          jsonDecode(jsonEncode(event.toJson())),
        );
        expect(restored.toJson(), event.toJson());
        expect(restored.taxonomyRevision, isNull);
      }
    }
    expect(count, 31);
    expect(
      taxonomy.categories.expand((c) => c.captureEventTypes),
      hasLength(55),
    );
    expect(
      taxonomy.categories.expand((c) => c.eventTypes).where((t) => t.archived),
      hasLength(16),
    );
    expect(
      taxonomy.categories
          .expand((c) => c.captureEventTypes)
          .every((t) => t.defaultImpact == null && t.definition.isNotEmpty),
      isTrue,
    );
    expect(
      SportTaxonomy.fromJson(taxonomy.toJson()).toJson(),
      taxonomy.toJson(),
    );
    expect(() => taxonomy.validate(), returnsNormally);
  });

  test(
    'keyboard pages reach every category and type, including future long lists',
    () {
      final entry = EventEntryController()..toggle();
      const keys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
        LogicalKeyboardKey.digit6,
        LogicalKeyboardKey.digit7,
        LogicalKeyboardKey.digit8,
        LogicalKeyboardKey.digit9,
      ];
      const numpad = [
        LogicalKeyboardKey.numpad1,
        LogicalKeyboardKey.numpad2,
        LogicalKeyboardKey.numpad3,
        LogicalKeyboardKey.numpad4,
        LogicalKeyboardKey.numpad5,
        LogicalKeyboardKey.numpad6,
        LogicalKeyboardKey.numpad7,
        LogicalKeyboardKey.numpad8,
        LogicalKeyboardKey.numpad9,
      ];
      for (final count in [
        taxonomy.captureCategories.length,
        ...taxonomy.captureCategories.map((c) => c.captureEventTypes.length),
        28,
      ]) {
        final reached = <int>{};
        for (var page = 0; page <= (count - 1) ~/ 9; page++) {
          entry.setPage(page, count);
          for (var i = 0; i < keys.length; i++) {
            final index = entry.selectionIndex(keys[i], count);
            expect(entry.selectionIndex(numpad[i], count), index);
            if (index != null) reached.add(index);
          }
        }
        expect(reached, Set.of(List.generate(count, (i) => i)));
        entry.setStage(EventEntryStage.labels);
        expect(entry.page, 0);
      }
      entry.setPage(1, 12);
      expect(entry.selectionIndex(LogicalKeyboardKey.digit4, 12), isNull);
      expect(entry.selectionIndex(LogicalKeyboardKey.digit0, 12), isNull);
      entry.setPage(-1, 12);
      expect(entry.page, 0);
      entry.exit();
      expect(entry.stage, EventEntryStage.none);
      expect(entry.showLabelNumbers, isFalse);
      entry.dispose();
    },
  );

  test(
    'ungraded/context filters and serialization preserve explicit selections',
    () {
      final input = {
        'analysisTeam': 'Wolves',
        'side': 'Our team',
        'incident': 'play-8',
      };
      final event = GameEvent(
        id: '1',
        timestamp: Duration.zero,
        label: 'Pass',
        categoryId: 'pass',
        eventTypeId: 'pass_completed',
        context: input,
        taxonomyRevision: taxonomy.revision,
        definition: 'Saved definition',
      );
      input['side'] = 'Opponent';
      final restored = GameEvent.fromJson(
        jsonDecode(jsonEncode(event.toJson())),
      );
      expect(restored.context['side'], 'Our team');
      expect(restored.definition, 'Saved definition');
      expect(restored.isComplete, isTrue);
      expect(restored.grade, isNull);
      final neutral = restored.copyWith(grade: EventGrade.neutral);
      final filter = EventsFilter(
        includeUngraded: true,
        contextValues: {'side': 'Our team'},
      );
      expect(filter.matches(restored), isTrue);
      expect(filter.matches(neutral), isFalse);
      expect(
        filter.matches(restored.copyWith(context: {'side': 'Opponent'})),
        isFalse,
      );
      expect(
        filter.copyWith(impacts: {EventGrade.neutral}).matches(neutral),
        isTrue,
      );
      expect(neutral.copyWith(clearGrade: true).grade, isNull);
      expect(
        filter.copyWith(clearImpacts: true, contextValues: {}).isActive,
        isFalse,
      );
    },
  );

  test(
    'legacy quick keys survive; variants keep snapshot, grade, and context',
    () async {
      final controller = QuickEventsController(MemoryQuickRepository());
      await controller.load();
      controller.selectGame('test', taxonomy);
      final old = QuickEvent.fromJson({
        'categoryId': 'shot',
        'eventTypeId': 'shot_on_net',
        'grade': 'positive',
      });
      expect(old.id, 'shot/shot_on_net');
      expect(
        controller.createEvent(old, taxonomy, Duration.zero)!.detail,
        'On Net',
      );
      final a = QuickEvent(
        categoryId: 'shot',
        eventTypeId: 'shot_saved',
        grade: null,
        slotId: 'a',
        categoryLabel: 'Original category',
        eventLabel: 'Original name',
        taxonomyRevision: 'custom-1',
        definition: 'Original definition',
        context: {'actor': '12'},
      );
      final b = QuickEvent(
        categoryId: 'shot',
        eventTypeId: 'shot_saved',
        grade: EventGrade.positive,
        slotId: 'b',
      );
      controller.add(a);
      controller.add(b);
      expect(controller.items, hasLength(2));
      final captured = controller.createEvent(
        QuickEvent.fromJson(a.toJson()),
        taxonomy,
        const Duration(seconds: 3),
      )!;
      expect(captured.label, 'Original category');
      expect(captured.detail, 'Original name');
      expect(captured.taxonomyRevision, 'custom-1');
      expect(captured.definition, 'Original definition');
      expect(captured.context, {'actor': '12'});
      expect(captured.grade, isNull);
      expect(controller.suggestedPresets, hasLength(4));
      for (final preset in controller.suggestedPresets) {
        for (final item in preset.items) {
          expect(
            controller.createEvent(item, taxonomy, Duration.zero),
            isNotNull,
          );
          expect(
            taxonomy.getEventTypeById(item.eventTypeId)!.archived,
            isFalse,
          );
        }
      }
      await controller.flushed;
      controller.dispose();
    },
  );

  test(
    'Track preserves existing IDs and shares precise Record definitions',
    () {
      for (final old in HockeyTrackingPresets.all) {
        final current = taxonomy.trackingPresets.singleWhere(
          (t) => t.id == old.id,
        );
        expect(current.kind, old.kind);
        expect(current.definition, isNotEmpty);
      }
      for (final tracker in taxonomy.trackingPresets.where(
        (t) => t.eventTypeId != null,
      )) {
        final type = taxonomy
            .getCategoryById(tracker.categoryId!)!
            .getEventTypeById(tracker.eventTypeId!)!;
        expect(tracker.definition, type.definition);
        expect(tracker.taxonomyRevision, taxonomy.revision);
      }
    },
  );

  testWidgets('category page two shows numbered choices matching dispatch', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventButtonsPanel(
            taxonomy: taxonomy,
            showNumbers: true,
            entryPage: 1,
            onEventTriggered: (id) => selected = id,
          ),
        ),
      ),
    );
    expect(find.text('1. Goalie'), findsOneWidget);
    expect(find.text('2. Penalty'), findsOneWidget);
    expect(find.text('1. Shot'), findsNothing);
    await tester.tap(find.text('2. Penalty'));
    expect(selected, 'penalty');
  });

  testWidgets(
    'SmartHUD paginates long subtype lists and saves an ungraded choice',
    (tester) async {
      final types = List.generate(
        12,
        (i) => EventTypeTaxonomy(
          eventTypeId: 't$i',
          name: 'Type $i',
          definition: 'Definition $i',
        ),
      );
      final custom = SportTaxonomy(
        schemaVersion: 2,
        sportId: 'custom',
        name: 'Custom',
        categories: [
          CategoryTaxonomy(
            categoryId: 'c',
            name: 'Category',
            iconKey: 'circle',
            colorKey: 'grey',
            eventTypes: types,
          ),
        ],
      );
      var draft = GameEvent(
        id: 'draft',
        timestamp: Duration.zero,
        categoryId: 'c',
        label: 'Category',
      );
      var saved = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SmartHUD(
                event: draft,
                taxonomy: custom,
                showTagNumbers: true,
                entryPage: 1,
                onUpdateEvent: (value) => setState(() => draft = value),
                onDeleteEvent: (_) {},
                onDismiss: () {},
                onSave: () => saved = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Type 0'), findsNothing);
      await tester.tap(find.text('Type 11'));
      await tester.pumpAndSettle();
      expect(draft.eventTypeId, 't11');
      expect(draft.grade, isNull);
      expect(draft.definition, 'Definition 11');
      await tester.tap(find.text('Save event'));
      expect(saved, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'optional context supports typing and clearing without dropping other details',
    (tester) async {
      var values = <String, String>{'analysisTeam': 'Wolves', 'actor': '12'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => EventContextEditor(
                  taxonomy: taxonomy,
                  categoryId: 'shot',
                  values: values,
                  onChanged: (next) => setState(() => values = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Event context (optional)'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('shot:analysisTeam'));
      await tester.enterText(field, 'Bears');
      expect(values, {'analysisTeam': 'Bears', 'actor': '12'});
      await tester.pump();
      await tester.enterText(field, '');
      expect(values, {'actor': '12'});
      expect(tester.takeException(), isNull);
    },
  );
}
