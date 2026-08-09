# Phase 03 — Resources, platform behavior, and export

## Objective

Make video replacement, platform startup, and export resource ownership safe.

## Prerequisites

Phase 02 state behavior.

## Implementation

Centralize replacement/release, guard asynchronous initialization, choose safe
native decoding, preserve mute state, and bound/throttle export diagnostics.

## API changes

Add conditional `releaseVideoUrl` and bounded export diagnostic primitives.

## Failure handling

Failed opens restore picker/error state. Export termination owns cancellation,
late output is ignored, streams close once, and temporary directories clean up.

## Tests

Blob ownership/revocation, failed replacement, export throttling/log bounds,
cancellation, and cleanup.

## Acceptance checklist

- [x] Owned browser URLs have symmetric release.
- [x] Native decoding uses `auto-safe`.
- [x] Logs are bounded to 200 lines and progress to 10 Hz.
- [x] Active export cannot dismiss without cancellation.

## Completion record

Implemented 2026-08-09.

