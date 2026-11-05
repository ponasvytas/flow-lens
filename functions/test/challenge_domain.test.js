import test from 'node:test';
import assert from 'node:assert/strict';
import { validateDraft, validateAnswers, scoreAnswers, canReveal,
  publicChallenge, publicSubmission } from '../src/challenge_domain.js';

export const now = 1700000000000;
export function draft(overrides = {}) {
  return { title: 'Read the breakout', prompt: 'Find my two breakouts', sportId: 'hockey',
    video: { kind: 'localFile', displayName: 'game.mp4', durationMs: 120000 },
    startMs: 0, endMs: 120000, toleranceMs: 5000, scoreGrades: true, revealAtMs: null,
    references: [
      { timestampMs: 10000, grade: 'positive', label: 'Breakout', explanation: 'Find the open wing.' },
      { timestampMs: 30000, grade: 'negative', label: 'Breakout', explanation: 'The middle was covered.' },
    ], ...overrides };
}

test('snapshots whitelist fields and omit local paths', () => {
  const source = draft();
  source.video.path = 'C:/private/game.mp4';
  source.references[0].secret = 'not part of the snapshot';
  const valid = validateDraft(source, now);
  assert.equal(valid.video.path, undefined);
  assert.equal(valid.references[0].secret, undefined);
  assert.equal(valid.referenceCount, 2);
  assert.equal(valid.references[0].id, 'moment-1');
});

test('rejects unsafe video schemes, invalid ranges, excessive size and bad deadlines', () => {
  for (const url of ['file:///secret', 'javascript:alert(1)', 'https://user:pass@host/video']) {
    assert.throws(() => validateDraft(draft({ video: { kind: 'externalUrl', displayName: 'game',
      durationMs: 120000, externalUrl: url } }), now));
  }
  for (const overrides of [{ startMs: 20000 }, { endMs: 0 }, { revealAtMs: now },
    { toleranceMs: 0 }, { title: 'x'.repeat(121) }, { references: Array(13).fill(draft().references[0]) }]) {
    assert.throws(() => validateDraft(draft(overrides), now));
  }
  assert.throws(() => validateDraft(draft({ references: [draft().references[0], draft().references[0]] }), now));
});

test('scores time and classification separately, with inclusive timing tolerance', () => {
  const challenge = validateDraft(draft(), now);
  const answers = validateAnswers([
    { timestampMs: 15000, grade: 'positive' },
    { timestampMs: 30000, grade: 'positive' },
  ], challenge);
  const result = scoreAnswers(challenge, answers);
  assert.equal(result.score, 3);
  assert.equal(result.maxScore, 4);
  assert.equal(result.matches.length, 2);
  assert.throws(() => validateAnswers([...answers, answers[0]], challenge));
  assert.throws(() => validateAnswers([{ timestampMs: -1, grade: null }], challenge));
});

test('repeated tags cannot score one reference twice', () => {
  const challenge = validateDraft(draft(), now);
  const answers = validateAnswers([{ timestampMs: 10000, grade: 'positive' },
    { timestampMs: 10000, grade: 'positive' }], challenge);
  assert.equal(scoreAnswers(challenge, answers).score, 2);
});

test('overlapping windows use the best one-to-one matching rather than greedy order', () => {
  const challenge = validateDraft(draft({ scoreGrades: false, references: [
    { ...draft().references[0], timestampMs: 10000 },
    { ...draft().references[1], timestampMs: 16000 },
  ] }), now);
  const answers = validateAnswers([{ timestampMs: 12000, grade: null },
    { timestampMs: 5000, grade: null }], challenge);
  assert.equal(scoreAnswers(challenge, answers).score, 2);
});

test('creator acceptance awards one reference and does not allow double counting', () => {
  const challenge = validateDraft(draft(), now);
  const answers = validateAnswers([{ timestampMs: 90000, grade: 'negative' },
    { timestampMs: 10000, grade: 'positive' }], challenge);
  const result = scoreAnswers(challenge, answers, { 'answer-1': 'moment-1' });
  assert.equal(result.score, 2);
  assert.equal(result.matches[0].answerId, 'answer-1');
  assert.equal(result.matches[0].acceptedByCreator, true);
});

test('no answers, tokens, membership or results leak before reveal', () => {
  const challenge = { ...validateDraft(draft({ revealAtMs: now + 120000 }), now),
    inviteToken: 'private', participantIds: ['a', 'b'] };
  const visible = publicChallenge(challenge, 'challenge-id');
  for (const key of ['references', 'inviteToken', 'participantIds']) assert.equal(visible[key], undefined);
  const submission = { answers: [], overrides: { a: 'b' }, result: { score: 4 } };
  assert.equal(canReveal(challenge, null, now + 200000), false);
  assert.equal(canReveal(challenge, submission, now), false);
  assert.equal(publicSubmission(challenge, submission, now).result, undefined);
  assert.equal(publicSubmission(challenge, submission, now).overrides, undefined);
  assert.deepEqual(publicSubmission(challenge, submission, now + 120000).result, { score: 4 });
  assert.deepEqual(publicSubmission(challenge, submission, now, true).result, { score: 4 });
});
