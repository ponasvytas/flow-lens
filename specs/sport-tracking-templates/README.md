# Sport-specific tracking and quick templates

Investigation date: 2026-10-05. Implementation update: 2026-10-06.
Status: the first local template release is implemented; advanced metric and
cloud phases remain proposals. See [implementation status](implementation.md).
Scope: hockey first; soccer, basketball, and volleyball examples to test whether
the design generalizes. Based on the working tree, including existing changes
to the tracking panel. Those application changes are outside this investigation.

## Recommendation

Build a sport-owned metric catalog and small, reusable tracking templates on top
of the taxonomy infrastructure already present. Start with manual counters and
timers, preserve historical sessions, and add calculated metrics only when their
inputs and recording coverage are explicit. Save template configuration locally
first; add an account-owned template library as a separate premium capability.

The tracker list is **already loaded from the sport asset**. The remaining Dart
`HockeyTrackingPresets` list is historical compatibility data, referenced by a
regression test rather than the production picker. Replacing that file alone
would miss the actual gaps.

| Current state | Finding |
| --- | --- |
| Hockey tracker catalog | 75 definitions: 66 counters and 9 timers |
| Event alignment | All 55 active hockey event types have a corresponding manual counter |
| Additional metrics | 11 counters without event links, plus 9 timers |
| Historical Dart list | 30 definitions: 21 counters and 9 timers; IDs retained in the current asset |
| Sport support | Hockey enabled; soccer, basketball, volleyball listed but disabled, without bundled taxonomies |
| Quick event templates | Four bundled suggestions and local user presets already exist |
| Tracking templates at audit time | No dedicated reusable template model, library, or apply operation; now implemented for local use |
| Cloud | Tracking-session repository and capability gates exist; template storage does not |

## What should change

1. **Make the hierarchy explicit:** sport → metric family → metric definition →
   optional outcome/context. Reuse event categories where the meaning matches;
   give durations and calculated measures their own families where needed.
2. **Separate three objects:** the metric's definition, a reusable template that
   selects a few metrics, and a session containing observations about real people
   or teams. A template must never contain a previous game's counts or timers.
3. **Declare the source:** manual observations, filtered Record events, or a
   calculation. An `eventTypeId` currently describes meaning; it does not make
   the tracker count Record events. Never sum both sources silently.
4. **Offer small templates:** begin with Faceoffs, Passing, Shot outcomes,
   Puck battles, Player involvement, and Goalie outcomes. Start with roughly
   three to five capture controls; keep advanced options in customization.
5. **Preserve meaning:** store metric revisions and snapshots in sessions.
   Templates reference stable IDs and pinned revisions. Renaming, archiving,
   or switching templates must not reinterpret or delete historical data.
6. **Prepare premium saving:** use a template repository behind account
   capabilities, with explicit synchronization and conflict handling. Keep
   bundled templates and current local workflows usable without login.

## Read the investigation

| Document | Contents |
| --- | --- |
| [Current-state audit](current-state.md) | Runtime wiring, remaining hardcoding, defects and migration risks, test coverage |
| [Current inventory](current-inventory.csv) | All 75 current definitions, IDs, event links, and review recommendations |
| [Metric catalog](metric-catalog.md) | Hockey candidates, definitions, priorities, formulas, and other-sport examples |
| [Quick templates](quick-templates.md) | Starter sets, operator workflow, lifecycle, and premium product boundary |
| [Architecture and delivery](architecture.md) | Proposed contracts, example JSON, migration, phases, and acceptance checks |
| [Implementation status](implementation.md) | Delivered behavior, actual file formats, validation, and remaining phases |
| [Research](research.md) | Public references actually accessed, source limitations, and design implications |

## First deliverable to implement

Ship bundled tracking templates and local saved configurations using the current
counter/timer engine, together with session identity and safe tracker visibility.
Templates may show observed totals immediately. Rates, paired outcomes, exclusive
timers, and event-derived results need the additional safeguards described in the
architecture; they should not be implied by the first template picker.

The first six templates are a candidate release set, not a requirement to add
every researched metric. Later catalog entries are an opportunity backlog.

## Decisions still worth validating with coaches

- Whether the first capture screen should default to a single player or a team.
- Whether outcome entry should expand a metric into outcome buttons, or show all
  three to five outcomes continuously on larger panels.
- The precise start/stop rules for possession, shifts, pressure, and zone time.
- Which competitions need non-checking hockey variants and different period or
  penalty rules.
- Whether premium launch includes only private cloud templates or also published
  coach packs. Private saving is the recommended first scope.

Recommended defaults for implementation are provided in the linked documents;
none of these questions blocks the catalog investigation.

## Validation

See the validation record in [current-state.md](current-state.md#validation-record).
The original investigation was documentation-only. The subsequent implementation
adds local tracking templates and session preservation; it does not enable new
sports, change historical metric definitions, or deploy cloud rules.
