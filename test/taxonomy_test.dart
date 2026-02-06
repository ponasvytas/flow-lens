import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_video_analyzer/models/sport_taxonomy.dart';
import 'package:flutter_video_analyzer/services/taxonomy_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TaxonomyRepository', () {
    late TaxonomyRepository repository;

    setUp(() {
      repository = TaxonomyRepository();
    });

    test('loads hockey taxonomy successfully', () async {
      final taxonomy = await repository.loadSportTaxonomy('hockey');

      expect(taxonomy.sportId, 'hockey');
      expect(taxonomy.name, 'Hockey');
      expect(taxonomy.categories.length, 7);

      final shotCategory = taxonomy.getCategoryById('shot');
      expect(shotCategory, isNotNull);
      expect(shotCategory!.name, 'Shot');
      expect(shotCategory.eventTypes.length, 5);

      final goalEvent = shotCategory.getEventTypeById('shot_goal');
      expect(goalEvent, isNotNull);
      expect(goalEvent!.name, 'Goal');
      expect(goalEvent.defaultImpact?.name, 'positive');
    });

    test('unknown iconKey/colorKey fall back safely', () {
      final category = CategoryTaxonomy(
        categoryId: 'unknown_category',
        name: 'Unknown Category',
        iconKey: 'not_a_real_icon',
        colorKey: 'not_a_real_color',
        eventTypes: <EventTypeTaxonomy>[],
      );

      expect(category.getIcon(), Icons.circle);
      expect(category.getColor(), Colors.grey);
    });

    test('validates unique category IDs', () async {
      final taxonomy = await repository.loadSportTaxonomy('hockey');
      
      expect(() => taxonomy.validate(), returnsNormally);
    });

    test('validates unique event type IDs across categories', () async {
      final taxonomy = await repository.loadSportTaxonomy('hockey');
      
      final allEventTypeIds = <String>{};
      for (final category in taxonomy.categories) {
        for (final eventType in category.eventTypes) {
          expect(allEventTypeIds.contains(eventType.eventTypeId), false,
              reason: 'Duplicate eventTypeId: ${eventType.eventTypeId}');
          allEventTypeIds.add(eventType.eventTypeId);
        }
      }
    });

    test('caches loaded taxonomy', () async {
      final taxonomy1 = await repository.loadSportTaxonomy('hockey');
      final taxonomy2 = await repository.loadSportTaxonomy('hockey');
      
      expect(identical(taxonomy1, taxonomy2), true);
    });
  });
}
