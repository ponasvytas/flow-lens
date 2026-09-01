# Phase 00 - Product boundaries

## Objective

Define the free, premium, and future premium-plus capability boundaries before
any code changes introduce cloud behavior.

## Prerequisites

- [../plan.md](../plan.md) exists.
- Initial decisions are recorded in [../decisions.md](../decisions.md).

## Implementation

- Define a capability matrix for anonymous free web, premium web, premium iOS,
  and premium Android.
- Identify which features require login, entitlement, cloud persistence, local
  cache, or no storage.
- Decide the minimum premium launch set.
- Confirm whether first review links use metadata-only, external video URLs, or
  both.
- Keep uploaded video outside the first launch unless [../video-sharing-policy.md](../video-sharing-policy.md)
  is completed with concrete quotas and controls.

## API changes

None. This is a documentation and product-boundary phase.

## Failure handling

If billing, video sharing, or team support decisions are unresolved, keep them as
explicit open decisions and do not let implementation assume a hidden answer.

## Tests

None.

## Acceptance checklist

- [x] Capability matrix is documented in
  [../product-boundaries.md](../product-boundaries.md).
- [x] Free anonymous web behavior is protected from accidental login or server
  requirements.
- [x] Premium launch capabilities are explicit.
- [x] Uploaded-video scope is explicitly deferred.
- [x] Open decisions are recorded in [../decisions.md](../decisions.md).
