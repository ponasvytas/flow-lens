# Phase 00 — Measurement and guardrails

## Objective

Provide opt-in profile-capable frame, rebuild, operation, and dropped-frame
measurement with repeatable fixtures and no practical default release overhead.

## Prerequisites

None.

## Implementation

Gate instrumentation with `FLOW_LENS_PERF`; collect frame timings and percentile
summaries; document datasets and reference runs.

## API changes

`Perf` exposes installation, synchronous/asynchronous timing, counters,
snapshots, dumps, and reset.

## Failure handling

Instrumentation remains inert unless explicitly compiled in and never changes
application behavior.

## Tests

Exercise percentile calculation and reset through deterministic snapshots.

## Acceptance checklist

- [x] Compile-time opt-in supports profile mode.
- [x] Frame and operation p50/p95/max are represented.
- [x] Rebuild and dropped-frame counters are represented.
- [x] Reference fixtures are documented.

## Completion record

Implemented 2026-08-09. Interactive baseline capture remains unavailable and is
recorded rather than inferred.
