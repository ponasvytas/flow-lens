# Data Model

This document describes the target premium data model. Names are provisional
until implementation begins, but the ownership and versioning constraints should
hold.

## Principles

- Firestore is the source of truth for authenticated premium account data.
- Local storage is cache/offline support and must not be the only copy of
  premium data.
- User-created records include stable IDs, schema versions, timestamps, and
  owner fields.
- Historical sessions and review links should remain understandable after a
  taxonomy is edited.
- Team support is deferred, but ownership fields should not block later team or
  organization migration.

## Ownership fields

Use these fields on user-owned documents unless a later phase replaces them:

- `ownerType`: initially `user`, later may include `team` or `organization`.
- `ownerId`: Firebase Auth user ID for individual ownership.
- `createdByUserId`: user who created the record.
- `updatedByUserId`: user who last changed the record.
- `createdAt`: server timestamp.
- `updatedAt`: server timestamp.
- `schemaVersion`: integer schema version for the document shape.

## Proposed collections

```text
users/{userId}
users/{userId}/preferences/default
users/{userId}/entitlements/current
users/{userId}/taxonomies/{taxonomyId}
users/{userId}/eventSessions/{sessionId}
users/{userId}/trackingSessions/{sessionId}
users/{userId}/reviewLinks/{linkId}
users/{userId}/videoAssets/{assetId}
publicReviewLinks/{tokenHash}
```

The `users/{userId}` tree keeps individual-user MVP rules simple. If teams are
introduced later, add a parallel `teams/{teamId}` ownership tree or migrate to a
top-level `owners/{ownerKey}` model.

## User profile

`users/{userId}` stores profile metadata only:

- `displayName`
- `emailLowercase`
- `photoUrl`
- `createdAt`
- `lastSeenAt`
- `disabledAt`

Do not store payment provider secrets or auth tokens in Firestore user profile
documents.

## Preferences

`users/{userId}/preferences/default` mirrors `AppSettings`:

- `schemaVersion`
- `fastPlaySpeed`
- `slowPlaybackSpeed`
- `defaultPlaybackSpeed`
- `leadInSeconds`
- `leadOutSeconds`
- `updatedAt`

This should be the first cloud-backed vertical slice because the current code
already has a `SettingsRepository` abstraction.

The Phase 03 document contains only the listed settings fields plus
`updatedAt`. Security rules enforce schema version 1 and the same numeric
ranges as `SettingsController`. Existing cloud data wins during sign-in
reconciliation; absent cloud data is initialized from local settings.

## Entitlements

`users/{userId}/entitlements/current` is backend-owned and contains:

- `tier`: `free`, `premium`, or `premium_plus`.
- `status`: `active` or `inactive`.
- `expiresAt`: optional Firestore timestamp; an elapsed timestamp disables
  premium capabilities.
- `updatedAt`: server timestamp.
- `source`: backend-defined billing or administrative source.

Clients may read their own entitlement but cannot create or modify it. A
missing, malformed, expired, or unreadable document resolves to free/local
capabilities.

## Taxonomies

Built-in taxonomy remains bundled under `assets/sports/*.json`. Premium custom
taxonomy records reference the built-in base:

- `taxonomyId`
- `schemaVersion`
- `sportId`
- `name`
- `baseTaxonomyId`
- `baseTaxonomyVersion`
- `revision`
- `categories`
- `archivedAt`

Stable category and event type IDs are required. Rename operations should update
display names, not IDs. Deleting taxonomy items used by existing sessions should
archive or hide them rather than breaking historical records.

## Event sessions

Event sessions store saved analysis timelines:

- `sessionId`
- `schemaVersion`
- `title`
- `sportId`
- `taxonomyId`
- `taxonomyRevision`
- `taxonomySnapshot` or immutable taxonomy reference
- `sourceVideo`: metadata only unless video upload is enabled
- `events`
- `createdAt`
- `updatedAt`

Existing JSON import/export should continue to work. Cloud session storage is an
additional durable repository, not a replacement for export.

Phase 04 stores schema version 1 event sessions directly under the proposed
collection. Documents include all ownership fields, `archivedAt`, a bundled or
custom taxonomy snapshot, sanitized source-video metadata, and the existing
event JSON array. Active-session queries are limited to 50 records ordered by
`updatedAt`. Encoded content must remain at or below 750 KiB.

## Tracking sessions

Tracking sessions store player/team tracking data:

- `sessionId`
- `schemaVersion`
- `title`
- `sportId`
- `subjects`
- `trackers`
- `events`
- `sourceVideo`
- `createdAt`
- `updatedAt`

Counter and timer event semantics should remain compatible with the existing
tracking JSON model.

Phase 04 stores the existing `TrackingSession.toJson()` payload under
`trackingSession` inside the owned/versioned cloud envelope. Native file paths
are removed; sanitized video metadata is stored separately. The same 750 KiB
content limit and active-session query limit apply.

## Review links

Review links allow another person to view a saved analysis:

- `linkId`
- `tokenHash`
- `sessionType`: `event` or `tracking`
- `sessionId`
- `visibility`: `private`, `unlisted`, or later `team`
- `expiresAt`
- `revokedAt`
- `allowDownload`
- `videoAccessMode`: `none`, `externalUrl`, or `uploadedAsset`
- `createdAt`

Store only a hash of public tokens. Public lookup documents should expose the
least data needed to resolve a viewer request.

## Video assets

Video assets are optional and deferred:

- `assetId`
- `storagePath`
- `originalFileName`
- `contentType`
- `sizeBytes`
- `durationMs`
- `status`: `uploading`, `ready`, `blocked`, `deleted`
- `quotaClass`
- `createdAt`
- `deletedAt`

Uploaded video requires explicit policy, cost, quota, and abuse controls before
implementation.
