## Plan: Premium Cloud Architecture

Flow Lens should evolve from a local-first single-user tool into a capability-based product: anonymous free web remains local-only, while premium web, iOS, and Android share the same authenticated Firebase-backed data model. Mobile local storage should remain a cache/offline layer, not the premium source of truth. The implementation should be documented under `specs/premium-cloud-architecture/` using the existing spec package pattern: README, decisions log, validation plan, data model helper docs, and phased implementation files.

**Steps**
1. Create the spec package structure under `specs/premium-cloud-architecture/`. Include `README.md`, `decisions.md`, `validation.md`, `data-model.md`, `security-rules.md`, `billing-entitlements.md`, `video-sharing-policy.md`, and `phases/` documents. This mirrors `specs/performance-quality-remediation/` so the architecture work has durable decisions and verifiable phases.
2. Define product tiers and runtime capabilities. Free anonymous web includes bundled taxonomies, local browser preferences, file import/export, and no server-side persistence. Premium web/iOS/Android includes login, cloud preferences, custom taxonomy, saved event/tracking sessions, review links, and later server-side export/video hosting. Use capability checks rather than platform checks wherever possible.
3. Introduce an application composition layer. Move direct construction of concrete services out of `lib/main.dart` into an app bootstrap/composition module that selects repository implementations based on environment, auth state, and entitlement state. Keep `ChangeNotifier` state management.
4. Formalize repository interfaces. Extend the existing `SettingsRepository` pattern to `AuthRepository`, `EntitlementsRepository`, `TaxonomyRepository`, `EventSessionRepository`, `TrackingSessionRepository`, `ShareLinkRepository`, and optional `VideoAssetRepository`. Existing file-picker services become import/export services rather than durable storage.
5. Add Firebase-backed premium infrastructure. Add Firebase Auth, Firestore, Cloud Functions, and selectively Firebase Storage. Keep `firebase_core`; add dependencies only as phases require them. Firestore is the source of truth for premium account data; local storage is cache/offline support.
6. Add local cache/offline storage design. Keep `SharedPreferences` only for tiny anonymous/local settings. Use a proper local database later, such as Drift/SQLite or Isar, for cached sessions, custom taxonomies, and sync queues. Do not store entitlement or permission truth only on-device.
7. Model premium account data for individual users first. Create Firestore collections for users, user preferences, custom taxonomies, sessions, review links, entitlements, and optional video assets. Leave team/org ownership as a future extension by including `ownerType`/`ownerId` or migration-friendly ownership fields.
8. Design taxonomy versioning before enabling editing. Built-in taxonomy remains bundled in `assets/sports/*.json`. Premium custom taxonomy stores stable IDs, schema versions, parent/base taxonomy references, and snapshots used by historical sessions and share links.
9. Implement authentication and entitlement gates before cloud writes. iOS should be a free app with premium login/subscription by default. Premium purchase can be through in-app purchase and/or existing account login depending on final billing policy. Avoid assuming iOS must be paid upfront; freemium is the better fit for cross-platform sharing and trial flows.
10. Build cloud settings sync as the first vertical slice. It is low-risk and already has a repository interface in `lib/services/settings_repository.dart`. Add a cloud implementation, a local implementation, and a hybrid implementation if offline cache is included in the same phase.
11. Refactor event/tracking persistence into session repositories. Preserve existing JSON import/export behavior, but add saved cloud sessions for premium users. Keep file import/export available for free and premium users.
12. Add custom taxonomy support. Load built-in taxonomy first, then overlay or select user-owned custom taxonomy. Validate duplicate IDs and schema compatibility using existing `SportTaxonomy.validate()` patterns.
13. Add review links in two stages. Stage 1 stores event/tracking metadata and references an external video URL or requires reviewers to load matching video. Stage 2 optionally supports uploaded video for higher-cost premium tiers with quotas, terms acceptance, moderation/reporting, and lifecycle cleanup.
14. Add video upload only after cost and policy gates are explicit. If enabled, enforce per-user quota, per-file size limit, allowed file types, deletion policies, access rules, signed URLs, and abuse-report workflows. Treat uploaded video as a premium-plus or usage-metered feature.
15. Add server-side export later as a separate premium feature. The web export stub already says server-side FFmpeg is planned; implement this via Cloud Functions/Cloud Run only after session storage and video asset rules are stable.
16. Add validation and rollout gates. Each phase should include Flutter analyzer/tests, Firebase emulator tests for rules/functions, manual web/iOS/Android smoke tests, and migration checks for existing JSON formats.

