# Workspace toolsets and coaching layout proposal

Status: proposed, 2026-09-22. Based on the current working tree, including the
recent uncommitted layout, quick-event, taxonomy, and theme work. This is a source
review and design proposal, not a new live visual or device audit.

The first implementation is now available; see [delivered behavior and remaining work](implementation.md).

## Recommendation

Build on the existing workspace with a single Tools menu, independently managed
Quick events and Categories panels, and compact drawing controls. Preserve
Record / Review / Track and the current plum/lavender visual language. Add a
temporary presentation layout for coaching calls after the toolset foundation.

The organizing principle is the coaching sequence: watch the play, mark a
moment, revisit its context, explain a decision, and continue watching. Workspace
management should happen before that sequence, with very little chrome competing
with the video during it.

## What is already working, and what needs to change

| Current implementation | Implication |
| --- | --- |
| `UIController` and `DockLayoutState` already persist visibility, collapse, edge, floating geometry, and overlay/squeeze settings per workflow. | Extend this system; a new docking framework or state-management package is unnecessary. |
| Recommended layouts put Playback left and Quick events right, with the video fitted between them. Narrow windows reflow below the video without replacing saved placement. | Preserve these defaults and existing user layouts. Improve how individual toolsets consume their space. |
| `PanelId.eventButtons` hosts Quick events and temporarily becomes Categories during numbered entry. The full category browser otherwise opens through All events in a dialog. | Quick events and Categories cannot currently have independent visibility or placement. A shared identity is the primary obstacle to the requested Record layout. |
| The over-video SmartHUD is gated by `eventButtons` visibility; last-capture feedback is built inside Quick events. | Adding Hide alone would make entry and feedback disappear in some workflows. Decouple these before shipping visibility controls. |
| Panel menus offer docking and global overlay/squeeze, but no Hide action. The title bar only exposes selected visibility actions. | Users lack one predictable place to discover, hide, and restore tools. A global workspace setting is also mixed into every local panel menu. |
| Horizontal panel chrome allocates 48 px for its menu and 48 px for collapse; collapsed panels have different representations at different edges. | Repeated frame controls consume scarce toolbar width. Establish a shared, compact toolbar frame and consistent collapsed identity. |
| Dock sizing has generic 112 px side and 88 px horizontal minimums. Panels on an edge are laid out in scrolling lists. Quick events can request the full side height. | A slim drawing palette needs panel-specific size contracts. Multiple full-height panels must share a height budget instead of pushing each other out of view. |
| Drawing uses 48 px buttons and swatches, but one sequence for Draw, Zoom, Clear, four tools, and five colors. Floating also uses the vertical variant. | In drawing mode this is 12 targets: about 658 px including gaps and content padding, before panel chrome. Changing orientation alone cannot fix the density. |
| Narrow-layout code invokes panel content builders directly, bypassing dock-panel headers. | New tool management must remain reachable in compact layouts; adding actions only to desktop headers is insufficient. |
| Events list and Shortcuts still have separate visibility/position handling outside the main docking system. | A Tools menu needs adapters initially, followed by migration to the common workspace model. |
| Drawing state contains strokes, lines, arrows, laser trails, and stroke width, but no drawing undo/redo history. | Undo/redo and width controls are functional work, not simply additional icons. |

Principal sources: [workspace state](../../lib/controllers/ui_controller.dart),
[dock layout](../../lib/widgets/dock_layout.dart),
[panel frame](../../lib/widgets/dockable_panel.dart),
[screen composition](../../lib/main.dart),
[drawing palette](../../lib/widgets/drawing_tools_panel.dart),
[categories](../../lib/widgets/event_buttons_panel.dart), and
[quick events](../../lib/widgets/quick_events_panel.dart).

## One place to manage toolsets

Add a labeled **Tools** button beside the workflow selector on wide screens.
Use **App menu > Tools** on compact screens. It opens a checklist and remains
open while users change several choices. On touch, use a sheet with a Done action.

Suggested Record menu:

