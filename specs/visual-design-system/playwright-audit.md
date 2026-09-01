# Playwright Audit Procedure

This procedure defines how to run Phase 00 as an automated browser audit.

## Preconditions

- Flutter web app can be served locally.
- Browser automation can open the app URL.
- Test video loading is optional for the first audit. If video loading is not
  stable, capture no-video shell states first and record video-loading as a
  blocker.

## Suggested outputs

```text
specs/visual-design-system/audit-screenshots/
specs/visual-design-system/visual-audit-results.md
```

The screenshot folder should be ignored or reviewed before committing if it
contains large binary files.

## Viewports

- `desktop`: 1440 x 900
- `wide-desktop`: 1920 x 1080
- `tablet`: 1024 x 768
- `phone`: 390 x 844

## States to capture

1. Sport selection or first-launch screen.
2. Main shell with no video.
3. Main shell after selecting the default enabled sport.
4. Record mode.
5. Review mode.
6. Tracking mode.
7. Drawing tools active.
8. Smart HUD active if reachable by keyboard automation.
9. Settings view.
10. Export dialog if reachable without a loaded video; otherwise record as
    blocked.

## Report template

For each state and viewport, record:

- Screenshot path.
- Interaction steps.
- Console errors.
- Visible error text.
- Obvious layout issues.
- Design-system issue category: color, spacing, type, panel chrome, mobile
  responsiveness, control hierarchy, or mode complexity.

## Automation limits

Playwright can produce an evidence baseline, but it should not make final design
decisions. Human review still decides brand direction, perceived complexity, and
whether the product feels right for coaches, young players, reviewers, and
analysts.
