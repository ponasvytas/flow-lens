# Decisions

This log is append-only. New information should add entries rather than rewrite
prior decisions, unless a decision is explicitly superseded.

## 2026-08-09

- Use Firebase-first for the initial premium architecture.
- Use individual user accounts first. Team and organization support is deferred,
  but ownership fields should be migration-friendly.
- Distribute iOS as a free app with premium login/subscription rather than as a
  paid-upfront app.
- Paid functionality is server-backed across web, iOS, and Android.
- Local mobile and web storage is cache/offline support, not the source of truth
  for premium data.
- Existing file import/export flows remain available for free and premium users.
- Uploaded video sharing is not part of the first premium slice. It requires
  quota, policy, privacy, retention, deletion, cost, and abuse controls first.
- Keep the existing `ChangeNotifier` state management style.
- Add dependencies only when a phase needs them.
- Keep bundled sport taxonomy assets as the baseline source for anonymous/free
  usage.
- The initial review-link scope includes session metadata and an optional
  external video URL. Uploaded video remains deferred.
- The initial premium launch includes auth and entitlements, cloud settings,
  saved event/tracking sessions, custom taxonomies, and review links.
- Firebase email/password is the initial account provider. Google and Apple can
  be added later without changing the app identity or capability models.
- Billing integration is deferred from the auth phase. Entitlements are
  backend/admin provisioned until a purchase flow is selected.
- Settings reconciliation uses cloud-wins when a premium settings document
  exists. A missing cloud document is seeded from current local settings.
- Settings use last-write-wins for the MVP, with Firestore server timestamps.
  Cloud failures preserve local changes and surface a non-blocking warning.
- Cloud event and tracking sessions use last-write-wins for MVP and are stored
  as single versioned documents with a 750 KiB client payload limit.
- Event sessions store the active taxonomy snapshot. Tracking sessions retain
  their existing JSON shape inside a versioned cloud envelope.
- Cloud video metadata never includes local absolute paths or browser blob
  URLs. Explicit HTTP(S) sources may be retained for later review-link use.
- Firestore SDK caching is the Phase 04 offline baseline. An app-owned durable
  database and sync queue remain a later decision before broad mobile rollout.

## Open decisions

- Whether web checkout, iOS in-app purchase, or both will sell premium.
- Whether initial review links require an external video URL, a reviewer-loaded
  local video, or support both.
- Which local database should support offline premium cache: Drift/SQLite, Isar,
  or another Flutter-friendly store.
- Whether uploaded video becomes a premium-plus tier, usage-metered add-on, or a
  limited feature inside the base premium plan.
