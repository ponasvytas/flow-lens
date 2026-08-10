# Docking workspace refactor

## Delivered scope

- Four resizable dock regions and a center video surface.
- Side docks are bounded between top and bottom docks, so dock regions never
  overlap one another.
- Each panel defines separate floating geometry and horizontal-dock width;
  side docks fill their configured edge width.
- Floating panels are resizable, stay within the workspace, and move only from
  their title strip.
- Docking remains an explicit action in the panel menu.
- The same menu switches the current workflow between overlaying docks on the
  video and squeezing the video into the center region.
- Event entry, playback, drawing, event navigation, and player tracking use the
  shared workspace.

## Persistence

`DockLayoutState` stores a separate `WorkflowDockState` for Record, Review, and
Track. Each workflow retains panel edge, visibility, collapsed state, floating
position and size, edge extents, and overlay/squeeze mode. It is stored under a
new SharedPreferences key, so existing event, tracking, and settings files are
unchanged.

## Responsive behavior

Requested dock sizes are reduced proportionally when necessary to retain a
usable center surface. Dock contents scroll when their region is smaller than
their natural size. This protects the workspace on constrained desktop and web
windows.

A whole-app responsive review for phone, tablet, accessibility scaling, and
all dialogs/tables is intentionally deferred; it should be validated as its
own cross-platform scope rather than folded into docking geometry.

## Validation

- JSON round-trip and per-workflow persistence tests.
- Disjoint four-edge geometry tests.
- Constrained-window center-area tests.
- Explicit docking, title-only dragging, viewport clamping, resizing, and
  overlay/squeeze widget tests.
