import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flow_lens/controllers/challenges_controller.dart';
import 'package:flow_lens/models/challenge.dart';
import 'package:flow_lens/models/cloud_sessions.dart';
import 'package:flow_lens/services/challenge_repository.dart';
import 'package:http/http.dart' as http;
import 'challenge_fixtures.dart';

void main() {
  test('invitation round trips without putting the secret in the query', () {
    final invitation = ChallengeInvitation('challenge12345', 'a' * 32);
    final uri = invitation.toUri();
    expect(uri.queryParameters.keys, ['challenge']);
    expect(ChallengeInvitation.parse(uri.toString())!.token, invitation.token);
    expect(ChallengeInvitation.parse('?challenge=bad#invite=secret'), isNull);
    expect(
      ChallengeInvitation.parse(
        'https://example.test/?challenge=challenge12345',
      ),
      isNull,
    );
    expect(ChallengeInvitation.parse('%invalid'), isNull);
  });

  test('challenge snapshots detach the references collection', () {
    final source = [ChallengeMoment.fromJson(referenceFixture)];
    final draft = ChallengeDraft(
      title: 'Title',
      prompt: 'Prompt',
      sportId: 'hockey',
      video: const VideoSourceMetadata(kind: VideoSourceKind.localFile),
      references: source,
      startMs: 0,
      endMs: 100000,
    );
    source.clear();
    expect(draft.references, hasLength(1));
    expect(() => draft.references.clear(), throwsUnsupportedError);
  });

  test('time input validates seconds and supports whole games', () {
    expect(parseChallengeTime('120:05'), 7205000);
    expect(challengeTime(7205000), '120:05');
    for (final value in ['1:60', '-1:05', '1:2:3', 'abc', '1.5:00']) {
      expect(parseChallengeTime(value), isNull);
    }
  });

  test('participant models allow withheld results and references', () {
    final waiting = ChallengeDetail.fromJson(challengeFixture(submitted: true));
    expect(waiting.references, isNull);
    expect(waiting.submission!.result, isNull);
    expect(waiting.challenge.inviteToken, isNull);
    final revealed = ChallengeDetail.fromJson(
      challengeFixture(submitted: true, revealed: true),
    );
    expect(revealed.submission!.result!.score, 2);
    expect(
      revealed.references!.single.explanation,
      'Secret reference explanation.',
    );
  });

  test(
    'controller prevents duplicate actions and ignores completion after disposal',
    () async {
      final response = Completer<Map<String, dynamic>>();
      final repo = FakeChallengeRepository((_) => response.future);
      final controller = ChallengesController(repo);
      final pending = controller.open('challenge12345');
      expect(await controller.open('challenge12345'), isFalse);
      controller.dispose();
      response.complete(challengeFixture());
      expect(await pending, isFalse);
      expect(controller.detail, isNull);
      expect(repo.requests, hasLength(1));
    },
  );

  test(
    'controller retains attempt state and allows retry after network failure',
    () async {
      var fail = true;
      final repo = FakeChallengeRepository((_) async {
        if (fail) throw const ChallengeException('Offline');
        return challengeFixture();
      });
      final controller = ChallengesController(repo);
      expect(await controller.open('challenge12345'), isFalse);
      expect(controller.error, 'Offline');
      fail = false;
      expect(await controller.open('challenge12345'), isTrue);
      expect(controller.error, isNull);
      controller.dispose();
    },
  );

  test(
    'transport sends authenticated callable envelope and surfaces server errors',
    () async {
      final repo = FirebaseChallengeRepository.withTransport(
        token: () async => 'test-token',
        endpoint: Uri.parse('https://example.test/challenges'),
        post: (uri, {headers, body, encoding}) async {
          expect(headers!['Authorization'], 'Bearer test-token');
          expect(jsonDecode(body as String), {
            'data': {'action': 'list'},
          });
          return http.Response(
            jsonEncode({
              'result': {'challenges': []},
            }),
            200,
          );
        },
      );
      expect(await repo.request({'action': 'list'}), {'challenges': []});
      final denied = FirebaseChallengeRepository.withTransport(
        token: () async => 'test-token',
        endpoint: Uri.parse('https://example.test/challenges'),
        post: (uri, {headers, body, encoding}) async => http.Response(
          jsonEncode({
            'error': {'message': 'Invitation revoked.'},
          }),
          403,
        ),
      );
      await expectLater(
        denied.request({'action': 'get'}),
        throwsA(
          isA<ChallengeException>().having(
            (e) => e.message,
            'message',
            'Invitation revoked.',
          ),
        ),
      );
    },
  );
}
