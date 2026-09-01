# Redesign Phases

## Phase 00 - Automated visual audit and target direction

Objective: use Playwright or equivalent browser automation to capture current UI
screenshots, identify inconsistent styling, and prepare evidence for confirming
the pro coaching suite direction with simple player/review modes.

Automation scope:

- Launch or connect to the Flutter web app.
- Capture desktop, tablet, and phone viewport screenshots.
- Record browser console errors and visible Flutter error text.
- Navigate through reachable app states without requiring user input.
- Exercise mode switches, panels, dialogs, and simple tagging flows where
	automation can identify stable controls.
- Save screenshots locally under `specs/visual-design-system/audit-screenshots/`;
  commit only privacy-reviewed captures using approved or synthetic footage.
- Save the written audit report as
	`specs/visual-design-system/visual-audit-results.md`.

Human review scope:

- Confirm whether the captured UI feels like the intended product direction.
- Choose the final visual direction and brand tone.
- Decide whether young-player/simple mode is calm enough.
- Approve framework choice when multiple options remain viable.

Acceptance:

- Automated screenshot set is captured or blockers are documented.
- Current hard-coded color and style hotspots are listed.
- Console/runtime visual blockers are listed.
- Mode priorities are accepted.
- Framework decision is recorded.

## Phase 01 - Responsive shell and theme foundation

Objective: define the responsive app shell and theme foundation needed to make
the video stage primary, remove fragmented styling, and prevent desktop panels
from being squeezed onto tablet and phone layouts.

Implementation scope:

- Add top-level `ThemeData`.
- Define Flow Lens color tokens.
- Define typography, spacing, radius, border, and elevation tokens.
- Decide whether to use `flex_color_scheme`.
- Define desktop, tablet, and phone breakpoints.
- Define video-stage background and sizing rules so white page gaps disappear.
- Define panel surface rules for floating, docked, modal, and sheet surfaces.
- Define first mode-layout rules for Coach, Player, Review, and Analyst density.
- Replace the most visible hard-coded colors in app shell components only after
	the tokens and shell rules are agreed.

Detailed handoff: [Phase 01 responsive shell and theme](phase-01-responsive-shell-and-theme.md).

Acceptance:

- App has light/dark or dark-first theme rules.
- Major shell surfaces share tokens.
- Video remains the dominant layout primitive.
- Tablet and phone behavior is intentionally specified, not inherited from the
	desktop shell by shrinkage.
- No major behavior changes.

## Phase 02 - App shell redesign

Objective: make the video stage, title/navigation, mode switcher, and docked
panels feel intentional.

Implementation scope:

- Redesign title bar and mode navigation.
- Normalize docked/floating panel chrome.
- Improve video control grouping.
- Define desktop, tablet, and phone shell behavior.

Acceptance:

- Video remains dominant.
- Mode switching is clear.
- Panels have one visual language.
- Mobile/tablet layouts do not feel like squeezed desktop.

## Phase 03 - Mode-specific surfaces

Objective: make Coach, Player, Analyst, and Review modes genuinely distinct in
complexity while still sharing the same design system.

Implementation scope:

- Coach mode: dense tagging and hotkeys.
- Player mode: touch-first quick actions.
- Analyst mode: tables, filters, and tracking density.
- Review mode: simplified playback and event navigation.

Acceptance:

- Player mode hides advanced clutter by default.
- Coach mode remains fast for keyboard workflows.
- Analyst mode supports dense information without visual chaos.
- Review mode works for non-expert users.

## Phase 04 - Component cleanup

Objective: replace one-off widget styling with reusable components.

Implementation scope:

- Buttons and icon buttons.
- Event chips and grade badges.
- Panel headers and actions.
- Timeline markers.
- Empty/error/loading states.
- Dialogs, sheets, and popovers.

Acceptance:

- Repeated UI elements use shared components or tokens.
- New colors are not introduced ad hoc.
- Component behavior is tested where practical.

## Phase 05 - Polish and accessibility

Objective: make the redesigned app robust across devices, input modes, and
lighting conditions.

Implementation scope:

- Contrast pass.
- Keyboard focus pass.
- Touch target pass.
- Motion pass.
- Screenshot regression capture.

Acceptance:

- Desktop, tablet, and phone screenshots are reviewed.
- Key controls meet touch target expectations.
- Focus states are visible.
- Text does not overlap or clip in common layouts.
