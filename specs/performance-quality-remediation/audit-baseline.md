# Audit baseline

Captured 2026-08-09 before remediation.

## Tool results

| Check | Result | Evidence |
|---|---|---|
| `flutter analyze` | Blocked | Two attempts produced no output and exceeded 120 s and 300 s; pre-existing Dart processes were present. |
| `flutter test` | Blocked | The combined baseline process exceeded 120 s before producing a result. |
| Web/Windows builds | Not run | Deferred until source remediation and process-lock diagnosis. |
| Profile captures | Unavailable | Requires interactive Chrome/Windows reference-machine runs. |

## Finding evidence

- Performance instrumentation was debug-only, disabled by a mutable switch,
  and tracked averages/maxima rather than frame p50/p95 and dropped frames.
- Freehand capture copied the entire active point list for every pointer update;
  its painter rebuilt paths and reduced points during every paint.
- Laser animation state lived in the domain model.
- Seekbar `onChanged` sought on every drag update and release performed another
  asynchronous seek without stale-completion protection.
- Event getters allocated unmodifiable copies and event selection invalidated
  the same broad notifier used by event data.
- Tracking aggregate getters scanned the complete event history and loaded IDs
  from list length, allowing collisions after non-tail deletion.
- Taxonomy resolution scanned category/event-type lists repeatedly.
- Video URL ownership had no symmetric conditional release API.
- Native player configuration selected NVIDIA-specific `nvdec-copy`.
- Export diagnostics and progress dispatch were not centrally bounded.
- The drawing overlay exposed double-tap clearing.

Interactive frame/memory baselines could not be truthfully manufactured in a
non-interactive session and remain explicitly pending in validation.
