# Framework Research

This document records candidate Flutter design-system options for Flow Lens.

## Current state

- `MaterialApp` is used without a top-level `ThemeData`.
- Many widgets hard-code colors such as `Color(0xFF753b8f)`, `Colors.blue`,
  `Colors.red`, `Colors.white70`, and dark panel backgrounds.
- The app already uses Flutter Material widgets and Material Icons.
- The app must remain cross-platform: web, iOS, Android, Windows, macOS, and
  Linux.

## Option A - Material 3 plus custom Flow Lens tokens

Use Flutter's built-in Material system, define `ThemeData`, add `ThemeExtension`s
for app-specific tokens, and gradually replace hard-coded styles.

Pros:

- Lowest dependency risk.
- Best fit with existing Material widgets.
- Works across all current platforms.
- Easy incremental migration.
- Good accessibility and input support.

Cons:

- Requires discipline to avoid generic Material defaults.
- Custom shell and panels still need design work.

Recommendation: baseline approach.

## Option B - FlexColorScheme

`flex_color_scheme` generates sophisticated Material 3 `ThemeData` and component
themes. Its docs describe Material 3 support, seeded color schemes, surface
blends, component theming, and a playground that can generate setup code.

Pros:

- Still returns standard `ThemeData`.
- Strong for color-system consistency.
- Good bridge from current Material usage to a more polished theme.
- Visual playground helps explore palettes quickly.

Cons:

- Solves theming, not product layout or UX.
- The app still needs custom video-tool components.

Recommendation: strong candidate for Phase 01 theme foundation.

## Option C - shadcn_ui

`shadcn_ui` is a Flutter port of shadcn/ui with customizable components such as
buttons, dialogs, popovers, sliders, tabs, tables, forms, and tooltips.

Pros:

- Modern component language.
- Good fit for dashboards and dense tools.
- Includes many interaction components Flow Lens uses.

Cons:

- Larger dependency and style shift.
- Some components are incomplete.
- May conflict with existing Material patterns.
- Full migration could distract from video-specific UX.

Recommendation: evaluate for selected panels only after token and shell work.

## Option D - Forui

Forui provides shadcn-inspired Flutter widgets for desktop and touch devices,
including layout, form, data, navigation, feedback, overlay, and tile widgets.
Its package notes broad widget coverage and a CLI for themes, but also notes a
Flutter version requirement.

Pros:

- Purpose-built design-system package.
- Strong component coverage for touch and desktop.
- Minimal, modern visual language.

Cons:

- Requires version compatibility check.
- Larger migration from Material.
- Needs proof that video-heavy app shell still feels native and performant.

Recommendation: research prototype only, not immediate adoption.

## Option E - fluent_ui

`fluent_ui` implements Microsoft Fluent UI for Flutter and is strongest for
Windows-like desktop apps.

Pros:

- Mature desktop controls.
- Strong Windows fit.
- Good for command bars and desktop panes.

Cons:

- Flow Lens must also feel good on web, iOS, Android, and iPad.
- Fluent visual language may feel too Windows-specific.
- Could fragment the cross-platform identity.

Recommendation: do not use as the primary design system. Borrow ideas for dense
desktop command layouts if useful.

## Recommended path

1. Material 3 plus Flow Lens tokens.
2. Use FlexColorScheme or manual `ColorScheme` generation for consistent theme
   output.
3. Build custom video-tool components for panels, controls, mode rails, event
   chips, and timeline markers.
4. Prototype Forui or shadcn_ui only for non-video surfaces such as settings,
   account, and future admin/dashboard screens.
