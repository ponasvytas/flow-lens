# Events Table + Excel-Style Filters + Taxonomy (Conservative Migration Plan)

## Goals

1. Add an Events table view with exactly 4 columns:
   - Time (video timestamp)
   - Category (EventCategory)
   - Event (taxonomy-driven event type)
   - Impact (EventGrade)

2. Add Excel-style filters (multi-select per column) that apply to:
   - Events table
   - Timeline markers

3. Prepare the architecture for multi-sport expansion and user-defined labels without breaking existing hockey functionality.

## Non-Goals (for this iteration)

- Preset management UI (we will only add the architecture/backlog item).
- Remote/downloading sport packs (local assets only).
- Replacing hockey `EventCategory` enum everywhere (conservative migration keeps it for now).

## Current State (Relevant)

- `GameEvent` currently stores:
  - `timestamp`, `category` (enum), `grade` (enum?), `label` (string), `detail` (string?)
- SmartHUD provides category-specific tag strings and auto-grade logic.
- Timeline markers are drawn from the `events` list passed to `VideoProgressBar`.
- App state is currently maintained in `main.dart` with `setState`.

## Proposed Direction (Conservative Migration)

- Introduce a taxonomy layer loaded from JSON assets (initially hockey only).
- Keep `EventCategory` enum for existing UI and for backwards compatibility.
- Add stable IDs to events:
  - `sportId` (default `"hockey"`)
  - `categoryId` (derived from `EventCategory.name`)
  - `eventTypeId` (selected from taxonomy)
- Continue to store `label/detail` temporarily for compatibility/migration.

## Finalized Decisions (Locked)

- User-added event types use UUIDs internally, but the UI only shows/asks for the label.
- Impact is always one of: Positive / Neutral / Negative (no "Unrated" option).
- Mobile Events table presentation: full-screen route/page.

---

# Milestones & Tasks

## Milestone 1 — Hockey taxonomy JSON + loader (no UI changes yet)

### Outcome
A hockey sport pack is bundled as an asset and can be loaded into a strongly-typed in-memory model.

### Tasks
- Add asset file:
  - `assets/sports/hockey.json`
- Register asset in `pubspec.yaml` under `flutter/assets`.
- Add taxonomy model types (Dart):
  - `SportTaxonomy`
  - `CategoryTaxonomy`
  - `EventTypeTaxonomy`
- Add a loader service:
  - `TaxonomyRepository.loadSportTaxonomy(sportId)`
  - Uses `rootBundle.loadString` on all platforms.
- Add minimal validation:
  - unique `categoryId` within sport
  - unique `eventTypeId` across all categories

### Acceptance Criteria
- Hockey taxonomy loads successfully on web and native.
- No changes in existing UI or saved events are required.

---

## Milestone 2 — Extend `GameEvent` to support taxonomy IDs + backward-compatible JSON

### Outcome
Every event can be represented by stable IDs (sport/category/eventType) suitable for table filtering while still loading older JSON files.

### Tasks
- Update `GameEvent` model:
  - Add fields: `sportId`, `categoryId`, `eventTypeId`
  - Keep existing `label/detail` for now
- Update serialization:
  - `toJson` includes new ID fields
  - `fromJson` tolerates missing fields (old files)
- Add mapping helper:
  - `categoryIdFromEnum(EventCategory)`
- Add migration behavior on load:
  - If `eventTypeId` is missing, attempt to map from `(categoryId, detail ?? label)` to a taxonomy type.
  - If not found, store the event as "unresolved" (keep `label/detail`) and create a user-added event type later when overrides storage is implemented (Milestone 5).

### Acceptance Criteria
- Existing exported JSON files still load.
- New saves include `sportId/categoryId/eventTypeId`.

---

## Milestone 3 — Events state controller + filter engine (shared between table + timeline)

### Outcome
A central controller owns all events and the active filter state. Both the timeline and the table use the same filtered list.

### Tasks
- Add `EventsController` (ChangeNotifier):
  - `List<GameEvent> allEvents`
  - `GameEvent? activeEvent`
  - `EventsFilter filter`
  - computed `filteredEvents`
  - methods: add/update/delete/select/clearFilter/setFilter
- Add `EventsFilter` model:
  - `Set<String>? categoryIds`
  - `Set<String>? eventTypeIds`
  - `Set<EventGrade>? impacts`
  - optional: text query (backlog)
- Update `main.dart` to use controller (minimal surface area):
  - existing `setState` calls replaced by controller updates where feasible
  - `VideoProgressBar(events: controller.filteredEvents)`

### Acceptance Criteria
- When filter changes, timeline markers update instantly.
- Filter logic is unit-testable (pure filtering function).

---

## Milestone 4 — Events table (4 columns) + Excel-style column filters

### Outcome
A table view is available from a button and supports Excel-style per-column multi-select filters. Clicking a row seeks the video and selects the event.

### Tasks
- Add an "Events" button to the top bar (BrandedTitleBar):
  - opens the Events table view
- Implement Events table view UI:
  - 4 columns: Time, Category, Event, Impact
  - responsive presentation:
    - mobile: full-screen page
    - desktop/web: dialog
- Implement row click behavior:
  - seek player to `timestamp`
  - set controller active event (opens SmartHUD)
- Implement column header filter UI:
  - filter icon per column
  - popup/bottom sheet with:
    - Select all
    - Multi-select list
    - Apply / Cancel / Clear
  - Available values derived from:
    - taxonomy (categories, event types)
    - events (impacts present)

### Acceptance Criteria
- Table opens and shows all events.
- Filters affect both table rows and timeline markers.
- Clicking a row jumps video playback to that timestamp.

---

## Milestone 5 — Storage for user-defined labels (overrides) + QA + backlog

### Outcome
User-defined labels can be persisted and merged with base taxonomy. Regression risk is reduced via tests and QA checklist.

### Tasks
- Add overrides storage (MVP):
  - `UserTaxonomyOverridesRepository` using `shared_preferences` (or local file fallback if preferred)
  - Store added event types by `(sportId, categoryId)`
  - New user-added event types use UUIDs internally; UI only requires a label
- Merge strategy:
  - `ResolvedTaxonomy = baseTaxonomy + userOverrides`
- Tests:
  - Filter logic
  - taxonomy load + merge
  - mapping from old label/detail to eventTypeId
- QA checklist (manual):
  - web vs native
  - load/save events
  - filter application to timeline and table
  - row click navigation

### Backlog (explicitly not implemented now)
- Filter presets:
  - named saved filters (e.g., "Offensive negative")
- Export filtered events
- Remote sport pack download/update
- Advanced filters (search query, time range)


# Notes

- During the current event creation flow, the UI may still temporarily hold a draft event while the user selects its values.
- When an event is added to the persisted list (the list that drives table/timeline), it must have an Impact assigned (Positive/Neutral/Negative).
