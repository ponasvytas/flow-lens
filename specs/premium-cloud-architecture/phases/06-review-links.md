# Phase 06 - Review links

## Objective

Allow premium users to generate links for others to review saved event or
tracking sessions.

## Prerequisites

- Phase 04 session storage is complete.
- Phase 05 custom taxonomy support is complete if links can include custom
  taxonomy data.
- Review-link access model is documented in [../security-rules.md](../security-rules.md).

## Implementation

- Add `ShareLinkRepository`.
- Generate unguessable tokens and store only token hashes.
- Support revocation and expiration.
- Support metadata-only or external-video URL links for MVP.
- Add a viewer route that does not require login when the link is unlisted and
  valid.
- Avoid uploaded video unless Phase 07 is accepted.

## API changes

- Review link model.
- Viewer route/deep-link model.
- Link status model for active, expired, revoked, or missing links.

## Failure handling

- Missing session: link resolves to a clear unavailable state.
- Expired or revoked link: public access is denied.
- Missing video: viewer can still inspect event metadata or load the matching
  video manually if supported.

## Tests

- Link creation requires premium entitlement.
- Public token can read only intended shared data.
- Revoked and expired links fail.
- Cross-user link mutation is denied.
- Viewer route handles missing video gracefully.

## Acceptance checklist

- [ ] Premium users can create review links.
- [ ] Links can expire and be revoked.
- [ ] Public access is limited to intended shared data.
- [ ] Anonymous reviewers can open valid unlisted links.
- [ ] Uploaded video is still deferred unless Phase 07 is accepted.
