import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { createChallengeService } from '../src/challenge_service.js';

// Never fall back to production credentials for integration tests.
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'Run this suite inside firebase emulators:exec.');
const app = initializeApp({ projectId: 'demo-flow-lens-challenges' });
const db = getFirestore(app);
let now = 1700000000000;
const service = createChallengeService(db, () => now);
let seq = 0;
const draft = (extra = {}) => ({
  title: 'Read the breakout', prompt: 'Find my good breakout', sportId: 'hockey',
  video: { kind: 'localFile', displayName: 'game.mp4', durationMs: 120000 },
  startMs: 0, endMs: 120000, toleranceMs: 5000, scoreGrades: true, revealAtMs: null,
  references: [{ timestampMs: 10000, grade: 'positive', label: 'Breakout', explanation: 'Find the open wing.' }],
  ...extra,
});
const create = (uid, extra = {}, requestId = `request-${String(++seq).padStart(8, '0')}`) =>
  service(uid, { action: 'create', requestId, draft: draft(extra) });
const join = (uid, detail) => service(uid, { action: 'join', id: detail.challenge.id, token: detail.challenge.inviteToken });
const submit = (uid, detail, extra = {}) => service(uid, { action: 'submit', id: detail.challenge.id,
  displayName: 'Sam', videoConfirmed: true, answers: [{ timestampMs: 10000, grade: 'positive', explanation: 'Open wing.' }], ...extra });

before(async () => {
  await db.recursiveDelete(db.collection('challenges'));
  await db.recursiveDelete(db.collection('users'));
});
after(async () => { await db.terminate(); await deleteApp(app); });

test('authentication and membership required; IDs alone cannot expose challenges', async () => {
  await assert.rejects(() => service(null, { action: 'list' }), { code: 'unauthenticated' });
  const created = await create('owner-access');
  await assert.rejects(() => service('stranger', { action: 'get', id: created.challenge.id }), { code: 'permission-denied' });
  await assert.rejects(() => service('stranger', { action: 'join', id: created.challenge.id, token: 'z'.repeat(32) }), { code: 'permission-denied' });
  const joined = await join('player-access', created);
  assert.equal(joined.references, null);
  assert.equal(joined.challenge.references, undefined);
  assert.equal(joined.challenge.inviteToken, undefined);
  assert.equal(joined.challenge.participantIds, undefined);
  assert.deepEqual(joined.submissions, []);
  const list = await service('player-access', { action: 'list' });
  assert.equal(list.challenges.length, 1);
  assert.equal(list.challenges[0].references, undefined);
});

test('submit scores on server, reveals answers, and cannot be replaced or forged', async () => {
  const created = await create('owner-submit');
  await join('player-submit', created);
  await assert.rejects(() => submit('owner-submit', created), { code: 'failed-precondition' });
  await assert.rejects(() => submit('player-submit', created, { videoConfirmed: false }), { code: 'invalid-argument' });
  const result = await submit('player-submit', created, { result: { score: 999 } });
  assert.equal(result.submission.result.score, 2);
  assert.equal(result.references[0].explanation, 'Find the open wing.');
  const retry = await submit('player-submit', created, { answers: [{ timestampMs: 90000, grade: 'negative' }] });
  assert.equal(retry.submission.answers[0].timestampMs, 10000);
  assert.equal(retry.submission.result.score, 2);
  const owner = await service('owner-submit', { action: 'get', id: created.challenge.id });
  assert.equal(owner.submissions.length, 1);
  await join('another-player', created);
  const other = await service('another-player', { action: 'get', id: created.challenge.id });
  assert.deepEqual(other.submissions, []);
  assert.equal(other.references, null);
});

test('deadline withholds score and reference answers until server time, then closes submission', async () => {
  const created = await create('owner-deadline', { revealAtMs: now + 120000 });
  await join('player-deadline', created);
  await join('late-player', created);
  const waiting = await submit('player-deadline', created);
  assert.equal(waiting.references, null);
  assert.equal(waiting.submission.result, undefined);
  now += 120000;
  const revealed = await service('player-deadline', { action: 'get', id: created.challenge.id });
  assert.equal(revealed.submission.result.score, 2);
  assert.equal(revealed.references.length, 1);
  await assert.rejects(() => submit('late-player', created), { code: 'failed-precondition' });
  await assert.rejects(() => join('new-late-player', created), { code: 'failed-precondition' });
});

test('only creator can accept alternatives or revoke, and revoke blocks joined users', async () => {
  const created = await create('owner-review');
  await join('player-review', created);
  await submit('player-review', created, { answers: [{ timestampMs: 90000, grade: 'negative' }] });
  const request = { action: 'review', id: created.challenge.id, userId: 'player-review',
    answerId: 'answer-1', referenceId: 'moment-1' };
  await assert.rejects(() => service('player-review', request), { code: 'permission-denied' });
  const reviewed = await service('owner-review', request);
  assert.equal(reviewed.submissions[0].result.score, 2);
  await assert.rejects(() => service('player-review', { action: 'revoke', id: created.challenge.id }), { code: 'permission-denied' });
  await service('owner-review', { action: 'revoke', id: created.challenge.id });
  await assert.rejects(() => service('player-review', { action: 'get', id: created.challenge.id }), { code: 'permission-denied' });
  await assert.rejects(() => join('new-player', created), { code: 'permission-denied' });
  assert.equal((await service('player-review', { action: 'list' })).challenges.length, 0);
});

test('create retry is idempotent and concurrent creates cannot exceed quota', async () => {
  const original = await create('owner-quota', {}, 'retry-request-123');
  const retry = await create('owner-quota', {}, 'retry-request-123');
  assert.equal(original.challenge.id, retry.challenge.id);
  const results = await Promise.allSettled(Array.from({ length: 7 }, () => create('owner-quota')));
  assert.equal(results.filter(r => r.status === 'fulfilled').length, 4);
  assert.equal(results.filter(r => r.status === 'rejected').length, 3);
  await service('owner-quota', { action: 'revoke', id: original.challenge.id });
  await service('owner-quota', { action: 'revoke', id: original.challenge.id });
  await create('owner-quota');
  await assert.rejects(() => create('owner-quota'), { code: 'resource-exhausted' });
});

test('participant capacity is enforced on the server', async () => {
  const created = await create('owner-capacity');
  for (let i = 0; i < 30; i++) await join(`capacity-player-${i}`, created);
  await join('capacity-player-0', created);
  await assert.rejects(() => join('capacity-overflow', created), { code: 'resource-exhausted' });
});
