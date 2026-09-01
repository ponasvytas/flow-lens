# Visual Audit Results

Date: 2026-08-09

Target: `http://localhost:52307/`

Method: Playwright-driven browser audit against the running Flutter web app.

## Captured screenshots

Screenshots were saved under `specs/visual-design-system/audit-screenshots/`.

- `desktop-01-sport-selection.png`
- `desktop-02-hockey-picker.png`
- `desktop-03-demo-video-attempt.png`
- `wide-desktop-01-sport-selection.png`
- `wide-desktop-02-hockey-picker.png`
- `tablet-01-sport-selection.png`
- `tablet-02-hockey-picker.png`
- `phone-01-sport-selection.png`
- `phone-02-hockey-picker.png`
- `desktop-04-loaded-video-record.png`
- `desktop-05-loaded-video-review.png`
- `desktop-06-loaded-video-track.png`
- `desktop-07-settings-attempt.png`
- `desktop-08-export-attempt.png`
- `tablet-03-loaded-video-current.png`
- `phone-03-loaded-video-current.png`
- `desktop-09-record-after-shot-event.png`
- `desktop-10-alt-smart-hud-attempt.png`
- `desktop-11-review-after-shot-event.png`
- `desktop-12-sign-in-screen.png`
- `desktop-13-settings-view.png`
- `desktop-14-export-dialog.png`
- `desktop-15-event-created-state.png`
- `desktop-16-smart-hud-active.png`
- `desktop-17-drawing-in-progress.png`

## Automation summary

Successful automated steps:

- Opened the running local web app.
- Captured sport-selection screenshots at desktop, wide desktop, tablet, and
  phone viewports.
- Selected Ice Hockey by coordinate automation.
- Captured the hockey video-picker screen at desktop, wide desktop, tablet, and
  phone viewports.
- Attempted the demo-video path and captured the resulting app shell.
- Continued after manual local video load.
- Captured the loaded-video shell in Record, Review, and Track modes.
- Captured tablet and phone loaded-video responsive states.
- Captured sign-in and Settings states from the restarted local server.
- Captured Export dialog after manual navigation.
- Captured Record mode with an event-created/editing state visible.
- Captured Smart HUD active state during staged event entry.
- Captured drawing in progress with annotations over live video.

Blocked automated steps:

- Local sample-file upload did not trigger a Playwright `filechooser` event from
  coordinate automation.
- Flutter accessibility semantics exposed an `Enable accessibility` placeholder,
  but the helper click could not activate it because the placeholder resolved
  outside the viewport.
- Deeper loaded-video states could not be fully audited from the local sample
  file without manual navigation.
- Settings and export clicks did not open their target surfaces from the
  coordinate-based automation pass.
- Coordinate attempts to add a shot event and trigger the Alt Smart HUD did not
  reach the intended state after the app remained in Track mode with the events
  side panel open.

## Console/runtime findings

- The app emitted repeated debug/development boot logs during viewport reloads.
- The demo-video attempt logged `NotAllowedError, Wake Lock permission request denied`.
- The remote demo video request failed with `net::ERR_BLOCKED_BY_ORB` against the
  Firebase Storage URL.

The remote-video failure means the automated audit could not rely on the demo
video to reach all loaded-video states.

## Visual findings

### Sport selection

Primary visual problems:

- The title bar uses a saturated purple gradient and high-contrast brand block,
  while the main area is nearly black and sparse. The relationship feels more
  like separate pieces than one designed shell.
- Sport cards use bright white Material-style cards on a black stage. They are
  readable, but the contrast is abrupt and not yet integrated with the video-tool
  surface language.
- Coming-soon cards appear disabled, but their disabled state is generic grey and
  not tied to a design token.
- The debug banner and Flutter overflow indicators dominate mobile screenshots,
  which can hide real design issues during audit runs.

Primary usability problems:

- Phone sport selection overflows vertically. The debug screenshot reports a
  bottom overflow by 245 pixels.
- On phone width, the top mode control and debug banner overlap the available
  header area.
- The title bar consumes meaningful vertical space on small screens before the
  user reaches sport selection.

Design-system fixes:

- Define shell/header tokens for height, background, border, and active mode
  state.
- Define card tokens for sport selection, disabled cards, and focus/selected
  borders.
- Add responsive sport-selection layout rules for phone height.
- Create an audit build/profile mode without the debug banner for clean visual
  capture.

### Hockey video picker

Primary visual problems:

