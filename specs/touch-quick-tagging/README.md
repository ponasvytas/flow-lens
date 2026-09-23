# Touch layouts and quick event tagging

Status: proposed implementation plan, 2026-09-13. Branch: `touch-quick-tagging`.
The first functional slice is implemented; see [implementation status and remaining work](implementation.md).

## Product decisions

- Primary task: watch footage quickly and record selected important moments;
  detailed analysis follows in Review.
- Confirmed: a quick event records immediately while playback continues.
- Confirmed: reusable presets plus an independent selection for each game.
- Confirmed: Safari/home-screen web use and the installed iPad app have equal
  priority. Validate both on real iPads.
- Default landscape layout: playback on the left, quick events on the right.
- Full taxonomy entry remains available at the bottom of Quick events.
- Drawing is available only in Review, including keyboard and touch entry points.

## Evidence and current workflows

This is a source review, supported by the repository's earlier
[visual audit](../visual-design-system/visual-audit-results.md). That audit predates
the latest docking work; its observations are historical, not a new device test.
No new live iPad or browser visual audit was performed for this plan.

| Area | Current behavior | Consequence / proposed change |
| --- | --- | --- |
| Start | Sport selection, local video, demo or URL; optional account/cloud sessions | Apply the responsive header and dialog rules here too; keep local workflows available |
| Record | Category button creates a draft at the video position; SmartHUD selects type and grade; complete events enter EventsController | Quick action creates a complete normal event directly; full entry remains staged |
| Event taxonomy | Hockey already includes `shot_on_net`, `shot_wide`, `shot_blocked`, with default grades | Reuse stable taxonomy IDs and combine category/type labels; do not add hockey-specific UI logic |
| Event entry panel | Default floating size 640 x 118; fixed horizontal row of 80 x 60 category buttons, including in side docks | Provide vertical, grid, and horizontal variants based on available space |
| SmartHUD | 300-wide floating editor over lower video; four-second dismiss timer outside latched keyboard entry | Move full entry into a deliberate panel/sheet; never time out an unfinished touch draft |
| Playback | Default 320 x 170 float; five fixed speed chips and seven jump/play controls; side docks stack all controls | Show the few primary actions first; move secondary speeds/jumps into More |
| Playback parity | Keyboard S/D/F uses configured slow/default/fast speeds; touch chips use fixed rates and show no selected-rate state | One shared playback command/state path, with current speed visible |
| Docking | Per-mode visibility, collapse, position, size, and overlay/squeeze persistence; defaults float | Use adaptive defaults and retain explicit custom layouts; separate layout profiles by window class |
| Panel chrome | 32-high title strips, small collapse/dock glyph hit areas, 8-wide resize handles | 48-high touch header/actions; touch layout choices do not require precision dragging |
| Dock geometry | Generic minimum side extent 180 and center 320 x 220 | Slim playback rail needs panel-specific size contracts; shrinking generic docks alone is insufficient |
| Review | Filtered chronological events, previous/next, lead-in/out preview, stored zoom restoration, table/filter/export access | Keep these behaviors, with an adaptive list/detail surface |
| Events list | Separate fixed 340-wide drawer outside DockLayout; table uses an 800 x 600 dialog | Include list width in workspace budgeting; use list/sheet presentation on narrow windows |
| Drawing | Default 300 x 250 float; vertical tools; 32/36 tool buttons and 26 color swatches | Collapsed Draw entry by default, adaptive palette with 48 touch targets |
| Mode boundaries | Drawing panel hidden in Record, but G/C/K and drawing tool shortcuts still work there; mode switching does not clear drawing mode | Enforce Review-only drawing at command and canvas levels; leaving Review exits input capture |
| Track | Separate player/team counters and toggle/hold timers, tracker presets and hotkeys; default 420 x 520 float | Preserve as a distinct workflow; do not confuse it with quick event tagging |
| Shell | No explicit MaterialApp theme; long header action row, mixed hard-coded surfaces/colors | Establish one Material 3 theme and responsive shell before broad restyling |
| Persistence | Local event JSON is an exported list, not durable game storage; cloud event sessions exist | Per-game quick menus need an explicit local session identity and recovery strategy |

Principal source files: `lib/main.dart`, `lib/controllers/ui_controller.dart`,
`lib/controllers/events_controller.dart`, `lib/widgets/dock_layout.dart`,
`lib/widgets/dockable_panel.dart`, `lib/widgets/control_bar.dart`,
`lib/widgets/event_buttons_panel.dart`, `lib/widgets/smart_hud.dart`,
`lib/widgets/drawing_tools_panel.dart`, `lib/widgets/event_navigation_panel.dart`,
`lib/widgets/docked_events_panel.dart`, `lib/widgets/player_tracking_panel.dart`,
`lib/models/game_event.dart`, `lib/services/event_storage_service.dart`.

