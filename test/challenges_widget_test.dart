import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/models/challenge.dart';
import 'package:flow_lens/models/cloud_sessions.dart';
import 'package:flow_lens/widgets/challenge_create_page.dart';
import 'package:flow_lens/widgets/challenge_play_page.dart';
import 'package:flow_lens/theme/flow_theme.dart';
import 'challenge_fixtures.dart';

void main() {
  testWidgets(
    'participant screen never displays hidden answers before submission',
    (tester) async {
      final repo = FakeChallengeRepository((_) async => challengeFixture());
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowTheme.dark,
          home: ChallengePlayPage(
            repository: repo,
            initial: ChallengeDetail.fromJson(challengeFixture()),
          ),
        ),
      );
      expect(find.text('Find my good breakout.'), findsOneWidget);
      expect(find.text('Secret reference explanation.'), findsNothing);
      expect(find.text('The reference plays'), findsNothing);
      await tester.ensureVisible(find.text('Submit answers'));
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Submit answers'),
      );
      expect(button.onPressed, isNull);
      expect(repo.requests, isEmpty);
    },
  );

  testWidgets('refresh reveals submitted results and enables challenge back', (
    tester,
  ) async {
    final repo = FakeChallengeRepository(
      (_) async => challengeFixture(submitted: true, revealed: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: ChallengePlayPage(
          repository: repo,
          initial: ChallengeDetail.fromJson(challengeFixture(submitted: true)),
        ),
      ),
    );
    expect(find.textContaining('Answers submitted.'), findsOneWidget);
    expect(find.text('Secret reference explanation.'), findsNothing);
    await tester.tap(find.byTooltip('Refresh challenge'));
    await tester.pumpAndSettle();
    expect(find.text('Sam · 2/2 points'), findsOneWidget);
    await tester.ensureVisible(find.text('Challenge back with your moments'));
    await tester.tap(find.text('Challenge back with your moments'));
    await tester.pumpAndSettle();
    expect(find.text('Create a challenge'), findsOneWidget);
    expect(find.text('game.mp4'), findsOneWidget);
  });

  for (final size in [const Size(375, 667), const Size(667, 375)]) {
    testWidgets('challenge screens fit $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = FakeChallengeRepository(
        (_) async => challengeFixture(owner: true),
      );
      Widget app(Widget child) => MaterialApp(
        theme: FlowTheme.dark,
        builder: (context, widget) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: widget!,
        ),
        home: child,
      );
      await tester.pumpWidget(
        app(
          ChallengePlayPage(
            repository: repo,
            initial: ChallengeDetail.fromJson(challengeFixture(owner: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        app(
          ChallengeCreatePage(
            repository: repo,
            video: const VideoSourceMetadata(
              kind: VideoSourceKind.localFile,
              displayName: 'game.mp4',
              durationMs: 120000,
            ),
            moments: [ChallengeMoment.fromJson(referenceFixture)],
            sportId: 'hockey',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Create challenge'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('creator validation prevents sending incomplete challenges', (
    tester,
  ) async {
    final repo = FakeChallengeRepository(
      (_) async => challengeFixture(owner: true),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowTheme.dark,
        home: ChallengeCreatePage(
          repository: repo,
          video: const VideoSourceMetadata(
            kind: VideoSourceKind.localFile,
            displayName: 'game.mp4',
            durationMs: 120000,
          ),
          moments: [ChallengeMoment.fromJson(referenceFixture)],
          sportId: 'hockey',
        ),
      ),
    );
    await tester.ensureVisible(find.text('Create challenge'));
    await tester.tap(find.text('Create challenge'));
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Challenge title'),
    );
    expect(find.text('Enter challenge title.'), findsOneWidget);
  });
}
