# Phase 02 - Auth and entitlements

## Objective

Add authenticated account state and backend-backed premium capability checks
without moving user data to the cloud yet.

## Prerequisites

- Phase 01 service composition is complete.
- Firebase project configuration is confirmed for web, iOS, and Android.
- Billing direction is recorded in [../billing-entitlements.md](../billing-entitlements.md).

## Implementation

- Add Firebase Auth as the first account provider.
- Add an `AuthRepository` implementation for current user state.
- Add an `EntitlementsRepository` that reads backend entitlement state.
- Add a capability layer that maps auth and entitlement state to app features.
- Keep anonymous free web usable without signing in.
- Do not let clients self-grant premium entitlements.

The initial provider is Firebase email/password authentication. Purchase flows
remain out of scope; until billing is implemented, entitlement documents must
be provisioned by a trusted backend or administrator.

## API changes

- Auth user model for app-level identity.
- Entitlement model for backend-backed capabilities.
- Capability model for UI and repository gates.

## Failure handling

- Auth unavailable: app falls back to anonymous/free local behavior.
- Entitlement unavailable: premium writes are disabled until state is known.
- Signed-out user: no cloud writes are attempted.

## Tests

- Auth/account controller unit tests with fake auth and entitlement state pass.
- Capability mapping tests cover signed-out, premium, expired, and unavailable
  entitlement states.
- Firebase emulator tests for entitlement read/write restrictions once rules
  exist.

## Acceptance checklist

- [x] Anonymous free web still works without login.
- [x] Premium capability checks are not platform-only checks.
- [x] Entitlement truth is backend-owned.
- [x] iOS can support free install plus premium login/subscription.
- [x] No cloud user-data migration has happened yet.

## Validation status

The Flutter implementation and automated app tests are complete. Before this
phase is closed, enable Email/Password in Firebase Auth, manually validate
create/sign-in/reset/sign-out against the configured project, and run Firestore
rules tests in the emulator. The rules harness is in `firebase-rules-tests/`,
but the current machine cannot start the emulator because Java is unavailable.
Missing, expired, unknown, or unreadable entitlements fail closed to local/free
capabilities.
