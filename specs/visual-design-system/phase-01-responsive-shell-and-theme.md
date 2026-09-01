# Phase 01 - Responsive Shell and Theme Foundation

This is the implementation handoff for the first visual redesign slice. It is
intended for a design agent or implementation agent. The goal is not to redesign
every screen. The goal is to create the foundation that makes later redesign work
coherent and safer.

## Source evidence

Use these documents as input:

- [Design principles](design-principles.md)
- [Experience modes](experience-modes.md)
- [Framework research](framework-research.md)
- [Visual audit results](visual-audit-results.md)
- [Component inventory](component-inventory.md)
- [Validation](validation.md)

The most important audit conclusion is that Flow Lens has a structural design
problem, not only a color problem. The desktop tool shell is currently compressed
onto tablet and phone, and major surfaces use separate visual languages.

## Objective

Create a cohesive, video-first foundation for Flow Lens by defining:

- app-level theme setup,
- Flow Lens design tokens,
- responsive shell rules,
- panel surface rules,
- mode-density rules,
- and the first narrow set of widget migrations.

This phase should preserve current app behavior. Avoid workflow redesign unless a
small layout adjustment is required to stop an obvious visual failure.

## Product direction

Flow Lens should feel like a pro coaching suite that can simplify itself for
young players and reviewers.

Design posture:

- Professional, video-first, and restrained.
- Dense when a coach or analyst needs speed.
- Calm and touch-friendly when a player or reviewer only needs a few actions.
- Functional before decorative.

Do not make the app feel like a marketing site, generic dashboard, or purely
desktop utility.

## Framework decision

Recommended baseline:

1. Use Flutter Material 3 with custom Flow Lens tokens.
2. Consider `flex_color_scheme` only for generating consistent `ThemeData` and
   component themes.
3. Do not adopt `shadcn_ui`, Forui, or `fluent_ui` as the main video-shell
   framework in this phase.
4. Third-party component packages may be prototyped later for account, settings,
   admin, or non-video dashboard surfaces.

Rationale:

- The current app already uses Material widgets.
- The hardest design problem is the custom video shell, not generic components.
- A large component-library migration would add risk before the shell model is
  clear.

## Breakpoints

Use named breakpoints rather than scattering width checks:

- Phone: `< 600` logical pixels.
- Tablet: `600-1023` logical pixels.
- Desktop: `>= 1024` logical pixels.
- Wide desktop: `>= 1440` logical pixels.

These names should drive shell decisions, panel decisions, and mode density.

## Shell rules

### All viewports

- The video stage is the primary layout primitive.
- The app background must fill the entire viewport; no white page gaps should be
  visible around the app shell.
- Overlays must not permanently obscure critical video regions unless the user
  explicitly pins them.
- Controls that sit over video must share panel/surface tokens.
- Mode-specific layouts should preserve video position and playback state.

### Desktop

- Desktop may use dense floating or docked panels.
- Floating panels should use one shared chrome system.
- Event/tagging controls may be visible by default in Coach mode.
- Analyst mode may prioritize data tables and tracking density.
- Review mode should not show every advanced panel by default.

### Tablet

- Tablet should not simply shrink the desktop layout.
- Prefer one primary side panel or one bottom sheet at a time.
- Touch targets should be larger than desktop icon controls.
- Review and Player flows should keep the video substantially visible.

### Phone

- Phone requires a true Player/Review shell, not desktop panels squeezed into a
  narrow viewport.
- Prefer bottom controls, bottom sheets, and simple quick actions.
- Hide or collapse advanced panels by default.
- The events drawer must not permanently consume the viewport.

## Mode rules

### Coach mode

- Dense tagging is allowed.
- Hotkeys and staged event entry can be visible.
- Event category controls may be prominent.
- The selected event editor should avoid covering the most important play area
  when possible.

### Player mode

- Use a small configured quick-action set.
- Use large touch targets.
- Hide taxonomy depth and advanced panels by default.
- Prioritize review, reflection, and quick tagging.

### Review mode

- Prioritize playback, event navigation, and current-event context.
- Keep drawing tools collapsed unless explicitly active.
- Use empty states instead of dense disabled panels when no events exist.

### Analyst mode

- Allow denser tables, filters, tracking panels, and export tools.
- Keep visual hierarchy clear so the video is not lost behind data surfaces.

## Token set

Create tokens before broad widget restyling.

### Color tokens

Required groups:

- App background.
- Video stage background.
- Header/navigation background.
- Floating panel surface.
- Docked panel surface.
- Modal/sheet surface.
- Scrim/backdrop.
- Primary action.
- Secondary action.
- Danger/destructive action.
- Disabled state.
- Focus ring.
- Divider/border.
- Text primary/secondary/muted/inverse.

### Semantic event tokens

Required groups:

- Positive event.
- Negative event.
- Neutral event.
- Selected event.
- Recent event.
- Timeline marker.

