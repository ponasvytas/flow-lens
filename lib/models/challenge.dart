import 'cloud_sessions.dart';
import 'game_event.dart';
import '../app/backend_environment.dart';

Map<String, dynamic> challengeMap(Object? value) =>
    Map<String, dynamic>.from(value as Map);

class ChallengeMoment {
  const ChallengeMoment({
    required this.id,
    required this.timestampMs,
    this.grade,
    this.label = '',
    this.explanation = '',
  });

  factory ChallengeMoment.fromJson(Map<String, dynamic> json) =>
      ChallengeMoment(
        id: json['id'] as String,
        timestampMs: (json['timestampMs'] as num).toInt(),
        grade: EventGrade.values
            .where((g) => g.name == json['grade'])
            .firstOrNull,
        label: json['label'] as String? ?? '',
        explanation: json['explanation'] as String? ?? '',
      );

  factory ChallengeMoment.fromEvent(GameEvent event) => ChallengeMoment(
    id: event.id,
    timestampMs: event.timestamp.inMilliseconds,
    grade: event.grade,
    label: event.label,
    explanation: event.detail ?? '',
  );

  final String id;
  final int timestampMs;
  final EventGrade? grade;
  final String label;
  final String explanation;

  ChallengeMoment copyWith({String? explanation}) => ChallengeMoment(
    id: id,
    timestampMs: timestampMs,
    grade: grade,
    label: label,
    explanation: explanation ?? this.explanation,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestampMs': timestampMs,
    'grade': grade?.name,
    'label': label,
    'explanation': explanation,
  };
}

class ChallengeDraft {
  ChallengeDraft({
    required this.title,
    required this.prompt,
    required this.sportId,
    required this.video,
    required Iterable<ChallengeMoment> references,
    required this.startMs,
    required this.endMs,
    this.scoreGrades = true,
    this.toleranceMs = 5000,
    this.revealAtMs,
  }) : references = List.unmodifiable(references);

  final String title;
  final String prompt;
  final String sportId;
  final VideoSourceMetadata video;
  final List<ChallengeMoment> references;
  final int startMs;
  final int endMs;
  final bool scoreGrades;
  final int toleranceMs;
  final int? revealAtMs;

  Map<String, dynamic> toJson() => {
    'title': title,
    'prompt': prompt,
    'sportId': sportId,
    'video': video.toJson(),
    'references': references.map((r) => r.toJson()).toList(),
    'startMs': startMs,
    'endMs': endMs,
    'scoreGrades': scoreGrades,
    'toleranceMs': toleranceMs,
    'revealAtMs': revealAtMs,
  };
}

class ChallengeSummary {
  const ChallengeSummary({
    required this.id,
    required this.title,
    required this.isOwner,
    required this.revoked,
    required this.referenceCount,
  });

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) =>
      ChallengeSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        isOwner: json['isOwner'] as bool,
        revoked: json['revoked'] as bool,
        referenceCount: (json['referenceCount'] as num).toInt(),
      );

  final String id;
  final String title;
  final bool isOwner;
  final bool revoked;
  final int referenceCount;
}

class VideoChallenge {
  VideoChallenge.fromJson(Map<String, dynamic> json)
    : summary = ChallengeSummary.fromJson(json),
      prompt = json['prompt'] as String,
      sportId = json['sportId'] as String,
      video = VideoSourceMetadata.fromJson(challengeMap(json['video'])),
      startMs = (json['startMs'] as num).toInt(),
      endMs = (json['endMs'] as num).toInt(),
      toleranceMs = (json['toleranceMs'] as num).toInt(),
      scoreGrades = json['scoreGrades'] as bool,
      revealAtMs = (json['revealAtMs'] as num?)?.toInt(),
      inviteToken = json['inviteToken'] as String?;

  final ChallengeSummary summary;
  final String prompt;
  final String sportId;
  final VideoSourceMetadata video;
  final int startMs;
  final int endMs;
  final int toleranceMs;
  final bool scoreGrades;
  final int? revealAtMs;
  final String? inviteToken;
}

