# Phase 05 - Custom taxonomies

## Objective

Allow premium users to create and modify event taxonomies without breaking
historical sessions or shared reviews.

## Prerequisites

- Phase 04 session storage is complete.
- Taxonomy schema and versioning rules are documented.
- Built-in taxonomy loading continues to work for free users.

## Implementation

- Split built-in taxonomy loading from user/cloud taxonomy loading.
- Add user-owned taxonomy repository behavior for premium users.
- Preserve stable category and event type IDs across rename operations.
- Archive or hide deleted taxonomy items that are referenced by old sessions.
- Store taxonomy revision or snapshot references on sessions and review links.
- Validate custom taxonomy with existing duplicate-ID validation patterns.

## API changes

- Taxonomy metadata model.
- Taxonomy revision field.
- Optional base taxonomy reference fields.

## Failure handling

- Invalid custom taxonomy: reject save and keep current valid taxonomy loaded.
- Missing historical taxonomy: use stored snapshot where available.
- Cloud unavailable: fall back to built-in taxonomy or cached custom taxonomy.

## Tests

- Built-in taxonomy tests still pass.
- Custom taxonomy validation tests cover duplicate category and event type IDs.
- Session load tests cover old taxonomy revisions.
- Security rules deny cross-user taxonomy mutation.

## Acceptance checklist

- [ ] Free users keep bundled taxonomies.
- [ ] Premium users can save custom taxonomies.
- [ ] Historical sessions remain understandable after taxonomy edits.
- [ ] Deleting taxonomy items does not break old sessions.
- [ ] Custom taxonomy security rules pass emulator tests.
