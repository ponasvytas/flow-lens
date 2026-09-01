# Phase 03 - Cloud settings sync

## Objective

Implement the first low-risk cloud-backed vertical slice by syncing app settings
for premium users.

## Prerequisites

- Phase 02 auth and entitlements are complete.
- Firestore rules for user preferences are drafted and tested in emulator.
- Existing `SettingsRepository` behavior is preserved.

## Implementation

- Add a cloud `SettingsRepository` implementation.
- Optionally add a hybrid repository that reads local settings first and syncs
  cloud state when available.
- Preserve existing local settings keys for anonymous/free usage.
- Define conflict behavior for first sign-in and multi-device updates.
- Keep `AppSettings` schema migration explicit.

The implemented hybrid repository always loads local settings first. Once an
authenticated account has an active premium entitlement, it reconciles with
Firestore. Existing cloud settings win and refresh the local cache; if the
cloud document is missing, current local settings seed it. Subsequent writes
use last-write-wins with a server `updatedAt` timestamp.

## API changes

`SettingsRepository` may need watch/stream support if live cross-device updates
are required. If not required for MVP, keep the existing load/save contract.

## Failure handling

- Cloud read failure: use local cache/defaults and surface non-blocking status.
- Cloud write failure: keep local value and retry only if a sync queue exists.
- Conflict: last-write-wins is acceptable for MVP if documented.

## Tests

- Existing settings controller tests pass.
- Local repository tests pass.
- Cloud repository tests run against Firestore emulator or fake Firestore.
- Security rules deny cross-user settings access.

## Acceptance checklist

- [x] Free users keep local settings only.
- [x] Premium users can load and save settings from cloud.
- [x] Cloud settings rules restrict access to the entitled owner.
- [x] Existing settings schema remains compatible.
- [x] `flutter analyze` and `flutter test` pass.

## Validation status

Repository contract tests cover local-only behavior, cloud-wins reconciliation,
first-sign-in seeding, local fallback, failed writes, and account transition.
Manual multi-device validation and Firestore emulator execution remain pending;
the current machine does not have Java available to start the emulator.