## Proposed layouts and size budget

All sizes below are Flutter logical pixels, starting values to validate rather
than device-specific constants. Use available width **and height**, safe-area
insets, text scale and pointer capabilities. An iPad with a keyboard still needs
touch-size controls. Rotation, browser chrome and Split View must trigger reflow.

| Surface | Landscape tablet / touch desktop | Portrait tablet / narrow window | Phone |
| --- | --- | --- | --- |
| Header | 56 high; mode, game, overflow | 56 high; secondary actions in overflow | 56 high; compact mode selector |
| Playback | Left rail 88-104 wide, 56-64 primary buttons | Horizontal strip below video, 64-80 high | Same strip; 48 minimum targets |
| Quick events | Right rail 184-224 wide, 56-64 high full-label rows | Two/three-column grid below playback | Two columns, 56-64 high; long text wraps |
| Full entry | Right panel 320-400 wide, replaces quick rail temporarily | Bottom sheet, initially about half available height, expandable | Expandable sheet/full-screen picker |
| Review events | Right list 280-360 wide when space allows | List below video or sheet | List/sheet; detail is a separate sheet |
| Drawing | Collapsed Draw action; expanded 64-72 tool rail plus color popover, or 64-80 bottom toolbar | Bottom toolbar; color/options sheet | Bottom toolbar with secondary options in sheet |
| Floating playback | About 320 x 192, two compact rows | Prefer docked strip | No default floats |
| Floating event entry | About 360 x 420, adaptive type grid | Prefer sheet | No default floats |
| Floating drawing | About 304 x 240, tool grid and wrapped colors | Prefer toolbar | No default floats |
| Settings / export / preset editor | Bounded dialog 480-640 wide; height <= available height minus 48 | Sheet/dialog sized to window | Full-screen route/sheet with safe-area footer |

Landscape two-rail layout is the starting candidate when usable width is at least
900 and usable height at least 500. After header, timeline, rail widths and gaps
are subtracted, require a video box of at least approximately 560 x 315 for a
16:9 source. Otherwise reflow to stacked controls. The actual video fits its source
aspect ratio without cropping. These constraints override the breakpoint.

Example: a 1024-wide window with 88 playback + 184 quick events + 24 total gaps
leaves 728 for the video (about 410 high at 16:9). At 768 portrait width, keeping
that same arrangement would leave only 472, so place the controls below the video.
Do not force landscape; show a useful portrait layout.

Reserve approximately 48-56 high for the timeline in the tagging workspace.
Use a 48-high scrub hit region even if the visible track is thin. Cluster crowded
markers and let the user choose from a nearby-event list rather than requiring a
precise tap on a tiny marker.

Keep the video unobscured by default using squeeze presentation. Allow an explicit
overlay/custom layout on larger windows. Rail contents align toward comfortable
hand reach without making key actions scroll offscreen. Recommend 3-6 quick items;
allow more through scrolling, with **All events** fixed at the bottom. Never shrink
targets to make an arbitrary number fit. A short window may use stacked controls
even in landscape.

Store layouts per workflow and compact/medium/expanded window class. Retain saved
custom desktop layouts; migrate version-1 layouts into the appropriate legacy
profile and provide Reset layout. Responsive adaptations must not overwrite a
user's larger-window layout. Dock menus offer explicit edge, reset, collapse and
overlay choices. Reordering or docking must not require drag as the only method.

## Quick-event interaction contract

1. Start with **Choose quick events**, offering a sport-appropriate starter preset
   (the hockey example is Shots) and an All events path. Applying a preset copies
   its ordered actions into the game; subsequent game edits do not modify it.
2. Each action resolves sport/category/type IDs and an explicit grade policy.
   Default recommendation: taxonomy default grade; allow a per-action override.
   If a taxonomy type lacks a default, ask once during setup. No extra grading
   prompt occurs during capture. Show the configured grade in the editor.
3. Tap captures the current video timestamp and zoom context immediately and adds
   exactly one complete GameEvent. Preserve playback rate, playing/paused state,
   mute and focus. Use collision-resistant IDs; timestamp-only IDs are inadequate
   for simultaneous input. Intentional rapid taps may create separate events.
4. Give brief button feedback plus a fixed, nonblocking last-event strip with
   label, time, Edit and Undo. Do not stack snackbars over the video or open SmartHUD
   on each tap. Undo targets the specific recorded event; keep correction available
   in recent events after the transient feedback fades.
