import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { ChallengeError } from './challenge_domain.js';
import { createChallengeService } from './challenge_service.js';

initializeApp();
const execute = createChallengeService(getFirestore());

export const challenges = onCall({ region: 'us-central1', maxInstances: 3,
  memory: '256MiB', timeoutSeconds: 30 }, async request => {
  try {
    return await execute(request.auth?.uid, request.data);
  } catch (error) {
    if (error instanceof ChallengeError) throw new HttpsError(error.code, error.message);
    console.error('Challenge request failed', error);
    throw new HttpsError('internal', 'Challenges are temporarily unavailable. Please retry.');
  }
});
