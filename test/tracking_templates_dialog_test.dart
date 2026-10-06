import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/controllers/tracking_templates_controller.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/services/taxonomy_repository.dart';
import 'package:flow_lens/services/tracking_template_repository.dart';
import 'package:flow_lens/widgets/tracking_templates_dialog.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(1024, 768)]) {
    testWidgets(
      'starter preview binds a new team and undo works at $size with large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final taxonomy = (await tester.runAsync(
          () => BundledTaxonomyRepository().loadSportTaxonomy('hockey'),
        ))!;
        final tracking = TrackingController(
          session: TrackingSession(id: 'game', sportId: 'hockey'),
        );
        final library = TrackingTemplatesController(
          LocalTrackingTemplateRepository(),
        );
        await tester.runAsync(library.load);
        addTearDown(tracking.dispose);
        addTearDown(library.dispose);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => TrackingTemplatesDialog(
                      tracking: tracking,
                      library: library,
                      taxonomy: taxonomy,
                      position: () => const Duration(seconds: 5),
                    ),
                  ),
                  child: const Text('Open templates'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open templates'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final preview = find.text('Preview and apply').first;
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(TextField), 'Our team');
        await tester.tap(find.text('Apply template'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tracking.subjects.single.kind, TrackingSubjectKind.team);
        expect(tracking.subjects.single.label, 'Our team');
        expect(tracking.trackers, hasLength(3));
        expect(tracking.events, isEmpty);
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();
        expect(tracking.subjects, isEmpty);
        expect(tracking.trackers, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'save current selection, rename, and reopen without observations',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final taxonomy = (await tester.runAsync(
        () => BundledTaxonomyRepository().loadSportTaxonomy('hockey'),
      ))!;
      final template = taxonomy.trackingTemplates[1].resolve(
        'hockey',
        taxonomy.trackingPresets,
      );
      final tracking = TrackingController(
        session: TrackingSession(
          id: 'game',
          sportId: 'hockey',
          subjects: [
            const TrackingSubject(id: 'player', label: 'Private player'),
          ],
          trackers: template.trackers,
        ),
      );
      tracking.setActiveSubject('player');
      tracking.incrementCounter(
        subjectId: 'player',
        trackerId: template.trackers.first.id,
        timestamp: Duration.zero,
      );
      final library = TrackingTemplatesController(
        LocalTrackingTemplateRepository(),
      );
      await tester.runAsync(library.load);
      addTearDown(tracking.dispose);
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrackingTemplatesDialog(
              tracking: tracking,
              library: library,
              taxonomy: taxonomy,
              position: () => Duration.zero,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save current'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Passing practice');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await library.flushed;
      expect(library.forSport('hockey').single.name, 'Passing practice');
      final saved = library.forSport('hockey').single;
      expect(saved.trackers, template.trackers);
      expect(saved.toJson().containsKey('events'), isFalse);
      expect(saved.toJson().containsKey('subjects'), isFalse);
      final restored = TrackingTemplatesController(
        LocalTrackingTemplateRepository(),
      );
      addTearDown(restored.dispose);
      await tester.runAsync(restored.load);
      expect(restored.forSport('hockey').single.name, 'Passing practice');
      expect(tracking.events, hasLength(1));
    },
  );
}
