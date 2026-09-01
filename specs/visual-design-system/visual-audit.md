# Visual Audit

This file tracks the current UI problems and evidence before redesign begins.

## Initial findings

- `MaterialApp` is instantiated without a global theme.
- Many widgets hard-code colors directly.
- Purple branding appears in multiple places without a token system.
- Blue, green, red, orange, grey, and white opacity values are used ad hoc.
- Dark panel surfaces vary by widget.
- Some screens use light Material defaults while video tools use custom dark UI.
- There is no documented spacing, radius, typography, or elevation scale.

## Screenshot set to capture

Capture desktop and mobile/tablet screenshots for:

- Sport selection
- Main video shell with no video
- Main video shell with video loaded
- Record mode with event buttons visible
- Review mode with event table/navigation visible
- Tracking mode with subjects and trackers
- Drawing tools active
- Smart HUD active
- Settings view
- Export dialog

## Automated capture plan

Use Playwright or equivalent browser automation for the first pass.

Viewports:

- Desktop: 1440 x 900
- Wide desktop: 1920 x 1080
- Tablet/iPad: 1024 x 768
- Phone: 390 x 844

Output paths:

- Screenshots: `specs/visual-design-system/audit-screenshots/`
- Report: `specs/visual-design-system/visual-audit-results.md`

Automation should record:

- Page title and URL.
- Browser console errors and warnings.
- Flutter error text visible on screen.
- Screenshot path for each captured state.
- Interactions attempted and whether they succeeded.
- Layout issues visible from screenshots or page snapshots.

Automation can complete the evidence-gathering portion of Phase 00 without user
interaction. Final design judgment still requires human review.

## Audit checklist

- Color consistency
- Contrast and readability over video
- Touch target size
- Keyboard discoverability
- Panel density
- Layout stability while tagging
- Typography hierarchy
- Repeated component styling
- Mobile overflow and clipping
- Empty states
- Error states
- Loading states

## Output

For each audited screen, record:

- Current screenshot path
- Primary visual problem
- Primary usability problem
- Proposed design-system token or component fix
- Whether the fix belongs to token pass, shell pass, or mode-specific pass

## Blockers

If the Flutter web app cannot run, record:

- Command attempted.
- Exit code.
- Relevant error output.
- Whether a built web app or alternate local server can be used instead.
