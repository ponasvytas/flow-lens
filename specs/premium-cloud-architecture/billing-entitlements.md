# Billing and Entitlements

This document separates purchase mechanics from app capabilities. The app should
check capabilities, not raw platform or billing-provider state.

## Product tiers

### Free anonymous web

- No login required.
- Bundled built-in taxonomy only.
- Local browser preferences only.
- Local file import/export.
- No cloud persistence.
- No custom taxonomy sync.
- No saved cloud sessions.
- No review-link creation.

### Premium account

- Login on web, iOS, and Android.
- Cloud preferences.
- Saved event and tracking sessions.
- Custom taxonomy.
- Review-link creation.
- Offline cache where supported.
- Server-side export in a later phase.

### Premium-plus or usage-metered add-on

- Uploaded video hosting.
- Larger storage quotas.
- Longer retention.
- Server-side rendering/export jobs.

This tier is deferred until cost controls and policy requirements are explicit.

## Entitlement source of truth

Entitlement truth should live on the backend, not on device storage. A client may
cache entitlements for offline display, but premium writes and share creation
must validate against backend state.

The app should use a capability object such as:

- `canSyncSettings`
- `canSaveCloudSessions`
- `canEditCustomTaxonomy`
- `canCreateReviewLinks`
- `canUploadVideo`
- `canRunServerExport`

## iOS distribution

iOS should be a free app with premium login/subscription. This avoids forcing
non-paying reviewers or trial users to buy the app upfront and fits shared-link
workflows better.

If premium is purchasable inside the iOS app, Apple in-app purchase rules likely
apply. If users can only sign in to an existing account purchased elsewhere,
the app needs a careful policy review before shipping.

## Web billing

Web checkout can be simpler for subscription management, coupons, team billing,
and payment recovery. If web billing is introduced, entitlements should still be
written to the same backend entitlement record used by mobile.

## Implementation requirements

- Do not gate premium behavior by `kIsWeb`, Android, or iOS directly when a
  capability check is possible.
- Do not trust locally cached entitlement state for cloud writes.
- Keep free anonymous behavior available without requiring Firebase Auth.
- Add billing provider dependencies only in the phase that implements purchase
  flows.
