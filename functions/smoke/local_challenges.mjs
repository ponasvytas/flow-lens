import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { getAuth } from 'firebase-admin/auth';

// Deliberately fixed to loopback and a demo project; never uses production data.
const project = 'demo-flow-lens-challenges';
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
const endpoint = `http://127.0.0.1:5001/${project}/us-central1/challenges`;
const app = initializeApp({ projectId: project }, 'local-smoke-test');
const db = getFirestore(app);
const accounts = [];
let challengeId;
async function post(url, data, token) {
  const response = await fetch(url, { method: 'POST', signal: AbortSignal.timeout(40000),
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify(data) });
  return { status: response.status, body: await response.json() };
}
async function signup(role) {
  const response = await post(
    'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=local-emulator-key',
    { email: `smoke-${role}-${randomBytes(6).toString('hex')}@example.test`,
      password: randomBytes(20).toString('hex'), returnSecureToken: true });
  assert.equal(response.status, 200, 'Local signup should succeed');
  accounts.push(response.body.localId);
  return response.body.idToken;
}
async function call(token, data) {
  const response = await post(endpoint, { data }, token);
  assert.equal(response.status, 200, JSON.stringify(response.body.error));
  return response.body.result;
}
try {
  const preflight = await fetch(endpoint, { method: 'OPTIONS', headers: {
    Origin: 'http://127.0.0.1:54321', 'Access-Control-Request-Method': 'POST',
    'Access-Control-Request-Headers': 'authorization,content-type',
  } });
  assert.equal(preflight.status, 204);
  assert.ok(preflight.headers.get('access-control-allow-origin'));
  assert.equal((await post(endpoint, { data: { action: 'list' } })).status, 401);
  const coach = await signup('coach');
  const player = await signup('player');
  const created = await call(coach, { action: 'create', requestId: randomBytes(16).toString('hex'), draft: {
    title: 'Local smoke test', prompt: 'Find the good breakout', sportId: 'hockey',
    video: { kind: 'localFile', displayName: 'test-game.mp4', durationMs: 60000 },
    startMs: 0, endMs: 60000, toleranceMs: 5000, scoreGrades: true, revealAtMs: null,
    references: [{ timestampMs: 10000, grade: 'positive', label: 'Breakout', explanation: 'Find the open wing.' }],
  } });
  challengeId = created.challenge.id;
  const joined = await call(player, { action: 'join', id: challengeId, token: created.challenge.inviteToken });
  assert.equal(joined.references, null);
  assert.equal(joined.challenge.inviteToken, undefined);
  const submission = await call(player, { action: 'submit', id: challengeId, displayName: 'Test player',
    videoConfirmed: true, answers: [{ timestampMs: 11000, grade: 'positive', explanation: 'The wing is open.' }] });
  assert.equal(submission.submission.result.score, 2);
  assert.equal(submission.references[0].explanation, 'Find the open wing.');
  const owner = await call(coach, { action: 'get', id: challengeId });
  assert.equal(owner.submissions.length, 1);
  await call(coach, { action: 'revoke', id: challengeId });
  assert.equal((await post(endpoint, { data: { action: 'get', id: challengeId } }, player)).status, 403);
  console.log('PASS: local signup, authenticated callable API, CORS, hidden answers, submission, scoring, review, revocation.');
} finally {
  if (challengeId) await db.recursiveDelete(db.collection('challenges').doc(challengeId));
  for (const uid of accounts) {
    await db.recursiveDelete(db.collection('users').doc(uid));
    await getAuth(app).deleteUser(uid);
  }
  await db.terminate();
  await deleteApp(app);
}