5. Persist capture locally in sequence without blocking the next tap. Distinguish
   recorded-in-session, locally saved, and explicit cloud-save state; never report
   cloud success on a local write. Retain dirty state and a retry path on failure.
6. **All events** at the bottom opens category/type entry, with search and visible
   Add to quick actions. Pinning configures the menu; it does not record an event.
   Full entry captures a draft timestamp when a category/type is chosen, visibly
   distinguishes draft from recorded state, and offers Save/Cancel without timeout.
   Keyboard staged completion can remain fast and automatic on its final choice.
7. **Edit quick menu** supports add, remove with Undo, drag reorder via handles,
   Move up/down, grade override, hotkey assign/change/clear, and reset from preset.
   Capture is disabled within the editor so rearranging never records an event.
8. Presets support create from current menu, rename, duplicate, update explicitly,
   delete, and apply to a game. Menu edits autosave; preset updates are explicit.
   Deleting a preset or menu item never removes historical events or copied menus.
9. Duplicate identical actions are prevented. Different grade variants may coexist
   with labels that distinguish them. Missing taxonomy items stay visible as
   unavailable with repair/remove actions; never silently remap IDs.
10. Reorder never changes an explicitly assigned hotkey. Optional slot shortcuts
    should not be added unless their different behavior is explained clearly.

Do not require a grade choice or player attribution on every tap. Existing grades
are judgments (e.g. Wide defaults negative), not objective shot outcomes; keep
outcome labels visually primary and make default grading configurable. Later
Review can correct details and grade through the normal event model.

## Playback and keyboard

Left primary actions: Play/pause, Back (initial recommendation 5 seconds), Slow
(configured 0.5x), Normal (configured 1x), Fast (configured 3x). The last three
show selected state. Secondary menu retains +/-3, +/-10, +/-30, other rates and
mute. Keep existing desktop shortcuts unless a separate change is agreed.

Touch Fast is an explicit rate toggle with Normal always visible. Also support
hold-to-fast for parity with keyboard F; release/cancel, focus loss, app background
or mode change must restore the prior rate and mute state. A toggle alternative
ensures holding is never required. Multi-touch must support left-hand hold plus
right-hand event tap without either input stealing the other.

Extract a scoped shortcut registry/dispatcher rather than extending the long root
handler. Bind quick actions only in Record and outside text fields, dialogs,
menu editing and latched Alt entry. Capture user key assignments, show conflicts,
offer reassignment and clear, and handle keyboard layouts and Cmd/Ctrl/Alt/Meta.
Reserve playback, navigation, browser/OS combinations and active workflow commands.
Initial suggestions can be J/K/L for the three shot actions after K becomes
Review-only; these are editable suggestions, not a new global binding contract.
Ignore key-repeat for event creation. Display assigned keys on buttons when useful
and list them in keyboard help. Preserve Track timer release behavior.

## Review, drawing and surrounding workflows

- Keep Record, Review and Track as task modes; no extra Coach/Player/Analyst mode
  matrix is needed for this release. Consider clearer visible labels Tag and
  Player tracking later while preserving stored enum values.
- Review swaps quick events for previous/next, filter summary, current-event
  detail and optional list. Preserve position/rate and existing lead-in/out and
  saved-view behavior across layout changes.
- Enter drawing deliberately from Draw; expose active tool and Done. Tool/color
  controls have 48 minimum hit targets, with visual swatches allowed to be smaller.
  Prefer horizontal groups/grids over one long vertical stack of every color.
- Add drawing undo/redo as a separate implementation slice; keep Clear all apart
  from ordinary tools and make it reversible. Existing strokes are not currently
  per-event persisted annotations; that larger feature is not implied here.
- Leaving Review ends drawing/laser input capture while retaining existing marks
  for returning to Review; annotations do not intercept tagging touches.
- Define pinch/pan versus finger drawing deliberately and test Apple Pencil.
  A pen-only option should depend on reliable pointer support; do not promise
  identical palm rejection between Safari and native Flutter.
- Track gets the shared touch controls, active-subject cards and a setup sheet;
  preserve counters/timers, hotkeys, CSV and session operations.
- Give events filters, import/export, settings, account and cloud-session dialogs
  bounded scrollable content and reachable fixed actions. On phones use event
  cards with filter/sort controls instead of compressing desktop table columns.
- Validate start/load/save/reopen as well as the loaded-video workspace, including
  native iPad file pickers and Safari file access, backgrounding and recovery.

## Visual direction

Use Material 3 plus a small Flow Lens token layer and the existing Material icons.
No external design service or new component framework is required. Optional Figma
work can refine branding or support stakeholder review; a Flutter prototype should
be the authority for fit, touch behavior and text scaling.

