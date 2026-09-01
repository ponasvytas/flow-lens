# Security Rules

This document describes the intended Firebase security posture. Exact Firestore
and Storage rules should be implemented and tested in a later phase.

## Goals

- Users can read and write only their own private data.
- Public review links expose only explicitly shared sessions.
- Review links can expire or be revoked.
- Entitlements cannot be self-granted by clients.
- Uploaded video access is scoped to owners and valid review links.
- Cross-user taxonomy, session, and preference writes are denied.

## Firestore rule posture

Client writes should be allowed for user-owned preferences, taxonomies, and
sessions only when:

- `request.auth.uid` matches the document owner.
- The user has the required backend entitlement for premium-only writes.
- Immutable fields such as `ownerId`, `createdByUserId`, and `createdAt` are not
  improperly changed after creation.
- Document schema constraints are satisfied.

Client writes should be denied for:

- Entitlement records.
- Billing/provider records.
- Public token-hash index records.
- Moderation or abuse status fields.
- Any document owned by another user.

Privileged writes should be performed by Cloud Functions or backend admin SDKs.

The `firestore.rules` implementation is default-deny. It permits an
authenticated user to read only their own entitlement and denies all
entitlement writes. An owner with an active, unexpired premium entitlement may
read and write `users/{userId}/preferences/default`; writes must contain only
the versioned settings schema, must satisfy controller-equivalent numeric
ranges, and must use the request server timestamp. Deletes and cross-user
access are denied.

Event and tracking session reads, creates, and updates require the matching
owner plus an active, unexpired premium entitlement. Creates enforce owner,
creator, session ID, schema version, and server timestamps. Updates preserve
owner, creator, creation timestamp, and session ID while requiring a server
update timestamp. Owners may permanently delete their own sessions even if a
premium entitlement later lapses. Basic title, collection-size, and document
shape constraints are enforced; the client additionally applies a 750 KiB
encoded-content limit.

## Review link access

Review-link reads should support these modes:

- Private: owner only.
- Unlisted: anyone with a valid token can view the shared snapshot or session.
- Revoked or expired: no public access.

Public tokens should not be stored in plaintext. Store token hashes and compare
through a Cloud Function or a minimal public lookup model.

## Storage rule posture

Uploaded video is deferred. If enabled, Storage rules should require:

- Authenticated upload.
- Owner-matching storage path.
- File size and content-type enforcement where possible.
- Metadata record creation before or immediately after upload.
- Read access limited to owner or valid review-link access path.
- Delete access limited to owner or privileged backend cleanup.

## Emulator tests

Rules should include tests for:

- Anonymous user cannot read private user documents.
- User A cannot read or write User B preferences, sessions, or taxonomies.
- User cannot create or edit their own entitlement record.
- Premium-only writes fail without entitlement.
- Public review link can read only intended shared data.
- Expired and revoked review links fail.
- Uploaded-video reads fail without owner or link access once video upload is
  implemented.
