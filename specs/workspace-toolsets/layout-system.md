# Shared toolset layout contract

Implemented in `ToolsetLayout`, `ToolActionGrid`, `ToolActionButton`, and
`DockLayout`. This follows the separation used by mature docking systems such
as Qt: the toolset declares its content needs; the dock owns placement and frame
space. Floating is a placement, not a separate vertical toolbar design.

| Token / profile | Value |
| --- | --- |
| Minimum interactive target | 48 × 48 logical pixels |
| Icon glyph | 24 logical pixels |
| Gap between actions / rows | 4 logical pixels |
| Toolset content inset | 8 logical pixels |
| Drawing command tile | 48 logical pixels wide |
| Playback tile | 64 logical pixels wide |
| Category tile | 72 preferred, 64 minimum width |
| Quick-event tile | 96 preferred, 80 minimum width |

Labels appear below icons. Event names, grades, and assigned shortcuts remain
visible. Text is measured at the actual accessibility scale to determine row
height; labels do not get ellipsized to force an arbitrary toolbar height.
All category choices stay present during keyboard entry; only the active
shortcut page receives number prefixes.

## Allocation

- Action toolsets declare labels and a tile profile through one sizing object.
  The dock and the rendered grid use the same measurement. The grid asserts
  that the declared labels match the number of controls.
- A single expanded toolset receives the available horizontal dock width.
  Multiple toolsets share a lane when their preferred widths fit; otherwise
  the dock creates more lanes. Actions wrap within each toolset. Horizontal
  docks do not scroll panels or capture actions off screen.
- Dock height accounts for measured rows plus frame and spacing. Side docks
  allocate heights from content needs, preserving collapsed panel height.
- Dividers resize adjacent toolsets in side docks, columns within horizontal
  rows, and stacked horizontal rows. Other toolsets and the overall dock extent
  stay fixed during a drag. Width changes can grow the dock after release when
  actions need to wrap. Minimums remain protected; double-click a divider to
  restore automatic sharing for its group.
- Proportions save on release, independently for each workflow and arrangement.
  Hiding or collapsing a toolset retains the previous arrangement's proportions
  for restoration. Presentation uses temporary shares; layout reset and undo
  include saved shares. Old layout files continue to use automatic allocation.
- Floating action panels reflow at their current width and grow to the height
  their rows need, bounded by the workspace. Resizing, moving, or pinning does
  not change target-size rules.
- Horizontal frames use one 48-pixel menu area. Collapse is in that menu;
  collapsed panels have one expand button. All-collapsed edges use compact
  extents while retaining the saved expanded extent.
- If video-space protection or a small window makes the full grid impossible,
  an explicit **Show all** action opens an expanded palette. Only this expanded
  palette may scroll vertically when needed. No partially visible primary
  buttons or implicit horizontal scrolling. Open palettes reflect action
  updates; selecting a category closes the palette to reveal event entry.
- Content widgets (event lists, navigation, tracking) declare preferred content
  dimensions separately and retain their content-specific scrolling. New
  action toolsets should use the shared grid, rather than add an edge-specific
  width or orientation branch.

## Adding or changing a toolset

1. Derive its sizing labels from the same actions used to render its controls.
2. Give its `DockPanelEntry` that `ToolsetLayout`; use `ToolActionGrid` inside.
3. Rebuild the entry when its action list or measured labels change. Keep
   button state listeners scoped to the toolset where dimensions do not change.
4. Use `ToolActionButton` for primary controls. Custom popup controls occupy
   the same measured cells. Mark category/utility actions `dismissPalette`
   when they should close an expanded palette before opening another surface.

No per-edge width needs to be tuned when adding/removing actions or toolsets.
Long-label and constrained-screen tests should check full button rectangles and
tap targets, not use scrolling as proof of visibility.

## Feedback and playback

The unsolicited idle status strip and Fit video button have been removed.
Capture feedback overlays the video for six seconds without reserving space.
An unfinished draft retains Resume/Cancel. **Reset zoom** is in Playback's
existing More menu.

## Validation and limits

Widget tests cover all five placements, doubled text scale, dynamic action and
toolset counts, multiple horizontal lanes, real hockey capture toolsets at
1024/1280 widths, floating growth, explicit overflow, live palette updates,
category selection, and feedback expiry. Optional readable synthetic previews:

```text
flutter test test/tool_action_layout_test.dart --dart-define=CAPTURE_WORKSPACE=true
```

Real coaching-call and device usability testing remains useful, particularly
for very large quick menus. Manual ordering within a dock remains separate work.
The responsive compact shelf still switches between
toolsets on phone-sized windows.

References: https://doc.qt.io/qt-6/qtoolbar.html and
https://doc.qt.io/qt-6/qdockwidget.html.
