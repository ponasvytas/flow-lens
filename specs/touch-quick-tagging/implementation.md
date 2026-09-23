# First implementation slice

Implemented on `touch-quick-tagging`, September 2026.

## Online references

Read directly on 2026-09-13:

- [Linear: How we redesigned the Linear UI, part II](https://linear.app/now/how-we-redesigned-the-linear-ui)
  — restrained chrome, aligned panels, a small set of base/accent/contrast choices,
  and testing density across environments.
- [Radix Colors: Understanding the scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale)
  — separate background, component, hover/selected, border and text roles.

These informed the design approach; no site assets or component code were copied.
Flow Lens keeps its purple identity: near-black plum background, layered plum
panels, lavender accents and a quieter purple header. Existing Material icons are
used, with an app-level Material 3 theme. No additional package is needed.

## Delivered

- New recommended landscape layout: vertical playback left, vertical quick events
  right, video fitted between them. Existing custom layouts remain available;
  App menu -> Reset workspace layout applies the new defaults.
- Narrow windows reflow controls below the video without overwriting saved docks.
- Larger playback, drawing, panel menu and collapse targets; compact app menu.
- Configured Slow/Normal/Fast rates shared by keyboard and touch, selected-rate
  feedback, and secondary jumps/speeds in More.
- Quick events produce normal events immediately without changing playback state.
  Last-event feedback offers Edit and Undo.
- Menu editor supports adding, removing, drag/button reordering, grade defaults,
  assign/change/clear letter shortcuts, and duplicate/reserved-key validation.
- Reusable presets: save, apply, update, rename, duplicate and delete. Applying a
  preset copies its menu; game changes do not mutate the preset.
- Full taxonomy entry remains available from All events, with Add to quick menu.
  Touch drafts no longer disappear on a four-second timer.
- Local menu/preset persistence with serialized writes, an error state and retry.
- Drawing input and shortcuts are restricted to Review. Leaving Review exits
  drawing input. Temporary keyboard fast-forward restores on focus/lifecycle loss.
- Video/zoom normalization uses the fitted video surface instead of estimating
  its width from the screen and dock configuration.

## Current boundaries

This is the first functional slice, not completion of every phase in the plan.

- Menu identity currently uses local video filename and file size, URL identity,
  or a loaded cloud-session ID. Distinct local files with identical name and size
  can share a menu. Explicit local game IDs and a versioned session file remain
  follow-up work.
- Menus/presets stay on this device. Existing event-file and cloud save operations
  are unchanged; event recovery, preset cloud sync and embedding menus in exported
  session files are not implemented. A quick capture records in the active event
  timeline; it does not claim to have saved a file or cloud session.
- The expanded full taxonomy currently opens a bounded dialog; replacing the
  right rail with an inline editor is a later refinement.
- Single-letter quick shortcuts are supported. Arbitrary modifier combinations
  and a full shortcut registry are deferred.
- Touch Fast selects the configured rate; Normal restores normal speed. Touch
  hold-to-fast and simultaneous two-hand hold/tag gesture testing remain pending.
- Responsive review cards, drawing undo/redo, pen-only input, and the broader
  settings/export/Track surface redesign remain follow-up slices.
- Real iPad Safari/home-screen and native iPad testing still requires hardware
  and macOS/iOS build tooling. Desktop widget tests are not a substitute.

## Verification

`test/quick_events_test.dart` covers capture identity/timestamps, preset isolation,
menu persistence, conflict validation, write failure recovery, touch playback
settings, menu editing without capture, vertical side menus, constrained layouts,
large text and draft timeout behavior. Existing docking tests remain in place.

Optional synthetic layout captures:

```text
flutter test test/quick_events_test.dart --dart-define=CAPTURE_TOUCH_PREVIEWS=true
```

Captures are written to ignored `build/touch-preview-*.png`. They use Flutter test
fonts and synthetic video, and are intended to inspect geometry, not final type
rendering or real media playback.