- The video-picker controls are centered in a large black empty stage, but the
  component hierarchy feels thin: icon/title, one light button, one green button,
  divider, URL field.
- Button colors are not part of an obvious shared system. The green demo button
  feels unrelated to the purple brand/header.
- The URL field border and placeholder styling are low contrast relative to the
  rest of the controls.

Primary usability problems:

- The local file button is hard for automation to activate because Flutter web
  semantics are not exposing a stable file chooser path.
- The picker does not provide much guidance about the difference between local
  file, demo video, and URL workflows.

Design-system fixes:

- Define primary, secondary, success/demo, field, divider, and helper-text
  tokens.
- Consider converting first-run video loading into a clearer task panel or
  bottom sheet on small screens.
- Ensure file picker controls are reachable by semantics or add test IDs if a
  future automation strategy supports them.

### Loaded shell via demo attempt

Primary visual problems:

- The top bar, playback panel, event-entry panel, and timeline each use separate
  color/spacing languages.
- The event buttons are vivid and useful, but the color palette is arbitrary:
  orange, cyan, red, blue, teal, purple, and yellow all compete equally.
- Floating panel chrome is functional but visually heavy, with small icons and
  borders that do not yet feel like a refined product surface.
- The white page area to the right/below the black app stage indicates viewport
  or canvas sizing issues in the captured desktop state.

Primary usability problems:

- The demo video did not load, leaving a loaded-shell-like state without actual
  footage.
- Timeline shows `00:00` to `00:00`, so meaningful loaded-video review states
  remain unaudited.

Design-system fixes:

- Define one panel surface system for floating and docked controls.
- Convert event-category colors into semantic taxonomy tokens with contrast
  rules.
- Define the video stage as a full-viewport layout primitive to avoid white page
  exposure.
- Audit loaded-video states manually or with a working local file upload path.

### Loaded video shell

Primary visual problems:

- The video itself is compelling and should clearly be the center of the product,
  but the surrounding shell does not yet frame it cleanly.
- The top purple app bar, black video stage, translucent floating panels,
  saturated event buttons, and right events drawer each feel like separate visual
  systems.
- Floating panels obscure meaningful parts of the video. The Playback panel and
  Event Entry panel are useful, but their default placement and opacity compete
  with the footage.
- The page can expose white browser background outside the app/video stage in
  desktop captures, which breaks the immersive analysis-room feel.
- Event category colors are highly visible, but the palette is too evenly loud;
  Shot, Pass, Battle, Defense, Goalie, Team Play, and Penalty all compete for the
  same level of attention.

Primary usability problems:

- Record mode is functionally clear on desktop, but the main event panel floats
  across the middle of the video and can cover play context.
- Review mode opens multiple overlays at once: Playback, Event Navigation, and
  Drawing. This is powerful for coaches but too much for a simple reviewer or
  young player.
- Tracking mode uses a large left tracking panel plus a right events drawer,
  leaving the video squeezed and partially obscured.
- The events side drawer is too dominant on tablet and phone. On phone, it takes
  almost the entire viewport while the video and controls are clipped to a thin
  left strip.
- Tablet layout shows the right events drawer consuming a large portion of the
  screen, with video and controls compressed on the left.

Design-system fixes:

- Define a responsive shell model with explicit desktop, tablet, and phone
  layouts instead of shrinking the desktop layout.
- Treat the video stage as the primary layout primitive; panels should dock,
  collapse, or become sheets without hiding the main video by default.
- Create separate default layouts for Coach, Player, Analyst, and Review modes.
- Add a panel surface token system: background opacity, border, header, drag
  affordance, icon color, and active state.
- Add event taxonomy color tokens with hierarchy rules so not every category is
  equally saturated.
- Create a mobile-first event drawer or bottom sheet that can be dismissed and
  does not permanently cover the video.

### Review mode

Primary visual problems:

- Playback, Event Navigation, and Drawing panels create a layered desktop-tool
  look that is dense but visually noisy.
- The Drawing panel appears in Review mode by default and covers the right side
  of the footage. This may be appropriate for advanced review but not for a
  simplified viewer mode.

Primary usability problems:

- With no events, the Review mode still shows several controls and panels. Empty
  review state should be calmer and more explanatory.
- Simple reviewers need a clear next action: jump between moments, inspect an
  event, or load/create events.

Design-system fixes:

- Split advanced coaching review from simple shared review.
- Use empty-state components for `No events` rather than dense disabled panels.
- Consider keeping drawing tools collapsed until explicitly requested.

