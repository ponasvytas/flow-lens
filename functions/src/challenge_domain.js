export const limits = Object.freeze({ active: 5, participants: 30, moments: 12 });

export class ChallengeError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}

export function requireThat(condition, message, code = 'invalid-argument') {
  if (!condition) throw new ChallengeError(code, message);
}

function text(value, name, max, optional = false) {
  requireThat(typeof value === 'string', `${name} must be text.`);
  const trimmed = value.trim();
  requireThat((optional || trimmed.length > 0) && trimmed.length <= max,
    `${name} must be ${optional ? '0' : '1'}–${max} characters.`);
  return trimmed;
}

function integer(value, name, min, max) {
  requireThat(Number.isSafeInteger(value) && value >= min && value <= max,
    `${name} must be between ${min} and ${max}.`);
  return value;
}

function grade(value) {
  requireThat(value === null || ['positive', 'negative', 'neutral'].includes(value),
    'Choose a valid classification.');
  return value;
}

export function validateDraft(data, now) {
  requireThat(data && typeof data === 'object', 'Enter a challenge.');
  const source = data.video;
  requireThat(source && ['localFile', 'externalUrl'].includes(source.kind), 'Choose a video.');
  const video = {
    kind: source.kind,
    displayName: text(source.displayName, 'Video name', 200),
    durationMs: integer(source.durationMs, 'Video duration', 1000, 8 * 3600000),
  };
  if (video.kind === 'externalUrl') {
    const url = text(source.externalUrl, 'Video URL', 4096);
    let parsed;
    try { parsed = new URL(url); } catch { /* Validated below. */ }
    requireThat(parsed && ['https:', 'http:'].includes(parsed.protocol) &&
      !parsed.username && !parsed.password, 'Use a direct HTTP(S) video URL without credentials.');
    video.externalUrl = url;
  }
  const startMs = integer(data.startMs, 'Start time', 0, video.durationMs - 1);
  const endMs = integer(data.endMs, 'End time', startMs + 1, video.durationMs);
  requireThat(Array.isArray(data.references) && data.references.length >= 1 &&
    data.references.length <= limits.moments, `Choose 1–${limits.moments} reference moments.`);
  const references = data.references.map((r, i) => ({
    id: `moment-${i + 1}`,
    timestampMs: integer(r.timestampMs, 'Reference time', startMs, endMs),
    grade: grade(r.grade),
    label: text(r.label, 'Event label', 120),
    explanation: text(r.explanation, 'Explanation', 1000),
  }));
  requireThat(new Set(references.map(r => r.timestampMs)).size === references.length,
    'Reference moments must have distinct timestamps.');
  requireThat(typeof data.scoreGrades === 'boolean', 'Choose classification scoring.');
  requireThat(!data.scoreGrades || references.every(r => r.grade !== null),
    'Every reference moment needs a classification when classification scoring is enabled.');
  const revealAtMs = data.revealAtMs === null ? null :
    integer(data.revealAtMs, 'Reveal deadline', now + 60000, now + 90 * 86400000);
  return {
    title: text(data.title, 'Title', 120),
    prompt: text(data.prompt, 'Prompt', 2000),
    sportId: text(data.sportId, 'Sport', 80),
    video, startMs, endMs, references,
    referenceCount: references.length,
    scoreGrades: data.scoreGrades,
    toleranceMs: integer(data.toleranceMs, 'Timing tolerance', 1000, 30000),
    revealAtMs,
  };
}

export function validateAnswers(data, challenge) {
  requireThat(Array.isArray(data) && data.length >= 1 && data.length <= challenge.referenceCount,
    `Submit 1–${challenge.referenceCount} answers.`);
  return data.map((a, i) => ({
    id: `answer-${i + 1}`,
    timestampMs: integer(a.timestampMs, 'Answer time', challenge.startMs, challenge.endMs),
    grade: grade(a.grade),
    explanation: text(a.explanation ?? '', 'Answer explanation', 1000, true),
  }));
}

// Maximum-score one-to-one matching. Greedy nearest-time matching can deny
// credit when reference windows overlap. Ties favor the closest total timing.
export function scoreAnswers(challenge, answers, overrides = {}) {
  const refs = challenge.references;
  const memo = new Map();
  function visit(index, mask) {
    if (index === answers.length) return { score: 0, distance: 0, matches: [] };
    const key = `${index}:${mask}`;
    if (memo.has(key)) return memo.get(key);
    let best = visit(index + 1, mask);
    for (let r = 0; r < refs.length; r++) {
      if (mask & (1 << r)) continue;
      const answer = answers[index];
      const reference = refs[r];
      const override = overrides[answer.id];
      const distance = Math.abs(answer.timestampMs - reference.timestampMs);
      const reserved = Object.entries(overrides).some(([id, refId]) =>
        id !== answer.id && refId === reference.id);
      if (reserved || (override ? override !== reference.id : distance > challenge.toleranceMs)) continue;
      const points = 1 + (challenge.scoreGrades &&
        (override || answer.grade === reference.grade) ? 1 : 0);
      const tail = visit(index + 1, mask | (1 << r));
      const candidate = {
        score: tail.score + points,
        distance: tail.distance + distance,
        matches: [{ answerId: answer.id, referenceId: reference.id, points,
          acceptedByCreator: Boolean(override) }, ...tail.matches],
      };
      if (candidate.score > best.score ||
          (candidate.score === best.score && candidate.distance < best.distance)) best = candidate;
    }
    memo.set(key, best);
    return best;
  }
  const result = visit(0, 0);
  return { score: result.score, maxScore: refs.length * (challenge.scoreGrades ? 2 : 1),
    matches: result.matches };
}

export function canReveal(challenge, submission, now) {
  return Boolean(submission) && (challenge.revealAtMs === null || now >= challenge.revealAtMs);
}

export function publicChallenge(challenge, id, owner = false) {
  const { references, inviteToken, participantIds, ...visible } = challenge;
  return { ...visible, id, isOwner: owner,
    ...(owner ? { references, inviteToken } : {}) };
}

export function publicSubmission(challenge, submission, now, owner = false) {
  if (!submission) return null;
  const { result, overrides, ...visible } = submission;
  return { ...visible, ...(owner || canReveal(challenge, submission, now) ? { result } : {}) };
}
