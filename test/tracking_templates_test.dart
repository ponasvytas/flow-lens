import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_lens/controllers/tracking_controller.dart';
import 'package:flow_lens/controllers/tracking_templates_controller.dart';
import 'package:flow_lens/models/sport_taxonomy.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/models/tracking_template.dart';
import 'package:flow_lens/services/taxonomy_repository.dart';
import 'package:flow_lens/services/tracking_template_repository.dart';

const pass = TrackingDefinition(
  id: 'pass',
  label: 'Completed',
  kind: TrackerKind.counter,
  sportId: 'hockey',
  definition: 'A completed pass.',
);
const shift = TrackingDefinition(
  id: 'shift',
  label: 'Observed shift',
  kind: TrackerKind.timer,
  timerMode: TimerMode.toggle,
  sportId: 'hockey',
);
const alice = TrackingSubject(id: 'alice', label: 'Alice');
const bob = TrackingSubject(id: 'bob', label: 'Bob');

TrackingTemplate passing({String sport = 'hockey'}) => TrackingTemplate(
  id: '$sport.passes',
  sportId: sport,
  name: 'Passing',
  trackers: [pass.copyWith(sportId: sport)],
);
TrackingController controller() => TrackingController(
  session: TrackingSession(
    id: 'game',
    sportId: 'hockey',
    videoIdentity: 'a',
    subjects: [alice, bob],
    trackers: [pass, shift],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'six hockey starters resolve and survive taxonomy serialization',
    () async {
      final taxonomy = await BundledTaxonomyRepository().loadSportTaxonomy(
        'hockey',
      );
      expect(taxonomy.trackingTemplates, hasLength(6));
      final restored = SportTaxonomy.fromJson(taxonomy.toJson());
      restored.validate();
      for (final entry in restored.trackingTemplates) {
        final template = entry.resolve(
          restored.sportId,
          restored.trackingPresets,
        );
        expect(template.trackers.length, inInclusiveRange(3, 5));
        expect(
          TrackingTemplate.fromJson(template.toJson()).toJson(),
          template.toJson(),
        );
      }
    },
  );

  test(
    'basketball and volleyball templates use the same catalog machinery',
    () {
      for (final sport in ['basketball', 'volleyball']) {
        final taxonomy = SportTaxonomy(
          schemaVersion: 1,
          sportId: sport,
          name: sport,
          categories: [],
          trackingPresets: [pass.copyWith(sportId: sport)],
          trackingTemplates: [
            SportTrackingTemplate(
              id: '$sport.basic',
              name: 'Basic',
              description: '',
              subjectKind: TrackingSubjectKind.team,
              trackerIds: ['pass'],
            ),
          ],
        );
        taxonomy.validate();
        expect(
          taxonomy.trackingTemplates.single
              .resolve(sport, taxonomy.trackingPresets)
              .sportId,
          sport,
        );
      }
      expect(
        () => SportTaxonomy(
          schemaVersion: 1,
          sportId: 'soccer',
          name: 'Soccer',
          categories: [],
          trackingPresets: [pass],
        ).validate(),
        throwsFormatException,
      );
    },
  );

  test(
    'template validation rejects ambiguous or unsupported configuration',
    () {
      expect(
        () => TrackingTemplate(
          id: 'bad',
          name: 'Bad',
          sportId: 'soccer',
          trackers: [pass],
        ),
        throwsFormatException,
      );
      expect(
        () => TrackingTemplate(
          id: 'bad',
          name: 'Bad',
          sportId: 'hockey',
          trackers: [pass, pass],
        ),
        throwsFormatException,
      );
      expect(
        () => TrackingTemplate.fromJson({
          ...passing().toJson(),
          'schemaVersion': 2,
        }),
        throwsFormatException,
      );
      expect(
        () => TrackingTemplate.fromJson({...passing().toJson(), 'results': []}),
        throwsFormatException,
      );
      expect(
        () => TrackingTemplate.fromJson(TrackingSession(id: 'game').toJson()),
        throwsFormatException,
      );
      expect(
        () => TrackingSession.fromJson(passing().toJson()),
        throwsFormatException,
      );
      expect(
        () => TrackingDefinition.fromJson({
          ...pass.toJson(),
          'kind': 'calculated',
        }),
        throwsFormatException,
      );
      expect(() => passing().trackers.add(shift), throwsUnsupportedError);
    },
  );

  test('legacy sessions infer sport and keep saved definition meaning', () {
    final original = TrackingSession(
      id: 'legacy',
      trackers: [pass],
      subjects: [alice],
    );
    final json = original.toJson()
      ..remove('schemaVersion')
      ..remove('documentType')
      ..remove('sportId')
      ..remove('visibleTrackerIds');
    final migrated = TrackingSession.fromJson(json);
    expect(migrated.sportId, 'hockey');
    expect(migrated.visibleTrackerIds, ['pass']);
    expect(migrated.trackers.single.definition, pass.definition);
    expect(() => migrated.trackers.clear(), throwsUnsupportedError);
    final mixed = TrackingSession(
      id: 'mixed',
      trackers: [
        pass,
        pass.copyWith(id: 'soccer', sportId: 'soccer'),
      ],
    );
    expect(mixed.sportId, isNull);
    expect(mixed.hasConsistentSport, isFalse);
  });

  test(
    'hiding and restoring retains counter totals, labels and timer history',
    () {
      final ctrl = controller();
      addTearDown(ctrl.dispose);
      ctrl.incrementCounter(
        subjectId: 'alice',
        trackerId: 'pass',
        timestamp: Duration.zero,
        delta: 4,
      );
      ctrl.startTimer(
        subjectId: 'alice',
        trackerId: 'shift',
        timestamp: const Duration(seconds: 2),
      );
      ctrl.configureTrackers([], timestamp: const Duration(seconds: 8));
      expect(ctrl.trackers, isEmpty);
      expect(ctrl.session.trackers, hasLength(2));
      expect(ctrl.getCounterValue('alice', 'pass'), 4);
      expect(
        ctrl.getTimerDuration('alice', 'shift'),
        const Duration(seconds: 6),
      );
      expect(ctrl.activeTimerKeys, isEmpty);
      ctrl.configureTrackers([shift, pass]);
      expect(ctrl.trackers.map((t) => t.id), ['shift', 'pass']);
      ctrl.loadSession(TrackingSession.fromJson(ctrl.session.toJson()));
      expect(ctrl.getCounterValue('alice', 'pass'), 4);
      expect(
        ctrl.getTimerDuration('alice', 'shift'),
        const Duration(seconds: 6),
      );
    },
  );

  test('template applies atomically, binds a subject, and is idempotent', () {
    final ctrl = controller();
    addTearDown(ctrl.dispose);
    var notifications = 0;
    ctrl.addListener(() => notifications++);
    ctrl.applyTemplate(
      passing(),
      subjectId: 'alice',
      timestamp: Duration.zero,
      replaceVisible: true,
    );
    expect(notifications, 1);
    expect(ctrl.trackersForSubject('alice'), [pass]);
    expect(ctrl.trackersForSubject('bob'), isEmpty);
    ctrl.applyTemplate(
      passing(),
      subjectId: 'alice',
      timestamp: Duration.zero,
      replaceVisible: true,
    );
    expect(notifications, 1);
    expect(ctrl.session.trackers, hasLength(2));
    expect(ctrl.undoTemplate(), isTrue);
    expect(ctrl.trackersForSubject('bob'), [pass, shift]);
  });

  test('undo restores timers and removes a newly created template subject', () {
    final ctrl = controller();
    addTearDown(ctrl.dispose);
    ctrl.startTimer(
      subjectId: 'bob',
      trackerId: 'shift',
      timestamp: const Duration(seconds: 2),
    );
    ctrl.applyTemplateToSubject(
      passing(),
      newSubject: const TrackingSubject(id: 'new', label: 'New'),
      timestamp: const Duration(seconds: 8),
      replaceVisible: true,
    );
    expect(ctrl.subjects, hasLength(3));
    expect(ctrl.getTimerDuration('bob', 'shift'), const Duration(seconds: 6));
    expect(ctrl.undoTemplate(), isTrue);
    expect(ctrl.subjects, hasLength(2));
    expect(ctrl.isTimerRunning('bob', 'shift'), isTrue);
    expect(ctrl.events, hasLength(1));
  });

  test('template conflicts never mutate observations or add a subject', () {
    final ctrl = controller();
    addTearDown(ctrl.dispose);
    ctrl.incrementCounter(
      subjectId: 'alice',
      trackerId: 'pass',
      timestamp: Duration.zero,
    );
    final before = ctrl.session.toJson();
    final incompatible = passing().copyWith(
      trackers: [pass.copyWith(definition: 'A different meaning')],
    );
    expect(
      () => ctrl.applyTemplateToSubject(
        incompatible,
        newSubject: const TrackingSubject(id: 'new', label: 'New'),
        timestamp: Duration.zero,
      ),
      throwsStateError,
    );
    expect(ctrl.session.toJson(), before);
    expect(
      () => ctrl.applyTemplate(
        passing(sport: 'soccer'),
        subjectId: 'alice',
        timestamp: Duration.zero,
      ),
      throwsStateError,
    );
    expect(ctrl.session.toJson(), before);
  });

  test(
    'later capture invalidates template undo and hidden keys cannot record',
    () {
      final ctrl = controller();
      addTearDown(ctrl.dispose);
      ctrl.setHotkey('bob', 'shift', 'j');
      ctrl.applyTemplate(
        passing(),
        subjectId: 'alice',
        timestamp: Duration.zero,
        replaceVisible: true,
      );
      expect(ctrl.handleHotkeyDown('j', Duration.zero), isFalse);
      ctrl.incrementCounter(
        subjectId: 'alice',
        trackerId: 'pass',
        timestamp: Duration.zero,
      );
      expect(ctrl.undoTemplate(), isFalse);
      expect(ctrl.getCounterValue('alice', 'pass'), 1);
      ctrl.removeSubject('alice', timestamp: Duration.zero);
      expect(ctrl.subjects, [bob]);
      expect(ctrl.session.subjects, [alice, bob]);
      ctrl.addSubject(alice);
      expect(ctrl.getCounterValue('alice', 'pass'), 1);
    },
  );

  test(
    'video and sport workspaces isolate data and finalize timers before switching',
    () {
      final ctrl = controller();
      addTearDown(ctrl.dispose);
      ctrl.incrementCounter(
        subjectId: 'alice',
        trackerId: 'pass',
        timestamp: Duration.zero,
      );
      ctrl.startTimer(
        subjectId: 'alice',
        trackerId: 'shift',
        timestamp: const Duration(seconds: 2),
      );
      ctrl.activateWorkspace(
        sportId: 'hockey',
        videoIdentity: 'b',
        timestamp: const Duration(seconds: 7),
      );
      expect(ctrl.events, isEmpty);
      expect(ctrl.subjects, isEmpty);
      ctrl.activateWorkspace(
        sportId: 'soccer',
        videoIdentity: 'a',
        timestamp: Duration.zero,
      );
      expect(ctrl.session.sportId, 'soccer');
      expect(ctrl.events, isEmpty);
      ctrl.activateWorkspace(
        sportId: 'hockey',
        videoIdentity: 'a',
        timestamp: Duration.zero,
      );
      expect(ctrl.getCounterValue('alice', 'pass'), 1);
      expect(
        ctrl.getTimerDuration('alice', 'shift'),
        const Duration(seconds: 5),
      );
      expect(ctrl.activeTimerKeys, isEmpty);
    },
  );

  test('backward timer boundaries never expose a negative interval', () {
    final ctrl = controller();
    addTearDown(ctrl.dispose);
    ctrl.startTimer(
      subjectId: 'alice',
      trackerId: 'shift',
      timestamp: const Duration(seconds: 8),
    );
    ctrl.stopTimer(
      subjectId: 'alice',
      trackerId: 'shift',
      timestamp: const Duration(seconds: 2),
    );
    expect(ctrl.getTimerDuration('alice', 'shift'), Duration.zero);
    expect(ctrl.getTimerIntervals('alice', 'shift'), isEmpty);
  });

  test(
    'local templates save configuration without roster, video or observations',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = TrackingTemplatesController(
        LocalTrackingTemplateRepository(),
      );
      addTearDown(library.dispose);
      await library.load();
      final saved = library.saveCopy(passing(), 'My passing');
      library.rename(saved, 'Renamed');
      library.saveCopy(passing(sport: 'soccer'), 'Soccer passing');
      await library.flushed;
      final loaded = TrackingTemplatesController(
        LocalTrackingTemplateRepository(),
      );
      addTearDown(loaded.dispose);
      await loaded.load();
      expect(loaded.forSport('hockey').single.name, 'Renamed');
      expect(loaded.forSport('hockey').single.revision, 2);
      expect(loaded.forSport('soccer'), hasLength(1));
      final encoded = jsonEncode(loaded.forSport('hockey').single.toJson());
      for (final key in [
        'subjects',
        'events',
        'hotkeys',
        'videoIdentity',
        'videoSource',
      ]) {
        expect(encoded, isNot(contains('"$key"')));
      }
      loaded.delete(saved.id);
      await loaded.flushed;
      expect(loaded.forSport('hockey'), isEmpty);
    },
  );

  test('failed library writes retain drafts and can be retried', () async {
    final repo = _FailingRepository();
    final library = TrackingTemplatesController(repo);
    addTearDown(library.dispose);
    await library.load();
    library.saveCopy(passing(), 'One');
    library.saveCopy(passing(), 'Two');
    await library.flushed;
    expect(library.error, isNotNull);
    expect(library.forSport('hockey'), hasLength(2));
    repo.fail = false;
    library.retrySave();
    await library.flushed;
    expect(library.error, isNull);
    expect(repo.saved.map((t) => t.name), ['One', 'Two']);
  });
}

class _FailingRepository implements TrackingTemplateRepository {
  bool fail = true;
  List<TrackingTemplate> saved = [];
  @override
  Future<List<TrackingTemplate>> load() async => saved;
  @override
  Future<void> save(List<TrackingTemplate> templates) async {
    if (fail) throw StateError('Offline storage failed');
    saved = templates;
  }
}
