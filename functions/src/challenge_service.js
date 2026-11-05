import { randomBytes } from 'node:crypto';
import {
  limits, requireThat, validateDraft, validateAnswers, scoreAnswers,
  canReveal, publicChallenge, publicSubmission,
} from './challenge_domain.js';

export function createChallengeService(db, clock = Date.now) {
  const collection = db.collection('challenges');
  function id(value) {
    requireThat(typeof value === 'string' && /^[a-zA-Z0-9_-]{10,100}$/.test(value),
      'Invalid challenge or request ID.');
    return value;
  }
  function access(challenge, uid) {
    requireThat(challenge, 'Challenge not found.', 'not-found');
    const owner = challenge.ownerId === uid;
    requireThat(owner || (!challenge.revoked && challenge.participantIds.includes(uid)),
      'This invitation is unavailable or has been revoked.', 'permission-denied');
    return owner;
  }
  async function detail(ref, uid) {
    // Use a transaction so revocation and submission/reveal state are consistent.
    return db.runTransaction(async tx => {
      const challenge = (await tx.get(ref)).data();
      const owner = access(challenge, uid);
      const submission = (await tx.get(ref.collection('submissions').doc(uid))).data();
      const submissions = owner ? await tx.get(ref.collection('submissions').limit(limits.participants)) : null;
      const now = clock();
      return {
        challenge: publicChallenge(challenge, ref.id, owner),
        submission: publicSubmission(challenge, submission, now, owner),
        references: owner || canReveal(challenge, submission, now) ? challenge.references : null,
        submissions: submissions?.docs.map(d => publicSubmission(challenge, d.data(), now, true)) ?? [],
        serverNowMs: now,
      };
    });
  }
  return async function execute(uid, data) {
    requireThat(typeof uid === 'string' && uid.length > 0, 'Sign in to use challenges.', 'unauthenticated');
    requireThat(data && typeof data === 'object', 'Invalid request.');
    const now = clock();
    if (data.action === 'list') {
      const memberships = await db.collection('users').doc(uid).collection('challengeMemberships')
        .orderBy('createdAtMs', 'desc').limit(50).get();
      const refs = memberships.docs.map(d => collection.doc(d.id));
      const snapshots = refs.length ? await db.getAll(...refs) : [];
      return { challenges: snapshots.filter(d => d.exists).map(d => ({ id: d.id, ...d.data() }))
        .filter(c => c.ownerId === uid || (!c.revoked && c.participantIds.includes(uid)))
        .map(c => ({ id: c.id, title: c.title, isOwner: c.ownerId === uid, revoked: c.revoked,
          createdAtMs: c.createdAtMs, referenceCount: c.referenceCount, revealAtMs: c.revealAtMs })) };
    }
    if (data.action === 'create') {
      const draft = validateDraft(data.draft, now);
      const requestId = id(data.requestId);
      const ref = collection.doc();
      const receipt = db.collection('users').doc(uid).collection('challengeRequests').doc(requestId);
      const quota = db.collection('users').doc(uid).collection('challengeUsage').doc('current');
      const challengeId = await db.runTransaction(async tx => {
        const existing = await tx.get(receipt);
        if (existing.exists) return existing.data().challengeId;
        const usage = (await tx.get(quota)).data() ?? { active: 0 };
        requireThat(usage.active < limits.active, `You can have ${limits.active} active challenges. Revoke one to create another.`, 'resource-exhausted');
        tx.create(ref, { ...draft, ownerId: uid, createdAtMs: now, revoked: false,
          participantIds: [], inviteToken: randomBytes(24).toString('base64url') });
        tx.set(quota, { active: usage.active + 1 });
        tx.create(receipt, { challengeId: ref.id });
        tx.set(db.collection('users').doc(uid).collection('challengeMemberships').doc(ref.id), { createdAtMs: now });
        return ref.id;
      });
      return detail(collection.doc(challengeId), uid);
    }
    const ref = collection.doc(id(data.id));
    if (data.action === 'join') {
      requireThat(typeof data.token === 'string' && /^[\w-]{32}$/.test(data.token), 'Invalid invitation.');
      await db.runTransaction(async tx => {
        const challenge = (await tx.get(ref)).data();
        requireThat(challenge && !challenge.revoked && challenge.inviteToken === data.token,
          'This invitation is unavailable or has been revoked.', 'permission-denied');
        if (challenge.ownerId === uid || challenge.participantIds.includes(uid)) return;
        requireThat(challenge.revealAtMs === null || now < challenge.revealAtMs,
          'This challenge has closed.', 'failed-precondition');
        requireThat(challenge.participantIds.length < limits.participants, 'This challenge is full.', 'resource-exhausted');
        tx.update(ref, { participantIds: [...challenge.participantIds, uid] });
        tx.set(db.collection('users').doc(uid).collection('challengeMemberships').doc(ref.id), { createdAtMs: now });
      });
      return detail(ref, uid);
    }
    if (data.action === 'get') return detail(ref, uid);
    if (data.action === 'submit') {
      await db.runTransaction(async tx => {
        const challenge = (await tx.get(ref)).data();
        const owner = access(challenge, uid);
        requireThat(!owner, 'Creators cannot submit to their own challenge.', 'failed-precondition');
        const submissionRef = ref.collection('submissions').doc(uid);
        const existing = await tx.get(submissionRef);
        // Retries after a lost response return the original immutable attempt.
        if (existing.exists) return;
        requireThat(challenge.revealAtMs === null || now < challenge.revealAtMs,
          'The deadline has passed.', 'failed-precondition');
        const answers = validateAnswers(data.answers, challenge);
        requireThat(data.videoConfirmed === true, 'Confirm that you have the same recording and cut.');
        requireThat(typeof data.displayName === 'string' && data.displayName.trim().length >= 1 &&
          data.displayName.trim().length <= 60, 'Enter your name (1–60 characters).');
        tx.create(submissionRef, { userId: uid, displayName: data.displayName.trim(), answers,
          submittedAtMs: now, overrides: {}, result: scoreAnswers(challenge, answers) });
      });
      return detail(ref, uid);
    }
    if (data.action === 'review') {
      requireThat(typeof data.userId === 'string' && /^[\w-]{1,128}$/.test(data.userId), 'Invalid participant.');
      await db.runTransaction(async tx => {
        const challenge = (await tx.get(ref)).data();
        requireThat(access(challenge, uid), 'Only the creator can review answers.', 'permission-denied');
        const submissionRef = ref.collection('submissions').doc(data.userId);
        const submission = (await tx.get(submissionRef)).data();
        requireThat(submission, 'Submission not found.', 'not-found');
        requireThat(submission.answers.some(a => a.id === data.answerId) &&
          challenge.references.some(r => r.id === data.referenceId), 'Choose an answer and reference moment.');
        const overrides = { ...submission.overrides };
        for (const [answerId, referenceId] of Object.entries(overrides)) {
          if (referenceId === data.referenceId) delete overrides[answerId];
        }
        overrides[data.answerId] = data.referenceId;
        tx.update(submissionRef, { overrides, reviewedAtMs: now,
          result: scoreAnswers(challenge, submission.answers, overrides) });
      });
      return detail(ref, uid);
    }
    if (data.action === 'revoke') {
      await db.runTransaction(async tx => {
        const challenge = (await tx.get(ref)).data();
        requireThat(access(challenge, uid), 'Only the creator can revoke this challenge.', 'permission-denied');
        if (challenge.revoked) return;
        const quota = db.collection('users').doc(uid).collection('challengeUsage').doc('current');
        const usage = (await tx.get(quota)).data();
        tx.update(ref, { revoked: true, inviteToken: null });
        tx.set(quota, { active: Math.max(0, (usage?.active ?? 1) - 1) });
      });
      return detail(ref, uid);
    }
    requireThat(false, 'Unknown challenge action.');
  };
}
