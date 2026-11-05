# Find the play challenges

The first challenge workflow is free for authenticated accounts. Any coach or
player can create a challenge from existing analysis events, invite participants,
review submissions, and accept alternative answers. Participants load their own
copy of a video or open its direct HTTP(S) media URL. Flow Lens does not upload,
transcode, store, or deliver video for this feature.

## Using it

1. Load a video in the analysis workspace and tag the reference moments.
2. Optionally select the events to use in the events table.
3. Open **App menu → Challenges → Create from current events**.
4. Select 1–12 moments, add a prompt and explanations, and choose a search range,
   timing tolerance, classification scoring, and optional deadline.
5. Create the challenge and copy its invitation link. Send it using your normal
   messaging tool. The app does not send messages automatically.
6. Participants sign in with free accounts, open the invitation, load the video,
   confirm the recording/cut, and tag answers while watching.
7. A participant submits once. Feedback appears immediately or after the deadline.
   Participants can create a new challenge from their submitted moments using
   **Challenge back with your moments**, then share the new invitation.
8. Creators refresh their challenge to see submissions. **Accept alternative**
   awards full credit for a specified reference moment. Revoking a challenge
   disables further participant access and frees an active challenge slot.

Joining via a copied link works on web. Native apps can open the same invitation
using the link field in Challenges; OS-level universal/app links are not configured.
Use a direct playable video URL, not a YouTube page or generic drive sharing page.
Playback depends on browser CORS, media codecs, provider access, and seek support.
Signed video URLs can expire; participants can fall back to a local copy.

## Rules and data

- Five active challenges per creator; 30 participants per challenge; 12 moments
  per challenge. Limits apply in backend transactions, including concurrent joins
  and creates. A passed deadline does not free a slot: revoke the challenge.
- The challenge holds a whitelisted snapshot, not a live reference to analysis
  events. Local filesystem paths, drawings, and unrelated event context are excluded.
- Matching uses maximum-score one-to-one assignment within the selected tolerance.
  Overlapping windows cannot cause greedy matching to unfairly lose points.
- One point for a matched moment; an optional additional point for good/bad/neutral
  classification. Ties prefer smaller total timestamp differences. No speed points.
- Creator acceptance reserves a reference for the accepted answer and recomputes
  the result without double counting. This can replace an earlier match.
- Only submitted participants receive references, and only once the reveal time
  permits it. Unsubmitted participants never receive the answer key.
- Retried creation uses a request receipt; retried submission returns the original
  immutable attempt. Failed network requests do not clear local answer drafts.
- Draft participant answers are held in memory. Leaving warns before discarding;
  refreshing/closing the browser does not preserve an unsubmitted draft.
- Local video validation compares duration within two seconds and requires an
  explicit same-cut confirmation. It does not prove identical footage. Video
  offsets, fingerprints, and alternate edits are future work.

`functions/src/challenge_service.js` implements the authenticated operations:
`list`, `create`, `join`, `get`, `submit`, `review`, and `revoke`.
`functions/src/challenge_domain.js` validates snapshots and computes scores.
`lib/services/challenge_repository.dart` calls the Firebase callable protocol using
the signed-in user's ID token. No premium entitlement is required.

Firestore paths (all denied to direct client reads/writes):

```
challenges/{challengeId}
challenges/{challengeId}/submissions/{userId}
users/{userId}/challengeMemberships/{challengeId}
users/{userId}/challengeRequests/{requestId}
users/{userId}/challengeUsage/current
```

The callable backend uses the Admin SDK and explicitly checks identity,
membership, ownership, deadlines, and revocation. Reference answers are never
sent in participant challenge payloads before release, and scores are computed
on the backend. Participants cannot read each other's submissions. Creator-only
responses include the invitation secret so the creator can copy it again.
Invitation tokens use 192 bits of cryptographic randomness, live only in private
backend data, and travel in the URL fragment rather than the query string. Tokens
must not be logged. Invitations are bearer invitations: anyone with the complete
link and an account can join until capacity, deadline, or revocation stops them.

The dashboard shows the latest 50 memberships. No public directory, leaderboard,
chat, analytics history, notifications, automatic cleanup, or video hosting is
included in this version.

## Configuration and deployment

### Local development without billing

Use local mode to test the whole flow without deploying Functions or enabling
billing. It uses the fixed `demo-flow-lens-challenges` project and a separate named
Firebase app. Authentication, Firestore, and Functions all use loopback emulators.
Production API/share URL overrides are ignored in this mode. If initialization
fails, the app does not fall back to production Firebase.

