# Design Principles

## 1. Video is the canvas

The video should own the screen. Panels, controls, and timelines support the
footage instead of competing with it.

Design implications:

- Use restrained surfaces around the player.
- Avoid saturated panel backgrounds unless they communicate state.
- Keep overlays legible without hiding the play.
- Reserve the loudest color for active actions and event meaning.

## 2. Modes reduce complexity

Flow Lens has different jobs for different users. A coach can need dense tools;
a young player may need only three actions and review markers.

Design implications:

- Create mode-specific layouts instead of one crowded universal shell.
- Let each mode define primary, secondary, and hidden tools.
- Use progressive disclosure for advanced controls.
- Make simple mode touch-first and low-distraction.

## 3. Professional beats flashy

The app should feel credible for coaches and parents. Beauty should come from
alignment, spacing, contrast, typography, motion restraint, and clear state.

Design implications:

- Avoid random gradients and one-off colors.
- Use compact, purposeful type.
- Prefer small radii, crisp borders, and controlled elevation.
- Use motion only to clarify panel changes, tagging feedback, and mode shifts.

## 4. Speed matters

Tagging during or immediately after play must feel instant.

Design implications:

- Important controls need large enough hit targets on touch devices.
- Keyboard affordances should be visible but not noisy.
- Event feedback should be immediate and reversible.
- Avoid layouts that shift while tagging.

## 5. Color carries meaning

Color should communicate brand, interaction state, and event semantics without
fighting the video.

Design implications:

- Define brand colors once as tokens.
- Define semantic colors for positive, negative, neutral, warning, danger, and
  selected states.
- Do not use arbitrary `Colors.blue`, `Colors.green`, or hard-coded purple in
  widgets.
- Check contrast for dark video backgrounds and mobile glare.

## 6. Touch and desktop are first-class

The same product needs mouse/keyboard efficiency and iPad/phone simplicity.

Design implications:

- Use responsive layout rules, not only fixed desktop panel dimensions.
- Provide touch-friendly simple controls.
- Keep advanced desktop panels dense but organized.
- Design bottom-sheet or rail alternatives for narrow screens.
