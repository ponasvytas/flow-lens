# Phase 01 — Input, rendering, and seeking

## Objective

Keep drawing, laser input, scrubbing, and event preview responsive and race-safe.

## Prerequisites

Phase 00 instrumentation.

## Implementation

Use incremental active paths and cached completed paths, reduced/throttled input,
one seek per scrub, and generation-based preview coordination.

## API changes

Add drawing capture/path utilities and an injectable event preview coordinator.

## Failure handling

Generation tokens ignore stale async completions; preview errors cancel state
and flow through an injected error callback.

## Tests

Point reduction, final flush, laser throttling/lifetime, one-seek scrubbing, and
preview boundary/cancellation cases.

## Acceptance checklist

- [x] No per-pointer full-list copies.
- [x] One seek per completed scrub.
- [x] Preview uses video position and generation tokens.
- [ ] Reference-machine drawing/laser p95 is at most 16.7 ms.

## Completion record

Implemented 2026-08-09; manual profile gate remains pending.