```text
Tools                         Record
[x] Playback
[x] Quick events
[ ] Categories
[ ] Events list
------------------------------------
Workspace layout                  >
Keyboard shortcuts
```

The menu shows tools available in the current workflow. Drawing remains a
Review tool, consistent with the recent product decision. Track retains its
player/timer tools. Keyboard shortcuts is a help command rather than another
mandatory persistent panel.

Workspace layout contains Fit video between panels / Overlay panels on video,
layout presets, and Reset this workflow. Use those descriptive labels instead
of exposing the implementation term "squeeze." Keep file, account, and export
actions in the existing App menu.

### Visibility and placement rules

| Action/state | Behavior |
| --- | --- |
| Show | Restore the last position and size and expand the toolset. Clamp an off-screen floating position into the current workspace. |
| Hide | Remove the panel and its collapsed tab completely. Retain its configuration and last placement. Restore it through Tools. |
| Collapse | Keep a small, identifiable tab at the current edge. Clicking/tapping it expands the toolset. A floating panel reduces to its title strip. |
| Dock left/right/top/bottom | Move to that edge and keep the panel expanded. This is the pinned state. |
| Float | Restore the previous floating size/position, or use a safe default on first use. |
| Reset this workflow | Restore the recommended arrangement for the active workflow only. Offer Undo for the layout reset. |

Use a pin only for returning a floating tool to its remembered dock edge; its
tooltip should name that edge. Do not use the pin glyph as a generic menu icon.
The overflow menu offers explicit placement choices, Collapse, and Hide.
Automatic hover reveal is deferred: it adds interaction complexity and has no
direct touch equivalent.

Hiding Quick events removes its panel and launcher, not its configured presets.
Assigned shortcuts continue to work in Record, with feedback in the shared
capture status area. If users want to disable a shortcut, they clear its
assignment. Visibility and shortcut enablement should not silently redefine one
another. Text fields and modal editing continue to suppress capture shortcuts.

Hiding Drawing exits drawing input and returns the pointer to video interaction;
it does not erase annotations. A later explicit drawing shortcut can re-enter
drawing and show a small active-tool indicator with an exit action without
permanently changing panel visibility.

## Adapt the contents, not just the panel direction

Give toolsets one of two presentation types: **toolbar** for small commands,
**content panel** for choices, lists, and editors. Both remain dockable.

| Placement | Toolbar behavior | Content-panel behavior |
| --- | --- | --- |
| Left/right | Two-column tool grid in a normal dock; single column only in an explicitly slim rail | Labeled rows or a responsive grid; independently scrolling content |
| Top/bottom | One compact row; essential actions stay visible; secondary actions use More | One/two rows of labeled items with explicit paging or scrolling; open detail outside the shallow strip |
| Floating | Compact horizontal palette by default; adapt to usable width | Resizable card with title and content; preserve search and draft state while moving |
| Compact window | Bottom toolbar | One active content surface with tabs for visible toolsets; expandable sheet for detailed entry |

Use the existing 48 px minimum touch targets and roughly 20-24 px glyphs.
Reduce wasted space through grouping and disclosure, not smaller hit areas.
Compact desktop density can follow later, but attaching a mouse to a tablet
must not make its targets too small for touch.

Toolbar framing should contain an identity/drag grip and one overflow action;
collapse can live in that menu. Content panels retain a readable title and direct
collapse action. Float dragging remains restricted to the grip/title; pressing a
tool or category must never initiate a drag. Placement is always available via
the menu, including on touch.

Collapsed side tabs retain horizontal icon-and-label text, avoiding rotated
labels. When every tool on an edge is collapsed, reduce the edge to its tab
strip. If any expanded panel needs a wider dock, retain that shared width.
Hidden panels consume no edge space.

A normal side dock should share height among its expanded content panels, with
each panel scrolling internally. For two tagging panels, start with an even
split and allow a divider adjustment. Keep both headers reachable. Save explicit
order and support Move before/after from the menu; drag ordering can follow.
On compact screens use tabs rather than several stacked scrolling toolsets.

