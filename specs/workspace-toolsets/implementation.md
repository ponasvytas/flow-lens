# Workspace toolsets: first implementation

Implemented September 2026. The [design proposal](README.md) remains the broader
roadmap; the scope below describes the working implementation.

## Using the workspace

- Open **Tools** beside the workflow selector, or **App menu > Tools** in a
  narrow window. The checklist stays open for multiple changes. Each workflow
  lists its applicable tools.
- Quick events and Categories are independent Record toolsets. Either, both,
  or neither can be visible. Tools > Workspace layout provides Quick tagging
  and Full tagging visibility arrangements while retaining each tool's placement.
- A panel's position menu now includes **Hide**. Hiding removes the entire panel;
  checking it in Tools restores its placement and expands it. Collapse and the
  existing four dock positions / floating remain available.
- Expanded panels share a side dock's available height. Compact windows show
  tabs, or a tool selector in short windows, rather than stacking every panel.
  The Events list now participates in the shared docking layout.
- Categories uses the active sport taxonomy, with labels, search, horizontal
  strips, and vertical choices. Alt/number entry remains paged and no longer
  replaces the Quick events panel. Hidden Categories can use temporary entry.
- Category entry starts a draft at the original video timestamp. **Save event**
  commits it; Cancel discards the draft. Drafts are separate from review selection
  and survive panel hiding and moving. The entry dialog can pin Categories open.
- A transient overlay provides capture feedback and Edit/Undo for six seconds;
  unfinished drafts retain resume/cancel. There is no idle status strip.
  Quick-event hotkeys remain usable with
  Quick events hidden. Modal editing and text entry suppress those shortcuts.

## Drawing and presentation

- Drawing uses Pointer, Pen, Line, Arrow, and Laser in the shared action grid,
  reflowing at the available width in every dock and floating panel.
- A single color control opens named colors. Stroke widths and Clear drawings
  are in Drawing options. Reset zoom is in Playback's More menu.
- Undo/Redo follows completed pen/line/arrow actions in order. Clear is reversible;
  laser trails do not enter history. History is capped at 100 actions and reset
  on video replacement. Ink and laser retain separate colors during the session.
- Escape returns to Pointer. Ctrl/Cmd+Z and Ctrl/Cmd+Shift+Z undo/redo in Review
  outside text fields. Hiding Drawing exits input capture without erasing ink.
- Completed annotations retain their capture canvas size and scale with the
  fitted video. Pan translations also scale when the viewport changes.
- In Review, **Tools > Workspace layout > Present** opens a temporary arrangement
  with Drawing above the video and Playback/Event navigation below. The header's
  Exit presentation action restores the saved layout. Presentation edits are not
  written into the normal Review workspace; playback and filters stay intact.

## Persistence and compatibility

Layout JSON is version 2 and continues using the existing preference location.
Legacy `eventButtons` state migrates to `quickEvents`; Categories starts hidden.
Geometry, visibility, collapse, and per-workflow choices are retained. Reset this
workflow can be undone during the session.

The implementation continues to use ChangeNotifier, immutable event updates,
scoped painting, existing media_kit playback, and the current laser throttling
and fade. It introduces no additional packages.

## Validation

New tests cover legacy layout migration, independent tool visibility, restore,
reset/undo, presentation isolation, draft retention and commit/cancel, mixed-tool
drawing history, reversible Clear, viewport scaling, tool menus, and all five
drawing placements at normal and doubled text sizes. Existing quick-event,
docking, taxonomy, playback, and performance tests remain in the suite.

Optional synthetic visual previews:

```text
flutter test test/workspace_tools_test.dart --dart-define=CAPTURE_WORKSPACE=true
```

Previews are written to ignored `build/workspace-*.png`, with synthetic video.
They validate component geometry and interactions, not real video playback or
screen-sharing quality. Real iPad Safari/native testing remains outstanding.

## Remaining design work

- Manual ordering within a shared dock. Adjustable dividers now resize adjacent
  toolsets, remember proportions per workflow, and reset on double-click.
- Shared sizing, compact framing, wrapping, floating growth, and explicit
  expanded palettes are implemented; see [layout-system.md](layout-system.md).
- Broader device usability testing, presentation readability during an actual
  coaching call, and additional toolbar density refinement.
- The independent Shortcuts help overlay retains its existing behavior.
- Drawings are temporary; this update does not add event-linked annotation
  storage, shape editing, or a separate presenter window.
