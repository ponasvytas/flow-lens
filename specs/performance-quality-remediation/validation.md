# Validation

## Repeatable datasets

- Events: 1,000 categorized events; select 500; batch-delete 250.
- Tracking: 8 subjects, 16 trackers, 10,000 events, 4 active timers.
- Drawing: 60 seconds continuous input and 50 completed strokes.
- Dragging: 10 seconds each for shortcuts and dock panels.
- Seeking: 5 seconds continuous seekbar scrubbing.

## Commands

```text
dart format lib test
flutter analyze
flutter test
flutter build web
flutter build windows
flutter run --profile -d chrome --dart-define=FLOW_LENS_PERF=true
flutter run --profile -d windows --dart-define=FLOW_LENS_PERF=true
```

## Results

| Date | Platform/check | Result | Notes |
|---|---|---|---|
| 2026-08-09 | Pre-change analyze | Blocked | No output before 300 s timeout; existing Dart processes present. |
| 2026-08-09 | Pre-change test | Blocked | Combined command timed out before result. |
| 2026-08-09 | `dart format lib test` | Pass | 74 Dart files checked after remediation. |
| 2026-08-09 | `flutter analyze` | Pass | No issues found. |
| 2026-08-09 | `flutter test` | Pass | 38 tests passed. |
| 2026-08-09 | `flutter build web` | Pass | Release build and Wasm dry run succeeded. |
| 2026-08-09 | `flutter build windows` | Pass | Release executable built successfully; dependency CMake deprecation warnings only. |
| Pending | Chrome profile scenarios | Pending | Interactive reference machine required. |
| Pending | Windows profile scenarios | Pending | Interactive reference machine required. |
| Pending | macOS/Linux/Android/iOS smoke | Pending | No matching runners in this Windows checkout. |

## Platform matrix

| Platform | Automated build | Smoke | Profile gate |
|---|---|---|---|
| Chrome/web | Pass | Interactive smoke pending | Required |
| Windows | Pass | Interactive smoke pending | Required |
| macOS | CI runner required | CI runner required | Not a reference gate |
| Linux | CI runner required | CI runner required | Not a reference gate |
| Android | CI/device required | CI/device required | Not a reference gate |
| iOS | CI/device required | CI/device required | Not a reference gate |
