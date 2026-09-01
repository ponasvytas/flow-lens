# Experience Modes

Flow Lens should support multiple UI modes that share one design system but vary
in density, controls, and layout.

## Coach mode

Primary user: coach tagging live or reviewing immediately after a game.

Priorities:

- Fast event creation.
- Visible hotkeys.
- Event table and timeline access.
- Docked panels for category buttons, navigation, tracking, and shortcuts.
- Low-latency feedback.

Design direction:

- Dense but organized.
- Keyboard-first on desktop.
- High-contrast event states.
- Video remains central.

## Player mode

Primary user: young player reviewing their own footage on iPad, phone, or web.

Priorities:

- Simple controls.
- A small number of configured quick actions.
- Big touch targets.
- Clear review moments.
- Low cognitive load.

Design direction:

- Touch-first.
- Bottom control strip or sheet.
- Only the active task is visible.
- Friendly labels without tutorial clutter.

## Analyst mode

Primary user: detailed breakdown, filtering, tracking, export, and comparison.

Priorities:

- Data table density.
- Advanced filters.
- Multi-panel workflows.
- Export configuration.
- Saved sessions and custom taxonomy once premium work exists.

Design direction:

- Desktop-first but responsive.
- Structured panes.
- Clear grouping and persistent filters.
- More information density than Player mode.

## Review mode

Primary user: parent, player, or teammate opening saved clips/events.

Priorities:

- Play, pause, jump between moments.
- Understand event labels and context.
- Avoid editing complexity.
- Work well from shared links.

Design direction:

- Minimal controls.
- Strong timeline and event list.
- Clear current event context.
- Works without requiring a full app-shell mental model.

## Mode-switching rules

- Modes should preserve video position when switching.
- Modes should not resize the video unexpectedly unless the user chooses a new
  layout.
- Advanced tools should be available from simple modes, but not visually dominant.
- Keyboard shortcuts can vary by mode, but conflicts must be visible and tested.
