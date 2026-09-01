# Phase 04 - Session storage

## Objective

Add premium cloud storage for event and tracking sessions while preserving JSON
import/export flows.

## Prerequisites

- Phase 03 cloud settings sync is complete.
- Event and tracking JSON compatibility tests exist or are added.
- Firestore data shape is finalized in [../data-model.md](../data-model.md).

## Implementation

- Introduce `EventSessionRepository` and `TrackingSessionRepository`.
- Keep existing file save/load services as import/export services.
- Add cloud session create, update, list, load, delete, and archive behavior for
  premium users.
- Add local cache/offline design if needed before broad mobile use.
- Store video source metadata without requiring Flow Lens-hosted video.

The implemented cloud-session browser is additive to the existing JSON
buttons. Premium users can create, update, list, load, archive, and permanently
delete event and tracking sessions. Event sessions include the taxonomy
snapshot used when saved. Video metadata keeps external HTTP(S) URLs but never
uploads local absolute paths or browser blob URLs.

Sessions use last-write-wins for MVP. Firestore client caching provides the
initial offline behavior where supported; no app-owned durable sync queue is
claimed yet. File import/export remains the fallback when cloud access fails.

## API changes

- Event session metadata model.
- Tracking session metadata model.
- Repository methods for listing and loading saved sessions.

## Failure handling

- Cloud unavailable: keep import/export usable.
- Save conflict: document last-write-wins or introduce revision checks.
- Large sessions: define size limits before relying on Firestore document
  payloads.

The client rejects encoded session content above 750 KiB, leaving headroom
below Firestore's 1 MiB document limit for ownership and timestamp fields.

## Tests

- Existing event controller tests pass.
- Existing tracking controller tests pass.
- Import/export compatibility tests pass.
- Repository contract tests cover local/fake cloud behavior.
- Firestore rules deny cross-user session access.

## Acceptance checklist

- [x] Premium users can save and load event sessions from cloud.
- [x] Premium users can save and load tracking sessions from cloud.
- [x] Free users retain file import/export.
- [x] Existing JSON formats remain compatible.
- [x] Session records include owner and schema version fields.

## Validation status

Model tests cover event and tracking JSON round trips, immutable event views,
local-path sanitization, external URL metadata, and the document-size gate.
Firestore rules harness cases cover premium owner CRUD, free and cross-user
denial, and immutable ownership fields. Manual Firebase validation and emulator
execution remain pending; Java is unavailable on the current machine.