Prerequisites: Flutter, Node (22 recommended), Firebase CLI, Java 21+, and
`npm.cmd --prefix functions ci`. The Windows launcher also recognizes the Java
runtime in `.local/challenge-jre` if installed during setup.

Start the backend in one terminal:

```powershell
.\scripts\start-local-backend.ps1
```

Start the app in another:

```powershell
.\scripts\start-local-app.ps1
```

Open http://127.0.0.1:54321/. The app has a **LOCAL** banner. Create a local account;
your live Firebase account is separate and will not sign in here unless you also
create a local account with those credentials (use a test password). Use a second
browser profile/private window for the player account. Invitations point to the
same local web app. These loopback links work on this computer only.

The backend dashboard is http://127.0.0.1:4000/. You can inspect local accounts,
Firestore records and emulator logs there. Challenge answer documents are private
from the client app, but accessible to you as the emulator administrator.

Stop the backend with Ctrl+C once and wait for export to finish. Accounts and
challenge data are saved to `.local/firebase-data` and imported on the next start.
This ignored folder can contain test passwords and answer keys; do not commit it.
An abrupt process kill may lose changes since the last export. To save while the
backend is running, use `firebase emulators:export .local/firebase-data --project
demo-flow-lens-challenges --force`.

Equivalent cross-platform commands (Java must be on PATH):

```sh
firebase emulators:start --only auth,firestore,functions --project demo-flow-lens-challenges --export-on-exit=.local/firebase-data
flutter run -d web-server --web-port=54321 --web-hostname=127.0.0.1 --dart-define=USE_FIREBASE_EMULATORS=true
```

Add `--import=.local/firebase-data` once an export exists. For the Windows app,
use `.\scripts\start-local-app.ps1 -Device windows`; the web app must also be running
to open invitation links in a browser. Switching backend mode requires a full
restart using the appropriate launch command, not a hot reload of an existing
production session. Plain `flutter run` continues to use production Firebase.

With all three emulators running, `npm.cmd --prefix functions run test:local`
checks local signup plus the real authenticated HTTP challenge flow. It creates
and removes only its own temporary test accounts and challenges. Run destructive
database-isolation integration/rules tests in a separate emulator session, not
against your persistent development data.

### Production deployment

The code is deployable but implementation/testing does not deploy it. Use Node 22
for Firebase Functions. A Firebase billing-enabled project is required to deploy
Functions; free accounts in the product still create backend costs.

```
cd functions
npm ci
npm test
cd ..
firebase deploy --only functions:challenges
flutter build web
firebase deploy --only hosting:flow-lens-player
```

The checked-in Firestore rules already default-deny all challenge paths. Do not
add direct client permissions for these collections. Existing rules should be
deployed to any new Firebase environment before use. Sign-in requires the existing
Firebase email/password provider to be enabled.

Defaults:

- API: `https://us-central1-<Firebase projectId>.cloudfunctions.net/challenges`
- Share URL: `https://flow-lens-player.web.app/`

Override with `--dart-define=CHALLENGE_API_URL=...` and
`--dart-define=CHALLENGE_SHARE_URL=...` for staging or a different host. The hosting
SPA rewrite already supports the challenge query parameter. HTTP(S) video URLs
are used only by the video player; the backend does not fetch arbitrary URLs.

The function has `maxInstances: 3`, bounded request data and response sizes, and
transactional capacity limits. These do not constitute a hard billing cap or
prevent account farming. Before a public rollout, choose billing alerts, retention,
and abuse controls based on the pilot. Start with invited users and existing video
sources to measure metadata/backend costs separately from video hosting.

## Validation

```
dart format lib test
flutter analyze
flutter test
cd functions
npm test
cd ..
firebase emulators:exec --only firestore --project demo-flow-lens-challenges "node --test functions/integration/challenge_service.test.js"
firebase emulators:exec --only firestore --project demo-flow-lens-challenges "npm --prefix firebase-rules-tests test"
```

The emulator needs Java 21+. Integration tests refuse to run without
`FIRESTORE_EMULATOR_HOST` and use a demo project, never production data. They cover
membership privacy, authoritative scoring, immutable submissions, deadlines,
creator review, revocation, create retries, and concurrent quotas. Rules tests
check that direct client access to answers, results, memberships, and quotas fails.
Flutter tests cover invitation parsing, request transport, notifier lifecycle,
withheld/revealed UI states, form validation, and phone portrait/landscape layouts
with enlarged text.

For a manual pilot, use two separate signed-in browser profiles and a short,
non-sensitive MP4. Create a challenge in one, join and submit in the other, then
verify reveal and creator review. Repeat with a delayed reveal and revocation.
Verify your actual hosted-video provider separately; direct URL playback is not a
guarantee of compatibility with every host or codec.
