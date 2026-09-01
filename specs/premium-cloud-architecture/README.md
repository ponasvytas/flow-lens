# Premium Cloud Architecture

This spec tracks the staged transition from a local-first coaching tool to a
capability-based product with anonymous free web usage and authenticated premium
features across web, iOS, and Android.

No application code is changed by this spec. Implementation phases should keep
the current free/local behavior working while adding cloud-backed premium
capabilities behind explicit gates.

## Status

- [x] Seed plan saved in [plan.md](plan.md)
- [x] Spec package created
- [x] Phase 00: product boundaries
- [x] Phase 01: service composition
- [ ] Phase 02: auth and entitlements (code complete; backend validation pending)
- [ ] Phase 03: cloud settings sync (code complete; backend validation pending)
- [ ] Phase 04: session storage (code complete; backend validation pending)
- [ ] Phase 05: custom taxonomies
- [ ] Phase 06: review links
- [ ] Phase 07: video assets and export

## Product direction

Flow Lens should be capability-based rather than platform-split:

- Free anonymous web: local-only, no login, no server-side persistence.
- Premium web, iOS, and Android: authenticated, Firebase-backed, shared data
  model.
- Local storage: cache, offline drafts, and import/export support, not the
  source of truth for premium account data.

## Acceptance summary

- Free web keeps working without login, server writes, or paid dependencies.
- Premium web, iOS, and Android use the same account, entitlement, and cloud
  data model.
- Existing JSON import/export formats remain compatible.
- Repository interfaces separate durable storage from file import/export.
- Taxonomy editing is versioned before any user-editable taxonomy ships.
- Review links are implemented before uploaded-video sharing.
- Uploaded video is enabled only after quota, retention, moderation, deletion,
  privacy, and cost controls are specified.
- Firebase security rules and Cloud Functions are validated with emulator tests
  before production rollout.

## Phase documents

1. [Product boundaries](phases/00-product-boundaries.md)
2. [Service composition](phases/01-service-composition.md)
3. [Auth and entitlements](phases/02-auth-entitlements.md)
4. [Cloud settings sync](phases/03-cloud-settings-sync.md)
5. [Session storage](phases/04-session-storage.md)
6. [Custom taxonomies](phases/05-custom-taxonomies.md)
7. [Review links](phases/06-review-links.md)
8. [Video assets and export](phases/07-video-assets-and-export.md)

## Supporting documents

- [Decisions](decisions.md)
- [Data model](data-model.md)
- [Security rules](security-rules.md)
- [Billing and entitlements](billing-entitlements.md)
- [Product boundaries](product-boundaries.md)
- [Video sharing policy](video-sharing-policy.md)
- [Validation](validation.md)