Recommended starting palette: stage `#0B1016`, panels `#18222E`, raised surfaces
`#243244`, primary text `#F3F6FA`, secondary text `#B6C2D2`, accent `#BA9CFF`.
Keep purple as a restrained brand/selection accent instead of a dominant header
gradient. Validate actual color pairs for normal-text 4.5:1 and UI/focus 3:1
contrast before choosing final tokens. Event-category color is a small content
cue; labels and icons carry meaning. Grade is not conveyed by color alone.

Use 14-16 control text, 12-13 metadata, 20-24 icons inside 48 minimum targets,
8-pixel control gaps, 8-12 corner radii and a 4/8/12/16/24 spacing scale. Allow
text growth/wrapping and responsive reflow up to 200% scaling. Keep visible focus,
screen-reader labels, move actions for reorder, reduced motion, and explicit
pressed/selected/disabled states.

[Open the interactive layout wireframe](wireframe.html). It demonstrates the
landscape/stacked layouts, basic quick capture/Undo and full-menu expansion with
synthetic footage. It is a design aid, not production behavior or device validation.

## Implementation sequence

1. **Theme, shared controls and responsive shell.** Build tokens, 48-pixel touch
   primitives, compact header, panel size contracts and adaptive layout profiles.
   Prototype landscape and portrait Record with synthetic video. Acceptance:
   readable controls, unobscured video, no overflow or lost controls on resize.
2. **Quick actions and presets.** Add immutable quick-action/preset models,
   ChangeNotifier controller, local repositories and a small shared event-creation
   command. Add quick rail/grid, full-entry expansion, preset/menu editor,
   timestamp-preserving capture and Undo. Enforce Review-only drawing. Acceptance:
   the three-shot workflow works end to end while playback continues.
3. **Session persistence and shortcut integration.** Introduce explicit local game
   identity (never temporary blob URL), durable recovery and per-game menu copies.
   Preserve legacy event-list import/export; use a versioned session format for
   menu metadata. Keep cloud fields/rules changes explicit and separately tested;
   no cloud dependency for basic tagging. Add assignment/conflict UI and scoped
   keyboard dispatch. Acceptance: reload/reopen restores actions/order/keys, and
   every quick action reaches the same timeline/filter/review/export path.
4. **Review and remaining surfaces.** Adaptive event list/detail/filter UI,
   collapsed drawing palette, undo/redo slice, shared dialog layouts and Track
   touch sizing. Acceptance: complete tag -> review -> correct -> export journey
   on touch and keyboard; no inaccessible modal footer.
5. **Device validation and polish.** Run the matrix below, tune dimensions from
   observed fit, then migrate defaults and offer reset. Do not call the work
   complete from desktop viewport emulation alone.

Keep scoped ChangeNotifiers and existing conditional platform imports. Preserve
laser throttling/fades, drawing point reduction, RepaintBoundary isolation, scroll
interception and seek coordination. Quick capture must not rebuild the whole
video tree or add work on every playback tick.

## Validation and definition of done

- Automated: meaningful controller tests for exact-once capture, timestamp/grade,
  rapid taps, Undo identity, preset-copy isolation, persistence/migration, missing
  taxonomy IDs, keyboard conflicts/repeats/focus and background cancellation.
- Widget/layout: landscape and portrait at 1024 x 768, 1180 x 820, 1366 x 1024;
  phone 390 x 844 and short landscape; narrow Split View; desktop 1280 x 720 and
  1920 x 1080; 100/150/200% text scale. Check target bounds, scrolling, fixed All
  events/footer reachability, focused control visibility and video budget.
- Real devices: iPad Safari, home-screen web app and native iPad; touch plus
  hardware keyboard/trackpad and Pencil; rotation, browser chrome, safe areas,
  onscreen keyboard, simultaneous hold-and-tag and background/resume.
- Workflow: load local video -> choose three actions -> slow/back/fast -> record
  20 rapid events -> Undo/edit -> reorder/add/remove -> reopen game -> switch
  Review -> filter/navigate/draw -> export/reimport. Check timers in Track too.
- Regression: format, Flutter analyze, relevant tests and existing full suite;
  web/Windows builds locally and iOS build/device checks on macOS tooling.
- Performance: compare existing profiling counters for seeks, video rebuilds,
  drawing and laser; capture feedback should appear by the next practical frame,
  independent of file/cloud writes. Measure on hardware before setting a strict
  latency promise.

## Relationship to existing plans

This plan specializes the [visual design foundation](../visual-design-system/README.md)
for the user's confirmed tagging workflow. Prefer its adaptive size/height rules
and three existing task modes over the older device-name breakpoints and proposed
persona mode matrix. Reuse the delivered docking engine, updating its size
contracts and persistence rather than replacing it wholesale.
