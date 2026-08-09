# Phase 02 — State indexing and rebuild isolation

## Objective

Make ordinary tracking/event work constant-time and isolate high-frequency UI
updates.

## Prerequisites

Phase 01 input behavior.

## Implementation

Maintain tracking indexes and scoped cell listenables; expose stable event
views, cached chronology, batched mutations, taxonomy lookup maps, lazy timeline
painting, binary navigation, and local drag state with edge snapping.

## API changes

Add immutable `TrackingCellStats`, cell listenables, stable collection views,
event upsert/batch deletion/containment, revision listenables, and chronological
filtered access.

## Failure handling

Historical operations rebuild indexes atomically. Removed cells dispose their
notifiers. Invalid IDs are ignored.

## Tests

Aggregate rebuilding, ID collision prevention, event cache/revisions/batch
notification, binary navigation, painter hit testing, and edge snapping.

## Acceptance checklist

- [x] Normal tracking actions update indexes in O(1).
- [x] Batch event deletion emits one controller notification.
- [x] Selection changes do not invalidate chronology.
- [ ] Reference 1,000/10,000-item profile gates pass.

## Completion record

Implemented 2026-08-09; manual profile gate remains pending.

