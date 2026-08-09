# Decisions

This log is append-only.

## 2026-08-09

- Retain `ChangeNotifier`; scoped `ValueListenable`s are used for hot cells.
- Preserve every persisted JSON schema and settings key.
- Keep Firebase packages and generated configuration as intentional future
  cloud/shared-video scaffolding.
- Event navigation plays from lead-in and pauses at lead-out using video
  position, never wall-clock delay.
- Restore drag-to-snap with a 30 logical-pixel edge threshold; the explicit
  dock menu remains available.
- Keep web and Windows as measured 60 FPS reference platforms.
- Use `auto-safe` for native hardware decoding.
- Treat owned browser blob URLs as resources: release on replacement and
  disposal, and never revoke URLs not created by the loader.
- Reference-machine FPS and memory gates are recorded manually rather than
  enforced in CI; deterministic counts and data behavior are enforced in tests.