### Tracking mode

Primary visual problems:

- The left Player Tracking panel and right Events drawer use different visual
  weight, opacity, and density.
- Icons in the tracking toolbar are small and low-contrast for touch use.

Primary usability problems:

- On desktop, Tracking mode obscures enough of the video that it is difficult to
  watch play while configuring or using trackers.
- On tablet and phone, Tracking mode is not currently touch-friendly. The events
  drawer and tracking panel dominate the video.

Design-system fixes:

- Design Tracking as its own mode layout rather than floating panels over a
  video-first record layout.
- Use larger touch targets and clearer tracker setup actions for Player mode.
- Put advanced tracking controls behind a setup panel or sheet on narrow
  screens.

### Automation attempts not completed

Settings, export, event creation, and Alt Smart HUD states were attempted by
coordinate automation but did not reach their intended surfaces in this pass.
They remain important for a follow-up audit, preferably with semantics/test IDs
or manual navigation.

### Settings view

Primary visual problems:

- Settings uses a large light modal over the dark video shell. It is readable,
  but it feels like a separate app surface rather than part of the same coaching
  tool.
- The modal radius, pale background, blue selected controls, purple sliders, and
  dark translucent playback panel behind it all come from different visual
  languages.
- The video behind Settings is heavily dimmed but still visually busy. The modal
  is legible, yet the backdrop does not feel intentionally designed.
- The close button, title icon, slider controls, and speed chips need shared
  token rules for icon color, selection state, radius, border, and focus.

Primary usability problems:

- Settings occupies most of the desktop viewport and covers the active video
  context. That may be acceptable for global preferences, but not for quick
  in-game adjustments.
- Playback settings are clear, but the screen does not visually distinguish
  quick coach adjustments from deeper app/account preferences.

Design-system fixes:

- Decide whether Settings should use a dark app-native modal or a deliberately
  light preferences surface. Do not mix both accidentally.
- Define modal/sheet tokens for background, scrim, radius, border, and title bar.
- Define chip/segmented-control tokens for selected, unselected, hover, and
  disabled states.
- Consider separating quick playback controls from full Settings so coaches can
  adjust speed behavior without entering a large modal.

### Export dialog

Primary visual problems:

- Export uses a light modal with a saturated purple header over a dimmed video
  shell and an Events drawer. Like Settings, it is readable but visually detached
  from the dark coaching workspace.
- The purple header, pale modal body, grey switches, purple sliders, checkbox
  controls, and disabled export button need one shared component/token system.
- The Events drawer remains visible behind the modal, producing a layered stack
  of purple header bars and grey surfaces. The hierarchy is understandable but
  visually busy.
- The disabled `Export Video` button is low contrast and appears cramped beside
  `Cancel` at the bottom edge of the modal.

Primary usability problems:

- The dialog is tall and appears vertically clipped at the bottom of the
  screenshot, suggesting risk on shorter desktop, tablet, or browser-window
  heights.
- Export has several advanced options in one vertical surface. This is useful for
  analysts, but a coach or player may need a simpler default export path.
- Per-event options are visually secondary but still consume meaningful vertical
  space.

Design-system fixes:

- Define export/settings modal patterns together rather than styling them as
  separate one-off dialogs.
- Add modal content scrolling and footer behavior that guarantees primary actions
  remain visible on smaller heights.
- Use a stronger disabled-action token and clearer explanation when export is not
  available.
- Consider `Simple export` and `Advanced export` sections so most users see fewer
  choices first.

### Event-created state

Primary visual problems:

- The event-created popover is functional and readable, but it introduces another
  floating black surface over the video in addition to the Playback panel and
  bottom category rail.
- The popover, event category rail, playback panel, and timeline markers use
  similar dark/translucent surfaces but different spacing, border, radius, and
  icon treatment.
- Event category colors are easy to distinguish, but every category button is
  highly saturated. The bottom rail draws attention away from the selected event
  editor and the video.
- Positive/negative/delete action buttons in the popover are visually clear, but
  their icon-button style does not yet feel part of a shared action system.
- Timeline markers at the bottom are visible, but their meaning is not visually
  connected to the selected event editor.

Primary usability problems:

- The selected event editor appears over the lower center of the video, covering
  the goal/crease area in this capture. That can hide exactly the play context a
  coach or player is tagging.
- The workflow mixes taxonomy selection, event editing, grade/action controls,
  and category rail controls in one area. It is powerful for coaches, but too
  dense for Player mode.
