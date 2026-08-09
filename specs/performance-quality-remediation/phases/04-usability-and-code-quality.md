# Phase 04 — Usability and code quality

## Objective

Remove confirmed dead paths, improve interaction accessibility, and reach a
clean analyzer without changing the application architecture.

## Prerequisites

Phase 03 resource lifecycle.

## Implementation

Document Firebase intent; remove dead APIs/widgets; require explicit drawing
clear; provide 44-pixel hit areas; use gated logging and current platform APIs.

## API changes

Confirmed unreferenced internal APIs are removed rather than deprecated.

## Failure handling

Visible actions retain tooltips/semantics and nonfunctional settings are hidden.

## Tests

Widget accessibility, explicit drawing clear, and analyzer/search verification.

## Acceptance checklist

- [x] `flutter analyze` reports zero findings.
- [x] Drawing clear is explicit rather than double-tap.
- [x] Firebase scaffold intent is documented.
- [ ] Every interactive control has verified keyboard/semantics coverage.

## Completion record

Implemented 2026-08-09. Analyzer is clean; interactive keyboard/screen-reader
coverage remains a Phase 05 smoke check.
