# Performance and Quality Remediation

This package tracks the staged remediation of the Flow Lens performance and
quality audit. Phases are ordered and each phase depends on the preceding phase.
Stored event, tracking, settings, and taxonomy formats remain compatible.

## Status

- [x] Phase 00: measurement and guardrails
- [x] Phase 01: input, rendering, and seeking
- [x] Phase 02: state indexing and rebuild isolation
- [x] Phase 03: resources, platform behavior, and export
- [x] Phase 04: usability and code quality
- [ ] Phase 05: final reference-machine and cross-platform validation

Phase 05 is complete only after dated Chrome and Windows profile captures meet
the targets and all platform runners have reported. Automated validation that
can be performed in this checkout is recorded in [validation.md](validation.md).

## Acceptance summary

- Profile-mode p95 frame time is at most 16.7 ms on the reference web and
  Windows scenarios.
- Frames over 33.3 ms remain below 1% during interaction scenarios.
- Event/tracking mutations are at most 4 ms p95 on reference fixtures.
- A seekbar drag sends one seek, export progress is at most 10 Hz, and export
  diagnostics retain at most 200 lines.
- Analyzer, tests, and release web/Windows builds pass.

## Phase documents

1. [Measurement and guardrails](phases/00-measurement-and-guardrails.md)
2. [Input, rendering, and seeking](phases/01-input-rendering-and-seeking.md)
3. [State indexing and rebuild isolation](phases/02-state-indexing-and-rebuilds.md)
4. [Resources, platform, and export](phases/03-resources-platform-and-export.md)
5. [Usability and code quality](phases/04-usability-and-code-quality.md)
6. [Final validation and rollout](phases/05-final-validation-and-rollout.md)

