# Visual Design System

This spec prepares a redesign of Flow Lens into a more beautiful, coherent, and
user-friendly web/mobile coaching application. It is documentation-only; no app
code changes are part of this spec.

The current app has strong functional pieces but weak visual system boundaries:
`MaterialApp` does not define a top-level theme, colors are hard-coded across
many widgets, and interaction density is not clearly separated by user mode.

## Product goal

Flow Lens should feel like a pro coaching suite that can simplify itself for
young players and reviewers. The app needs advanced tools for coaches and
analysts, but also touch-friendly simple modes for players reviewing and tagging
their own games on iPads and phones.

## Target experience

- Video-first: the footage stays visually dominant.
- Mode-aware: Record, Review, Tracking, and future Player modes have distinct
  priorities without feeling like different apps.
- Fast under pressure: live tagging and quick review controls are obvious,
  reachable, and high contrast.
- Calm enough for learning: young players should not feel dropped into an
  airplane cockpit when they only need a few actions.
- Professional, not decorative: restrained surfaces, clear hierarchy, deliberate
  color, and predictable panel behavior.

## Status

- [x] Initial UI evidence gathered
- [x] Framework options researched
- [x] Design principles drafted
- [x] Visual audit completed with screenshots
- [ ] Design tokens selected
- [ ] Component inventory completed
- [ ] Shell redesign prototype completed
- [ ] First implementation phase approved

## Supporting documents

- [Design principles](design-principles.md)
- [Framework research](framework-research.md)
- [Experience modes](experience-modes.md)
- [Component inventory](component-inventory.md)
- [Visual audit](visual-audit.md)
- [Visual audit results](visual-audit-results.md)
- [Phases](phases.md)
- [Phase 01 responsive shell and theme](phase-01-responsive-shell-and-theme.md)
- [Validation](validation.md)

## Initial recommendation

Start with Material 3 plus a Flow Lens design-token layer. Evaluate
`flex_color_scheme` for theme generation and consistency. Do not immediately
rewrite the app around a third-party component library until the shell redesign
and token system prove the visual direction.