**Relevant files**
- `specs/premium-cloud-architecture/README.md` — overview, status checklist, phase links, acceptance summary.
- `specs/premium-cloud-architecture/decisions.md` — append-only decisions: Firebase-first, individual users first, free iOS app with premium subscription/login, video upload deferred behind policy/quota design.
- `specs/premium-cloud-architecture/data-model.md` — Firestore documents, ownership fields, taxonomy/version strategy, session/link schemas.
- `specs/premium-cloud-architecture/security-rules.md` — access-control model, emulator test cases, public/private review-link behavior.
- `specs/premium-cloud-architecture/billing-entitlements.md` — product tiers, entitlement source of truth, iOS/web purchase implications, capability gating.
- `specs/premium-cloud-architecture/video-sharing-policy.md` — external URL vs uploaded video tradeoffs, quotas, legal/abuse controls, retention.
- `specs/premium-cloud-architecture/validation.md` — automated and manual validation matrix.
- `specs/premium-cloud-architecture/phases/00-product-boundaries.md` — product tier and capability matrix.
- `specs/premium-cloud-architecture/phases/01-service-composition.md` — app bootstrap and repository interface extraction.
- `specs/premium-cloud-architecture/phases/02-auth-entitlements.md` — Firebase Auth and premium capability gate.
- `specs/premium-cloud-architecture/phases/03-cloud-settings-sync.md` — first cloud-backed vertical slice.
- `specs/premium-cloud-architecture/phases/04-session-storage.md` — event/tracking session repositories and cloud persistence.
- `specs/premium-cloud-architecture/phases/05-custom-taxonomies.md` — user taxonomy editing/versioning.
- `specs/premium-cloud-architecture/phases/06-review-links.md` — share-link creation, viewer flow, permissions.
- `specs/premium-cloud-architecture/phases/07-video-assets-and-export.md` — optional uploaded-video and server export architecture.
- `lib/main.dart` — currently constructs concrete services directly; should delegate to composition/bootstrap.
- `lib/services/settings_repository.dart` — existing repository pattern to extend for cloud/hybrid implementations.
- `lib/controllers/settings_controller.dart` — first low-risk cloud sync vertical slice.
- `lib/services/event_storage_service.dart` — reclassify as import/export, not durable storage.
- `lib/services/tracking_storage_service.dart` — reclassify as import/export, not durable storage.
- `lib/services/taxonomy_repository.dart` — split built-in asset loading from user/cloud taxonomy loading.
- `lib/models/sport_taxonomy.dart` — preserve validation and immutable model patterns; extend with version/reference metadata only if required.
- `lib/services/export/export_service_stub.dart` — future premium server-side export hook.

**Verification**
1. Spec verification: ensure the new spec package has README, decisions, validation, data model, security, billing, video policy, and phase docs with no unresolved implementation blockers hidden in prose.
2. Architecture verification: `flutter analyze` after each implementation phase.
3. Unit tests: existing controller/model tests continue passing after repository extraction.
4. Repository tests: local, cloud, and hybrid repository implementations use contract tests where practical.
5. Firebase emulator tests: security rules deny cross-user reads/writes, enforce public review-link access only where intended, and block unauthorized taxonomy/session mutation.
6. Migration tests: existing event/tracking JSON import/export remains compatible.
7. Manual smoke tests: anonymous free web, premium web login, iOS login, Android login, offline cache behavior, and review-link viewer flow.
8. Cost/security review before uploaded video: validate quotas, retention, signed URL behavior, deletion, and abuse-report path before enabling production upload.

**Decisions**
- Use Firebase-first for the initial premium architecture.
- Use individual user accounts first; team/org support is deferred but should be migration-friendly.
- iOS should be distributed as a free app with premium login/subscription rather than requiring all iOS users to pay upfront.
- Paid functionality should be server-backed across web, iOS, and Android.
- Local mobile/web storage is cache/offline support, not the source of truth for premium data.
- Existing import/export flows remain available and should not be replaced by cloud-only storage.
- Uploaded video sharing is not part of the first premium slice; it requires explicit quota, policy, privacy, and cost design.

**Further Considerations**
1. Billing needs a dedicated decision: Apple in-app purchase, web checkout, or both. Recommended starting point is free app plus premium account, with iOS IAP support for purchases made inside the iOS app.
2. Review links need a product decision: metadata-only MVP, external-video URL MVP, or uploaded-video premium-plus. Recommended starting point is metadata/external URL, then uploaded video after cost controls exist.
3. Team/org support should be delayed unless it is essential for launch. Add ownership fields now so migration is possible later.
