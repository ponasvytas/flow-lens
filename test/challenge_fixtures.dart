import 'package:flow_lens/services/challenge_repository.dart';

Map<String, dynamic> challengeFixture({
  bool owner = false,
  bool submitted = false,
  bool revealed = false,
  int? deadline,
}) => {
  'challenge': {
    'id': 'challenge12345',
    'title': 'Read the breakout',
    'prompt': 'Find my good breakout.',
    'sportId': 'hockey',
    'isOwner': owner,
    'revoked': false,
    'referenceCount': 1,
    'video': {
      'kind': 'localFile',
      'displayName': 'game.mp4',
      'durationMs': 120000,
    },
    'startMs': 0,
    'endMs': 120000,
    'toleranceMs': 5000,
    'scoreGrades': true,
    'revealAtMs': deadline,
    if (owner) 'inviteToken': 'a' * 32,
  },
  'references': owner || revealed ? [referenceFixture] : null,
  'submission': submitted
      ? {
          'userId': 'player1',
          'displayName': 'Sam',
          'answers': [
            {
              'id': 'answer-1',
              'timestampMs': 10000,
              'grade': 'positive',
              'explanation': 'The wing was open.',
            },
          ],
          if (revealed)
            'result': {
              'score': 2,
              'maxScore': 2,
              'matches': [
                {
                  'answerId': 'answer-1',
                  'referenceId': 'moment-1',
                  'points': 2,
                  'acceptedByCreator': false,
                },
              ],
            },
        }
      : null,
  'submissions': [],
  'serverNowMs': 1700000000000,
};

const referenceFixture = {
  'id': 'moment-1',
  'timestampMs': 10000,
  'grade': 'positive',
  'label': 'Breakout',
  'explanation': 'Secret reference explanation.',
};

class FakeChallengeRepository implements ChallengeRepository {
  FakeChallengeRepository(this.handler);
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) handler;
  final requests = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(Map<String, dynamic> data) {
    requests.add(data);
    return handler(data);
  }
}