Taxonomy category colors should be treated as content colors, not general UI
chrome colors. Avoid giving every category equal saturation in every context.

### Drawing tokens

Drawing colors should be chosen for visibility over ice/video and must be
separate from brand colors.

Required groups:

- Drawing default stroke.
- Drawing alternate palette.
- Active drawing tool.
- Temporary/in-progress annotation.
- Laser pointer.
- Clear/undo danger action.

### Spacing, radius, and border tokens

Define a compact scale suitable for a tool UI:

- Spacing: `4`, `8`, `12`, `16`, `24`, `32`.
- Radius: `4`, `6`, `8`, `12` only where needed.
- Border widths: hairline/standard/emphasis.
- Panel padding: compact and comfortable variants.

Cards and panels should generally stay at `8` radius or less unless there is a
specific reason.

### Typography tokens

Define text roles:

- App title.
- Mode label.
- Panel title.
- Control label.
- Button label.
- Metadata/timecode.
- Hotkey hint.
- Table body.
- Empty-state text.

Avoid scaling font size with viewport width. Compact surfaces should use tighter
hierarchy, not oversized display text.

## First implementation slice

Keep the first code slice intentionally narrow.

Recommended files likely touched:

- `lib/main.dart`
- `lib/theme/flow_lens_theme.dart` or equivalent new theme file
- `lib/theme/flow_lens_tokens.dart` or equivalent new token file
- `lib/widgets/branded_title_bar.dart`
- `lib/widgets/dock_layout.dart`
- `lib/widgets/dockable_panel.dart`
- `lib/widgets/control_bar.dart`

Possible follow-up files, only if needed for the first visual pass:

- `lib/widgets/event_buttons_panel.dart`
- `lib/widgets/docked_events_panel.dart`
- `lib/widgets/settings_view.dart`
- `lib/widgets/export_dialog.dart`

Do not begin by restyling every widget. Establish the theme, background, shell,
and panel primitives first.

## Implementation sequence

1. Add an app-level theme and token structure.
2. Apply the theme to `MaterialApp`.
3. Normalize app and video-stage backgrounds.
4. Define shared panel surface styles.
5. Migrate title bar and core floating/docked panel chrome to tokens.
6. Add breakpoint helpers or a small responsive shell abstraction.
7. Update only the most visible hard-coded colors that affect the shell.
8. Re-run the visual audit screenshots for comparison.

## Non-goals

- Do not implement premium/cloud visual surfaces.
- Do not redesign all event taxonomy buttons in this phase.
- Do not replace the state management approach.
- Do not adopt a large component package as the primary framework.
- Do not redesign all mobile workflows yet; define the shell rules and remove
  the worst shrinkage failures first.
- Do not change event, tracking, drawing, or export behavior unless a tiny visual
  wrapper change is unavoidable.

## Validation

Run:

```bash
flutter analyze
flutter test
```

Capture screenshots for comparison:

- Sport selection desktop and phone.
- Hockey video picker desktop and phone.
- Loaded video Record desktop.
- Loaded video Review desktop.
- Loaded video Tracking desktop.
- Loaded video tablet.
- Loaded video phone.
- Settings view.
- Export dialog.
- Event-created state.
- Smart HUD active state.
- Drawing in progress.

Compare against [visual-audit-results.md](visual-audit-results.md) and any
privacy-reviewed screenshots retained locally.

## Acceptance checklist

- [ ] `MaterialApp` has an intentional app theme.
- [ ] Flow Lens token files or theme extensions exist.
- [ ] App/video backgrounds fill the viewport with no white gaps.
- [ ] Header, floating panels, docked panels, and modals have documented surface
  rules.
- [ ] Desktop/tablet/phone breakpoints are defined in one place.
- [ ] Phone and tablet shell behavior is intentionally specified.
- [ ] Drawing colors are separated from brand colors.
- [ ] Major shell colors no longer depend on repeated hard-coded purple/black
  values.
- [ ] Existing behavior remains intact.
- [ ] Analyzer and tests pass.
- [ ] Updated screenshots are captured for the Phase 01 comparison set.

## Design-agent prompt

Use this prompt when handing the phase to a design agent:

```text
You are redesigning the Flow Lens Flutter app visual foundation. Use the files in
specs/visual-design-system as the source of truth. Focus only on Phase 01:
responsive shell and theme foundation. Do not redesign every screen and do not
change product behavior. Create a professional video-first coaching UI that can
support dense Coach/Analyst modes and simpler Player/Review modes. Define and
apply app-level theme tokens, video-stage background rules, panel surface rules,
and desktop/tablet/phone shell behavior. Keep Material 3 as the baseline; do not
adopt a third-party component system as the main framework unless explicitly
approved. Validate with flutter analyze, flutter test, and comparison
screenshots against the Phase 00 audit.
```
