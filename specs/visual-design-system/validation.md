# Validation

Visual redesign work should be validated with screenshots, manual interaction,
and existing automated checks.

## Automated checks

Run after implementation phases:

```bash
flutter analyze
flutter test
```

## Screenshot checks

Capture before/after screenshots for:

- Desktop web, wide viewport.
- Tablet/iPad-sized viewport.
- Phone-sized viewport.
- Main shell without video.
- Main shell with video.
- Coach tagging mode.
- Player quick-action mode.
- Analyst tracking/table mode.
- Review mode.
- Settings and export dialogs.

## Playwright audit checks

The automated Phase 00 audit should verify or record:

- App URL under test.
- Browser and viewport sizes used.
- Screenshot path for each state.
- Console errors and Flutter error overlays.
- Whether sport selection can be completed.
- Whether the main shell can be reached.
- Whether mode switching can be exercised.
- Whether dialogs and panels can be opened without manual input.
- Any state that could not be reached automatically.

If `flutter run -d chrome` fails, record the failure and use either a fixed dev
server command or a built web app served locally before rerunning the audit.

## Manual interaction checks

- Keyboard tagging remains fast.
- Touch quick actions are reachable.
- Docked/floating panels do not obscure essential video content.
- Mode switching preserves video position and user context.
- Event feedback is visible but not distracting.
- Text does not clip in compact panels.
- Controls remain readable over bright and dark video frames.

## Accessibility checks

- Sufficient color contrast for text and event states.
- Visible focus states for keyboard users.
- Hit targets are appropriate for touch surfaces.
- Color is not the only signal for event grade or active state.
- Motion is purposeful and not required to understand state.

## Framework validation

Before adopting a new component package:

- Prototype one real Flow Lens panel.
- Check Flutter version compatibility.
- Check web, iOS, Android, and desktop behavior.
- Estimate migration cost from existing Material widgets.
- Confirm it does not force a visual language that conflicts with video-first
  coaching workflows.