- The category rail is touch-friendly, but on smaller screens this same pattern
  will need to collapse or become a bottom sheet.

Design-system fixes:

- Define an event editor component with consistent header, action buttons,
  option chips, and danger action states.
- Add mode-specific variants: dense coach event editor and simplified player
  quick-action editor.
- Connect event timeline markers and the selected event state through color,
  shape, or active-state tokens.
- Reconsider default popover placement so it avoids covering critical video
  regions when possible.
- Tone down non-selected category buttons or reserve saturation for selected,
  active, or recently created states.

### Smart HUD active state

Primary visual problems:

- The Smart HUD popover successfully communicates staged keyboard entry with
  numbered options, but it visually overlaps with the persistent Event Entry
  rail and the video action area.
- The active popover, bottom event rail, and playback panel all use black
  translucent surfaces with slightly different shape, opacity, and spacing.
- Number badges are clear, but their bright blue style introduces another accent
  color competing with taxonomy colors and the purple brand.
- The selected category state in the bottom rail is partly obscured by the active
  HUD, making the relationship between rail and staged options harder to parse.

Primary usability problems:

- The HUD is useful for advanced keyboard tagging, but it is dense and assumes
  the user understands the staged workflow.
- The HUD appears near the lower-center/right video area, again covering key play
  context near the goal in this capture.
- For young-player or simple mode, this control pattern should likely be hidden
  or replaced by fewer quick actions.

Design-system fixes:

- Define Smart HUD as a first-class event-entry component rather than a generic
  dark popover.
- Use tokenized number badges that harmonize with the app accent system.
- Add mode variants: full staged HUD for Coach mode, simplified quick-action
  picker for Player mode.
- Consider anchoring the HUD to the event rail or moving it to a non-critical
  side region when video content allows.

### Drawing in progress

Primary visual problems:

- The purple annotation strokes are visible over the ice and communicate the
  coaching idea well, but the annotation color is close to the brand/header
  purple. This makes it unclear whether purple is brand, active tool, or drawing
  content.
- The drawing palette appears as a vertical rail on the far right edge. It is
  compact, but it feels disconnected from the rest of the panel system and is
  partially clipped by the viewport edge.
- Playback and Event Navigation panels remain visible over the annotated video,
  creating three simultaneous visual layers: controls, drawings, and footage.
- Drawing marks can cover important players and puck/play context. That is the
  purpose of annotations, but the UI should make clear which marks are active,
  selectable, temporary, or persistent.

Primary usability problems:

- The right-edge color/tool rail is not self-explanatory in the screenshot and
  may be hard to use on touch screens if it remains narrow.
- Review mode with drawing active still shows playback and navigation controls,
  which may be useful for coaches but heavy for players or shared reviewers.
- There is no visible distinction between drawing mode as an active app state and
  ordinary review playback beyond the drawn marks and right rail.

Design-system fixes:

- Separate brand accent color from drawing defaults. Use a drawing palette that
  is intentionally chosen for visibility over ice/video.
- Define drawing tool chrome as a first-class toolbar or sheet rather than a
  clipped edge rail.
- Add clear active-tool state, temporary annotation state, and clear/undo
  affordance tokens.
- Provide a simplified Review/Player drawing mode with fewer tools and larger
  touch targets.
- Consider hiding non-essential floating panels while drawing unless pinned by
  the user.

## Manual navigation status

Manual navigation was needed for parts of this audit because Flutter web file
selection and several advanced states were not reliably reachable by coordinate
automation.

Please use the active browser page and manually:

1. Select Ice Hockey if the app is not already on the hockey picker.
2. Click `Select Game Video`.
3. Choose `.local/hockey_videos/2026_06_10 12U Storm North vs Practice.mp4`.
4. Confirm the video loads and reaches the main player shell.

Manual navigation was completed for the local video load, Settings, Export,
Event-created, Smart HUD, and Drawing states. The initial Phase 00 visual
evidence set is complete enough to plan Phase 01.

Remaining optional follow-up audit targets are:

1. Phone-specific Player mode once a true Player/simple mode exists.
2. Tablet-specific drawing tools.
3. Account/sign-in flow variants after the premium cloud work settles.
4. Empty/error/loading states in release/profile mode without the debug banner.

## Recommended next action

Fix or work around local file automation after the manual capture pass. If this
workflow will be part of recurring visual audits, add a test/development-only way
to load a local or bundled fixture video without relying on the browser file
picker.