Allocate sizes from panel minimum/preferred dimensions, available width and
height, text scale, and safe areas. Preserve the existing disjoint dock geometry.
Do not overwrite a saved wide-screen placement merely because a narrow fallback
is currently rendered.

## Categories as an independent Record toolset

Create a Categories toolset next to Quick events in Tools. Users may show either,
both, or neither. Default Categories to hidden for existing quick-tagging users;
provide a Full tagging arrangement that opens it immediately.

Categories shows every capture-eligible category from the active sport taxonomy,
using its label, icon, and color. Preserve taxonomy order and the existing rule
that historical/non-capture types are not offered for new events. "All" means
the complete available set, with scrolling when needed; it does not mean forcing
arbitrarily many categories into one viewport.

Use full labels by default. A symbol alone is too ambiguous for sports concepts,
particularly when players are still learning the vocabulary. Category color is
a supporting cue, not the only identifier. Put search behind a Find action in a
shallow toolbar; allow a persistent search field in a taller content panel.
Do not reorder categories based on usage while someone is tagging.

### Entry behavior

1. Selecting a category captures the video time immediately and starts one draft.
2. Select an event type, then grade/context using the existing entry semantics.
   Keep definitions available for less familiar terminology.
3. Save commits that draft and returns focus to the category choices. Cancel
   discards only the draft. Playback behavior remains consistent with existing
   full entry; Quick events continues to capture without pausing.
4. Present the editor inside a sufficiently large panel, or in an anchored
   adjacent surface when a toolbar is too shallow. On narrow screens use a sheet.
   Provide Back to categories and Cancel; never time out unfinished entry.

On wide layouts keep the category grid visible beside the editor when space
permits. On smaller layouts the editor temporarily replaces the panel contents.
The panel returns to the same category search and scroll position after entry.

Quick events must no longer transform into Categories when Alt entry begins.
If Categories is visible, numbered entry uses it. If hidden, show a temporary
entry surface without changing its saved visibility. Keep the existing paged
Alt/number mapping and visible stage/page indicators.

Move the last-recorded message, timestamp, Edit, and Undo into a reserved capture
status slot near the timeline. Its updates must not move tagging buttons. This
also gives keyboard-only users feedback when both tagging panels are hidden.

Only one event draft should be active across the category panel, transient
keyboard entry, and editor. If users hide its host, retain the draft and provide
a Resume event entry action in the status slot. Cancel remains explicit; a
visibility change must not silently commit or discard work.

### Record layout sketches

```text
Quick tagging (preserves the current arrangement)
+-------------------------------------------------------------+
| Flow Lens          Record  Review  Track       Tools    ...  |
+----------+-------------------------------------+-------------+
| Playback |                                     | Quick events|
|          |                VIDEO                | labeled     |
|          |                                     | choices     |
+----------+-------------------------------------+-------------+
| Timeline / capture status: Recorded ...          Edit  Undo  |
+-------------------------------------------------------------+

Full tagging (Quick events can be completely hidden)
+-------------------------------------------------------------+
| Flow Lens          Record  Review  Track       Tools    ...  |
+----------+-------------------------------------+-------------+
| Playback |                                     | Categories  |
|          |                VIDEO                | full labels |
|          |                                     | + entry     |
+----------+-------------------------------------+-------------+
| Timeline / capture status                                   |
+-------------------------------------------------------------+
```

When both are visible, they can share a divided right dock or occupy separate
edges, for example Quick events right and Categories bottom. Do not duplicate
the All events dialog as a second competing editor. The existing All events
action should open the shared category-entry surface, with Keep open to make
Categories a persistent toolset.

## Drawing for explanation, with less space

Replace the separate Draw toggle followed by tool selection with direct choices:
**Pointer, Pen, Line, Arrow, Laser**. Pointer means normal video interaction;
it does not promise shape selection or editing. Selecting an annotation tool
enters drawing input. Escape returns to Pointer after dismissing any open menu.

