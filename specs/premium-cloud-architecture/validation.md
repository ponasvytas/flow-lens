# Validation

Each implementation phase should record validation here. This spec file defines
the expected checks before production rollout.

## Documentation validation

- Spec files exist for README, decisions, data model, security, billing,
  video policy, validation, and every phase.
- Open decisions are listed instead of hidden inside implementation prose.
- Uploaded video remains explicitly deferred until quota and policy controls are
  designed.

## Local app validation

Run after each implementation phase:

```bash
flutter analyze
flutter test
```

Also manually smoke-test:

- Anonymous free web loads without login.
- Existing local video loading still works.
- Existing JSON event import/export still works.
- Existing tracking session import/export still works.
- Settings still load and save locally when cloud is unavailable or disabled.

## Repository contract validation

Repository implementations should share behavior tests where practical:

- Local settings repository.
- Cloud settings repository.
- Hybrid local-cache plus cloud repository.
- Event session repository.
- Tracking session repository.
- Taxonomy repository.

## Firebase validation

Use Firebase emulators before production:

- Auth emulator for signed-in and anonymous states.
- Firestore emulator for user data and review-link rules.
- Storage emulator before uploaded-video support.
- Functions emulator for privileged entitlement and share-link operations.

Security rule tests should verify both allowed and denied paths.

## Platform validation

Before enabling premium features broadly, manually validate:

- Free web anonymous flow.
- Premium web login and cloud settings sync.
- iOS login and entitlement recognition.
- Android login and entitlement recognition.
- Offline startup with cached settings/session metadata.
- Review-link viewer flow in a fresh browser profile.

## Migration validation

- Existing event JSON files still import.
- Existing tracking JSON files still import.
- Existing settings keys remain compatible or migrate cleanly.
- Built-in taxonomy assets continue to load for free users.

## Validation record

### 2026-08-09 - Phases 00 and 01

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 52 tests passed.
- `flutter build web`: passed, including the WebAssembly dry run.
- Manual anonymous/free web smoke test: passed by user confirmation.

### 2026-08-09 - Phase 02 app implementation

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 55 tests passed.
- `flutter build web`: passed, including the WebAssembly dry run.
- Firebase email/password project validation: pending.
- Firestore rules harness: added under `firebase-rules-tests/`; JavaScript and
  Firebase configuration syntax checks pass.
- Firestore security-rules emulator execution: blocked because Java is not
  installed or available on `PATH`.

### 2026-08-09 - Phase 03 app implementation

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 60 tests passed.
- `flutter build web`: passed, including the WebAssembly dry run.
- Firestore rules/configuration and JavaScript harness syntax checks: passed.
- Manual premium cloud and multi-device settings validation: pending.
- Firestore emulator execution: blocked because Java is unavailable.

### 2026-08-09 - Phase 04 app implementation

- `dart format lib test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: all 65 tests passed.
- `flutter build web`: passed, including the WebAssembly dry run.
- Firebase rules harness, hosting configuration, and Firestore index JSON
  syntax checks: passed.
- Manual premium event/tracking session validation: pending.
- Firestore emulator execution: blocked because Java is unavailable.
