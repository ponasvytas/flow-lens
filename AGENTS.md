# AGENTS.md — Flow Lens

Video analysis tool for sports coaching, built with Flutter/Dart. Load and play
video, record categorized game events, draw annotations/laser overlays, track and
filter events, and export timelines. Cross-platform: web, Windows, macOS, Linux,
Android, iOS.

## Commands
- Run (web): `flutter run -d chrome`
- Run (desktop): `flutter run -d windows`
- Analyze: `flutter analyze`
- Format: `dart format lib test`
- Test: `flutter test`
- Deps: `flutter pub get`
- Outdated: `flutter pub outdated`

On Windows, `dart`/`flutter` are `.bat` scripts — when invoking them from a
non-shell process launcher, wrap with `cmd /c`.

## Architecture
- State management: plain Flutter `ChangeNotifier` (no Provider/GetX/Riverpod).
  Scoped notifiers mutate without triggering parent `setState`; UI updates via
  direct listeners.
- `lib/controllers/`: app state — `events_controller`, `settings_controller`,
  `ui_controller`, `tracking_controller`.
- `lib/models/`: immutable data models with `copyWith()` and JSON
  (de)serialization — `game_event`, `sport_taxonomy`, `sport_profile`,
  `app_settings`, `app_mode`, `drawing_models`, `tracking_models`,
  `events_filter`, `tracking_presets`.
- `lib/services/`: persistence/repositories — `event_storage_service`,
  `tracking_storage_service`, `taxonomy_repository`, `settings_repository`,
  `export/`.
- `lib/painters/`: `CustomPainter` overlays — `drawing_painter`, `laser_painter`.
- `lib/widgets/`: UI components (panels, pickers, overlays, docking, timeline,
  events table).
- `lib/utils/`: platform-specific helpers via conditional imports (see below).
- Video engine: `media_kit` / `media_kit_video`. Initialize with
  `MediaKit.ensureInitialized()` in `main()`. Always dispose Player/controllers.
- Cloud: `firebase_core` + `firebase_storage` (demo/shared videos).

## Multi-platform conventions
- Platform code uses conditional imports with `_stub` / `_web` / `_native`
  variants. Keep this pattern when adding platform-dependent features:
  `file_saver.dart` (+ `_stub`/`_web`), `video_loader.dart` (+ `_stub`/`_web`),
  `player_config.dart` (+ `_stub`/`_native`),
  `native_player_helpers.dart` (+ `_stub`/`_native`).
- Web: native HTML file picker + blob URLs to avoid memory bloat; GPU
  acceleration disabled. Desktop: `file_picker` plugin; GPU acceleration on.

## Domain model
- Events are hierarchical: Category → EventType → Grade
  (Positive/Negative/Neutral). SmartHUD supports an Alt+Number staged entry
  workflow for rapid tagging.
- Sports are taxonomy-driven (`assets/sports/*.json`). Hockey is implemented;
  add new sports via taxonomy/profile assets, not hardcoding.

## Drawing / overlay system
- Layered: base drawings layer + interactive overlay. Tools: freehand strokes,
  lines, arrows, plus a laser pointer with fading trails (~2.5s).
- Wrap paint-heavy widgets in `RepaintBoundary`.

## Docking system
- Panels dock to 5 positions (left/right/top/bottom/floating); `dock_layout`
  handles positioning and drag-to-snap. Panels adapt layout to their dock edge.

## Performance rules (keep these intact)
- Laser: throttled updates (≈50ms idle, ≈16ms while drawing).
- Drawing: point reduction, min ≈5px between captured points.
- Custom scroll interceptor prevents scroll propagation to video controls.
- Per-trail `AnimationController`s for independent fade.

## Conventions
- Lints: `flutter_lints` (see `analysis_options.yaml`). Run `flutter analyze`
  and `dart format` before finishing.
- Keep models immutable; prefer `copyWith` over mutation.
- Don't introduce a state-management package — match the existing
  `ChangeNotifier` approach.
- Add comments only for non-obvious intent; keep them short.
