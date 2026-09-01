import 'package:flow_lens/models/cloud_sessions.dart';
import 'package:flow_lens/models/game_event.dart';
import 'package:flow_lens/models/tracking_models.dart';
import 'package:flow_lens/services/session_repository_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local video metadata never includes an absolute path', () {
    final metadata = VideoSourceMetadata.fromSource(
      r'C:\Users\coach\Videos\game.mp4',
      duration: const Duration(minutes: 10),
    );

    expect(metadata.kind, VideoSourceKind.localFile);
    expect(metadata.displayName, 'game.mp4');
    expect(metadata.externalUrl, isNull);
    expect(metadata.toJson().toString(), isNot(contains('Users')));
  });

  test('external video metadata retains only an explicit web URL', () {
    const source = 'https://media.example.com/games/game.mp4';
    final metadata = VideoSourceMetadata.fromSource(source);

    expect(metadata.kind, VideoSourceKind.externalUrl);
    expect(metadata.displayName, 'game.mp4');
    expect(metadata.externalUrl, source);
  });

  test('event cloud session round trips existing event JSON', () {
    final draft = EventSessionDraft(
      title: 'Game one',
      sportId: 'hockey',
      taxonomyId: 'built-in:hockey',
      taxonomyRevision: 1,
      taxonomySnapshot: const {
        'schemaVersion': 1,
        'sportId': 'hockey',
        'name': 'Hockey',
        'categories': <dynamic>[],
      },
      events: [
        GameEvent(
          id: 'event-1',
          timestamp: const Duration(seconds: 12),
          label: 'Shot',
          categoryId: 'shot',
        ),
      ],
    );
    final now = DateTime.utc(2026, 8, 9);
    final map = {
      ...draft.toContentMap(),
      'ownerType': 'user',
      'ownerId': 'user-1',
      'createdByUserId': 'user-1',
      'updatedByUserId': 'user-1',
      'createdAt': now,
      'updatedAt': now,
      'archivedAt': null,
    };

    final session = CloudEventSession.fromMap('session-1', map);

    expect(session.id, 'session-1');
    expect(session.events.single.id, 'event-1');
    expect(session.events.single.timestamp, const Duration(seconds: 12));
    expect(
      () => session.events.add(session.events.single),
      throwsUnsupportedError,
    );
  });

  test('tracking cloud payload round trips and strips local video source', () {
    final tracking = TrackingSession(
      id: 'tracking-local',
      videoSource: r'C:\private\game.mp4',
      createdAt: DateTime.utc(2026, 8, 9),
      subjects: const [TrackingSubject(id: 'p1', label: 'Player 1')],
      trackers: const [
        TrackingDefinition(
          id: 'passes',
          label: 'Passes',
          kind: TrackerKind.counter,
        ),
      ],
      events: const [
        TrackingEvent(
          id: 'te_1',
          timestamp: Duration(seconds: 4),
          subjectId: 'p1',
          trackerId: 'passes',
          action: TrackingAction.increment,
          delta: 1,
        ),
      ],
    );
    final draft = TrackingSessionDraft(
      title: 'Tracking game',
      sportId: 'hockey',
      session: tracking,
      sourceVideo: VideoSourceMetadata.fromSource(tracking.videoSource),
    );
    final content = draft.toContentMap();
    final trackingJson = content['trackingSession'] as Map<String, dynamic>;

    expect(trackingJson, isNot(contains('videoSource')));

    final now = DateTime.utc(2026, 8, 9);
    final session = CloudTrackingSession.fromMap('cloud-1', {
      ...content,
      'ownerType': 'user',
      'ownerId': 'user-1',
      'createdByUserId': 'user-1',
      'updatedByUserId': 'user-1',
      'createdAt': now,
      'updatedAt': now,
      'archivedAt': null,
    });
    expect(session.session.subjects.single.label, 'Player 1');
    expect(session.session.events.single.delta, 1);
    expect(session.session.videoSource, isNull);
  });

  test('oversized session content is rejected before a cloud write', () {
    final content = {
      'events': [
        {
          'detail': List.filled(
            SessionDocumentSize.maximumBytes + 1,
            'x',
          ).join(),
        },
      ],
    };

    expect(
      () => SessionDocumentSize.validate(content),
      throwsA(isA<SessionSizeException>()),
    );
  });
}
