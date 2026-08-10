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

## 2026-08-09 — Drawing clear interaction revision

- Restore double-click/double-tap clearing on the active drawing surface and
  make all clear actions immediate. Drawings are intentionally short-lived,
  temporal coaching annotations, so fast clearing is more valuable than a
  confirmation step. This supersedes the Phase 04 explicit-only clear decision.

## 2026-08-09 — Laser cursor rendering revision

- Cursor motion is no longer throttled or distance-reduced. The colored cursor
  uses a dedicated repaint-only layer so pointer movement never rebuilds the
  overlay or repaints fading trails. The 16 ms throttle and 5 px reduction now
  apply only to captured trail points.

## 2026-08-09 — Explicit-only panel docking revision

- Dragging a floating panel only changes its clamped screen position. Docking
  now occurs exclusively through the panel dock-position menu. This supersedes
  the earlier drag-to-snap decision for every app mode, including Tracking.
