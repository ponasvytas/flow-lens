import fs from 'node:fs';
import path from 'node:path';
import test, { after, before, beforeEach } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  deleteDoc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const directory = path.dirname(fileURLToPath(import.meta.url));
const rules = fs.readFileSync(path.join(directory, '..', 'firestore.rules'), 'utf8');
let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'flow-lens-rules-test',
    firestore: { rules },
  });
});

beforeEach(async () => environment.clearFirestore());
after(async () => environment.cleanup());

test('anonymous users cannot read private entitlements', async () => {
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'users/user-a/entitlements/current')));
});

test('users can read only their own entitlement', async () => {
  const ownerDb = environment.authenticatedContext('user-a').firestore();
  await assertSucceeds(
    getDoc(doc(ownerDb, 'users/user-a/entitlements/current')),
  );
  await assertFails(
    getDoc(doc(ownerDb, 'users/user-b/entitlements/current')),
  );
});

test('clients cannot create or modify entitlements', async () => {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'users/user-a/entitlements/current'),
      { tier: 'premium', status: 'active' },
    );
  });
  const db = environment.authenticatedContext('user-a').firestore();
  const entitlement = doc(db, 'users/user-a/entitlements/current');
  await assertFails(
    setDoc(entitlement, { tier: 'premium', status: 'active' }),
  );
  await assertFails(updateDoc(entitlement, { status: 'inactive' }));
});

async function grantPremium(userId) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `users/${userId}/entitlements/current`),
      { tier: 'premium', status: 'active' },
    );
  });
}

function validSettings() {
  return {
    schemaVersion: 1,
    fastPlaySpeed: 3.0,
    slowPlaybackSpeed: 0.5,
    defaultPlaybackSpeed: 1.0,
    leadInSeconds: 10,
    leadOutSeconds: 10,
    updatedAt: serverTimestamp(),
  };
}

test('premium users can read and write their own valid settings', async () => {
  await grantPremium('user-a');
  const db = environment.authenticatedContext('user-a').firestore();
  const preferences = doc(db, 'users/user-a/preferences/default');
  await assertSucceeds(setDoc(preferences, validSettings()));
  await assertSucceeds(getDoc(preferences));
});

test('free, anonymous, and cross-user settings access is denied', async () => {
  await grantPremium('user-a');
  const freeDb = environment.authenticatedContext('free-user').firestore();
  const otherDb = environment.authenticatedContext('user-b').firestore();
  const anonymousDb = environment.unauthenticatedContext().firestore();

  await assertFails(
    setDoc(doc(freeDb, 'users/free-user/preferences/default'), validSettings()),
  );
  await assertFails(
    getDoc(doc(otherDb, 'users/user-a/preferences/default')),
  );
  await assertFails(
    getDoc(doc(anonymousDb, 'users/user-a/preferences/default')),
  );
});

test('malformed premium settings writes are denied', async () => {
  await grantPremium('user-a');
  const db = environment.authenticatedContext('user-a').firestore();
  await assertFails(
    setDoc(doc(db, 'users/user-a/preferences/default'), {
      ...validSettings(),
      fastPlaySpeed: 99,
    }),
  );
});

function ownedFields(userId, sessionId) {
  return {
    sessionId,
    schemaVersion: 1,
    title: 'Game review',
    sportId: 'hockey',
    sourceVideo: { kind: 'localFile', displayName: 'game.mp4' },
    ownerType: 'user',
    ownerId: userId,
    createdByUserId: userId,
    updatedByUserId: userId,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    archivedAt: null,
  };
}

function eventSession(userId, sessionId) {
  return {
    ...ownedFields(userId, sessionId),
    taxonomyId: 'built-in:hockey',
    taxonomyRevision: 1,
    taxonomySnapshot: { schemaVersion: 1, sportId: 'hockey' },
    events: [],
  };
}

function trackingSession(userId, sessionId) {
  return {
    ...ownedFields(userId, sessionId),
    trackingSession: {
      id: 'local-session',
      createdAt: '2026-08-09T00:00:00.000Z',
      subjects: [],
      trackers: [],
      events: [],
    },
  };
}

test('premium owners can create, update, read, and delete sessions', async () => {
  await grantPremium('user-a');
  const db = environment.authenticatedContext('user-a').firestore();
  const eventRef = doc(db, 'users/user-a/eventSessions/event-1');
  const trackingRef = doc(db, 'users/user-a/trackingSessions/tracking-1');

  await assertSucceeds(setDoc(eventRef, eventSession('user-a', 'event-1')));
  await assertSucceeds(
    setDoc(trackingRef, trackingSession('user-a', 'tracking-1')),
  );
  await assertSucceeds(updateDoc(eventRef, {
    title: 'Updated review',
    updatedByUserId: 'user-a',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(eventRef));
  await assertSucceeds(deleteDoc(trackingRef));
});

test('free and cross-user session access is denied', async () => {
  await grantPremium('user-a');
  const freeDb = environment.authenticatedContext('free-user').firestore();
  const otherDb = environment.authenticatedContext('user-b').firestore();
  await assertFails(
    setDoc(
      doc(freeDb, 'users/free-user/eventSessions/event-1'),
      eventSession('free-user', 'event-1'),
    ),
  );
  await assertFails(
    getDoc(doc(otherDb, 'users/user-a/eventSessions/event-1')),
  );
});

test('session owners cannot mutate immutable ownership fields', async () => {
  await grantPremium('user-a');
  const db = environment.authenticatedContext('user-a').firestore();
  const reference = doc(db, 'users/user-a/eventSessions/event-1');
  await assertSucceeds(
    setDoc(reference, eventSession('user-a', 'event-1')),
  );
  await assertFails(updateDoc(reference, {
    ownerId: 'user-b',
    updatedByUserId: 'user-a',
    updatedAt: serverTimestamp(),
  }));
});