Group the palette into tool selection, appearance, and history/actions:

```text
Wide Review toolbar (labels stand in for icons)
[grip] Pointer Pen Line Arrow Laser | Color v | Undo Redo | ...

Side dock / compact floating card
Drawing                                      ...
[Pointer] [Pen   ]
[Line   ] [Arrow ]
[Laser  ] [Color ]
[Undo   ] [Redo  ]
```

The grid uses existing side width productively and is roughly half the height
of the current expanded one-column sequence. A genuinely narrow rail remains
available where that buys meaningful video width. A horizontal palette falls
back to tool grouping/More before resorting to scrolling every command.

Keep only the current color swatch visible. Its popover contains the existing
colors with names, selection checks, and 48 px targets. Add line-width options
there when width changes are implemented. Expose only properties supported by
the selected tool; do not imply persistent-stroke behavior for the fading laser.
Persistent ink color and laser color should retain separate preferences.

Move Reset zoom to Playback/view controls and label it **Fit video**. Move
Clear drawings into More. Make Clear reversible with drawing Undo rather than
putting an oversized destructive control beside frequently used tools.

Undo/Redo must operate on completed annotation actions in chronological order
across pen, line, and arrow, including a reversible clear. Laser trails remain
ephemeral and do not fill that history. A new action after Undo clears Redo.
Scope this history to the loaded video and expose it through a drawing
ChangeNotifier. A menu color change is not an annotation-history action.

Keep visible tool selection, selected semantics, tooltips with current shortcuts,
and a distinct video cursor. Remove floating blue shortcut bubbles from every
tool; show keys in tooltips and a deliberate keyboard-hints view. On touch, an
expanded chooser can provide tool names without relying on hover.

Keep the existing laser throttling/fade, point reduction, RepaintBoundary
isolation, and fitted-video coordinate conversion. Changing a dock must not
shift annotations relative to the video or leave input active outside Review.

Annotation persistence tied to an event/clip is a separate product capability.
This palette update must not imply that current temporary drawings are stored
with exported events. Seek/playback clearing behavior should be made explicit
in a later annotation-lifecycle design rather than changed incidentally here.

## A presentation layout for coaching calls

Offer **Present** from Review's workspace choices. It is a temporary display
arrangement, not another permanent top-level workflow or a conferencing feature.

```text
+-------------------------------------------------------------+
| Review: current event                         Tools   Exit   |
|                                                             |
|                         VIDEO                               |
|                                                             |
+-------------------------------------------------------------+
| Previous event   Play / Pause   Next event   Speed   Timeline |
| Pointer  Pen  Line  Arrow  Laser       Color   Undo   ...     |
+-------------------------------------------------------------+
```

Hide tagging, tracking, and configuration surfaces temporarily. Keep the event
label, timestamp, and navigation through the active filtered sequence visible.
Allow the coach to reveal the event list when needed. Prefer a fixed strip
outside the video over automatically appearing controls that cover the play.

The layout supports a practical teaching loop: replay the lead-in, pause at the
decision, point or draw, undo/clear, and continue to the outcome or next event.
Preserve existing event preview lead-in/out, filters, and zoom restoration.

Entering Present keeps the current playback position/state and Review filters.
Exiting restores the previous layout without reverting playback progress or
event changes made during the discussion. Do not persist temporary hiding into
the user's normal Review workspace. Keep Exit reachable even when panels are
hidden. Use a larger readable control profile for screen sharing.

External call software shares the app window; there is no implied private
presenter surface. Dual-window output, shared cursors, multiplayer annotation,
and event-linked drawing storage are outside this update.

## Suggested implementation slices

