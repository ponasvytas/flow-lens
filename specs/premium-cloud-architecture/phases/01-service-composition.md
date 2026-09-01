# Phase 01 - Service composition

## Objective

Introduce a composition boundary that selects repositories and capabilities
without changing current local behavior.

## Prerequisites

- Phase 00 product boundaries are accepted.
- Current local app behavior is understood and covered by existing tests where
  practical.

## Implementation

- Move direct service construction out of `lib/main.dart` into an app
  composition/bootstrap module.
- Preserve `ChangeNotifier` state management.
- Introduce capability/config objects that describe runtime behavior.
- Keep current concrete local services as the default implementation.
- Define repository interfaces before adding Firebase-backed implementations.
- Reclassify file-picker storage services as import/export services, not durable
  app storage.

## API changes

Candidate interfaces:

- `AuthRepository`
- `EntitlementsRepository`
- `SettingsRepository`
- `TaxonomyRepository`
- `EventSessionRepository`
- `TrackingSessionRepository`
- `ShareLinkRepository`
- `VideoAssetRepository` only when uploaded video is in scope

## Failure handling

If composition changes affect current app startup, revert to local-only service
selection until tests and manual smoke checks pass.

## Tests

- Existing unit tests pass (52 tests on 2026-08-09).
- `flutter analyze` passes (2026-08-09).
- Production web build passes (2026-08-09).
- Manual free web smoke test passes (confirmed 2026-08-09).

## Acceptance checklist

- [x] `lib/main.dart` no longer owns all concrete service construction.
- [x] Current local/free behavior is unchanged by composition selection.
- [x] Capability checks are possible without platform-only branching.
- [x] Import/export services are separated from durable repositories.
- [x] No Firebase-backed persistence is required yet.

## Validation status

The code, automated validation, and anonymous/free web smoke test are complete.