class ChallengeMatch {
  ChallengeMatch.fromJson(Map<String, dynamic> json)
    : answerId = json['answerId'] as String,
      referenceId = json['referenceId'] as String,
      points = (json['points'] as num).toInt(),
      acceptedByCreator = json['acceptedByCreator'] as bool;
  final String answerId;
  final String referenceId;
  final int points;
  final bool acceptedByCreator;
}

class ChallengeResult {
  ChallengeResult.fromJson(Map<String, dynamic> json)
    : score = (json['score'] as num).toInt(),
      maxScore = (json['maxScore'] as num).toInt(),
      matches = List.unmodifiable(
        (json['matches'] as List).map(
          (m) => ChallengeMatch.fromJson(challengeMap(m)),
        ),
      );
  final int score;
  final int maxScore;
  final List<ChallengeMatch> matches;
}

class ChallengeSubmission {
  ChallengeSubmission.fromJson(Map<String, dynamic> json)
    : userId = json['userId'] as String,
      displayName = json['displayName'] as String,
      answers = List.unmodifiable(
        (json['answers'] as List).map(
          (a) => ChallengeMoment.fromJson(challengeMap(a)),
        ),
      ),
      result = json['result'] == null
          ? null
          : ChallengeResult.fromJson(challengeMap(json['result']));
  final String userId;
  final String displayName;
  final List<ChallengeMoment> answers;
  final ChallengeResult? result;
}

class ChallengeDetail {
  ChallengeDetail.fromJson(Map<String, dynamic> json)
    : challenge = VideoChallenge.fromJson(challengeMap(json['challenge'])),
      references = json['references'] == null
          ? null
          : List.unmodifiable(
              (json['references'] as List).map(
                (r) => ChallengeMoment.fromJson(challengeMap(r)),
              ),
            ),
      submission = json['submission'] == null
          ? null
          : ChallengeSubmission.fromJson(challengeMap(json['submission'])),
      submissions = List.unmodifiable(
        (json['submissions'] as List).map(
          (s) => ChallengeSubmission.fromJson(challengeMap(s)),
        ),
      ),
      serverNowMs = (json['serverNowMs'] as num).toInt();
  final VideoChallenge challenge;
  final List<ChallengeMoment>? references;
  final ChallengeSubmission? submission;
  final List<ChallengeSubmission> submissions;
  final int serverNowMs;
  bool get closed =>
      challenge.summary.revoked ||
      (challenge.revealAtMs != null && serverNowMs >= challenge.revealAtMs!);
}

class ChallengeInvitation {
  const ChallengeInvitation(this.id, this.token);
  final String id;
  final String token;

  static ChallengeInvitation? parse(String value) {
    try {
      final uri = Uri.parse(value.trim());
      final id = uri.queryParameters['challenge'];
      final token = Uri.splitQueryString(uri.fragment)['invite'];
      if (id == null ||
          token == null ||
          !RegExp(r'^[a-zA-Z0-9_-]{10,100}$').hasMatch(id) ||
          !RegExp(r'^[\w-]{32}$').hasMatch(token)) {
        return null;
      }
      return ChallengeInvitation(id, token);
    } on FormatException {
      return null;
    }
  }

  Uri toUri({Uri? base}) {
    final root =
        base ?? BackendEnvironment.current.shareRoot(browserUri: Uri.base);
    return root.replace(
      queryParameters: {'challenge': id},
      fragment: Uri(queryParameters: {'invite': token}).query,
    );
  }
}

String challengeTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final minutes = seconds ~/ 60;
  return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
}

int? parseChallengeTime(String input) {
  final parts = input.trim().split(':');
  if (parts.length != 2 || !parts.every((p) => RegExp(r'^\d+$').hasMatch(p))) {
    return null;
  }
  final minutes = int.tryParse(parts[0]);
  final seconds = int.tryParse(parts[1]);
  if (minutes == null || seconds == null || seconds > 59) return null;
  return (minutes * 60 + seconds) * 1000;
}

String challengeGrade(EventGrade? grade) => switch (grade) {
  EventGrade.positive => 'Good',
  EventGrade.negative => 'Bad',
  EventGrade.neutral => 'Neutral',
  null => 'Unclassified',
};