| Slice | Concrete scope | Completion check |
| --- | --- | --- |
| 1. Tool visibility and Categories | Tools checklist; panel Hide/restore; separate Quick events/Categories IDs; shared entry host; shared capture feedback; retain existing geometry. | Quick events can disappear completely while Categories, keyboard entry, Edit, and Undo remain usable. |
| 2. Adaptive framing and drawing palette | Toolbar/content variants; panel-specific size contracts; shared-edge height allocation and order; compact-layout tabs; tool grid and color popover; Pointer and Fit video semantics. | All four dock edges and floating work without unreachable primary actions, including multiple toolsets on the same edge. |
| 3. Drawing history | Scoped drawing controller and ordered Undo/Redo; reversible Clear; width controls where supported. | Mixed pen/line/arrow history, Clear, and Redo behave correctly without laser trails polluting history. |
| 4. Review/presentation consolidation | Move Events list into workspace sizing; reconcile Shortcuts help; temporary Present arrangement and restoration. | A coach can review a filtered sequence, annotate, and exit Present with their workspace intact. |

Keep future hover auto-hide, arbitrary nested/tabbed desktop docking, named custom
layout libraries, shape editing, and multi-window presentation out of the initial
slices. They are not prerequisites for this request.

### State and migration

- Add stable tool IDs for Quick events and Categories. Map legacy `eventButtons`
  placement/visibility to Quick events because that ID currently hosts it; do not
  rename the serialized key and lose saved layouts. Initialize Categories hidden.
- Centralize labels, icons, applicable workflows, presentation type, and size
  contracts in a small toolset registry. Build the checklist and workspace from
  the same definitions so a menu item cannot claim to show an unavailable tool.
- Keep user visibility, collapse, and placement independent. Add explicit order
  and remembered dock edge where needed. Transient entry and presentation state
  must not be serialized as user layout preferences.
- Continue immutable copyWith state and ChangeNotifier updates. Keep draft data
  outside widgets so reparenting, hiding, and adaptive reflow cannot discard it.
- Version any changed persisted layout schema, retain old-key migration, tolerate
  missing/unknown entries, and test per-workflow restoration. Save deliberate
  layout changes, not every resize frame or responsive fallback.
- Use current FlowTheme surfaces, borders, and accents. Keep selected tools
  distinct from taxonomy colors and grading meaning. Use consistent Material
  icons; new icon dependencies are unnecessary.

## Validation and acceptance

Test these behaviors during implementation; they are not claimed as delivered:

- Hide, restore, collapse, float, dock, restart, and change workflows without
  losing geometry, category state, or quick presets. Restore hidden tools in no
  more than Tools plus one selection.
- Exercise category entry with Quick events hidden, both visible, both hidden
  using Alt entry, and a draft active during reflow/hide. Verify one draft and
  the timestamp from the initial category action.
- Confirm a quick capture remains one action and never changes playback speed
  or pauses playback. Capture feedback cannot move the next target.
- Verify wide and short desktop windows, tablet landscape/portrait/Split View,
  compact phone fallback, large text, and keyboard traversal. Include real iPad
  Safari and native iPad validation when hardware/build tooling is available.
- Test all five placements with expanded/collapsed toolsets, long translated
  labels, many categories, empty quick menus, and multiple same-edge panels.
  Primary playback remains reachable even if the Playback toolset is hidden,
  through a minimal Play/Pause control in the persistent video/timeline chrome.
- Validate color-picker focus return, selected-state semantics, named colors,
  touch targets, and discoverability without hover. Keep scrolling within tool
  content from changing video controls.
- Verify drawing Undo/Redo and Clear, mode-exit input cleanup, and alignment
  after docking/resizing. Compare rendering responsiveness against the existing
  performance baseline; palette state changes must not rebuild the video engine.
- Test Present entry/exit, viewport changes, filtered event navigation, and
  layout restoration while playback position continues normally.

For a short usability session, ask a coach to hide Quick events, pin Categories,
record three events, find an earlier play, explain it with Arrow/Laser, and return
to normal review. Measure errors and time spent managing panels as well as task
time. Success means attention stays on the play and the decision being taught.

Related work: [docking foundation](../docking-workspace-refactor/README.md),
[quick-tagging implementation](../touch-quick-tagging/implementation.md), and
[visual principles](../visual-design-system/design-principles.md).
