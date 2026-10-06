# First local template release

Implemented 2026-10-06. This delivers the local-template portion of the plan and
the core session identity/preservation work it depends on. It is not a claim that
every metric, timer protocol, or cloud phase in the research is complete.

## Using it

In Track mode, open **Templates** in the Player Tracking panel. Narrow panels
show the same action as an icon with the tooltip **Tracking templates**.

Choose Faceoffs, Passing, Shot outcomes, Puck battles, Player involvement, or
Goalie outcomes. Preview the definitions, choose an existing subject or name a
new player/team/goalie, and remove/reorder controls before applying. By default,
the template adds controls. **Replace visible controls** preserves historical
definitions and observations while stopping timers that would be hidden.

The application offers an Undo action immediately after applying. It restores
the prior configuration, any stopped timers, and the prior subject list. Further
recording or configuration edits invalidate that undo so it cannot discard newer
work. Recording remains manual, with no automatic rate calculation.

**Save current** stores the current focused subject's visible trackers, or the
visible session selection when there is no focus. Saved templates support rename,
copy, delete, import and export. They are filtered by sport and stored on this
device. No video paths, people, recorded counts, running timer state or session
hotkeys are copied into a template.

## Delivered behavior

- Six bundled templates live in `assets/sports/hockey.json`, each referencing
  the existing tracker IDs. New sport assets can define their own sets without
  widget/controller sport-name branches.
- The tracker picker groups definitions by taxonomy category, includes preserved
  session definitions, and searches labels/definitions.
- Immutable `TrackingTemplate` and `TrackingSession` collections, with typed
  template serialization and strict rejection of unsupported template formats.
- Template definitions are snapshots. An incompatible definition with an existing
  ID cannot overwrite the meaning of previously recorded data.
- Templates bind their controls to a selected subject. Existing session-wide
  controls remain compatible; adding another subject does not rewrite history.
- Hiding trackers or subjects retains their definitions, labels and raw events.
  Restoring a tracker restores its totals; **Session actions → Restore hidden
  subjects** restores hidden identities.
- Tracking workspaces are separated by sport and video identity and can be resumed
  during the current app run. Switching finishes active timers before the old
  video position is lost. This is not durable session autosave: use session files
  or the existing cloud-session workflow to keep observations across app restarts.
- Explicit seeking/scrubbing and session saves stop active timers. Normal media
  pauses still use video time. Reverse timer boundaries do not create negative
  exported/displayed intervals, and CSV labels correctly escape embedded quotes.
- Loading tracking data restores its sport/catalog, keeps saved definitions, and
  asks before attaching timestamps to a different or unidentified current video.
  A legacy empty catalog can be assigned a sport during import. Conflicting sport
  identities are rejected rather than silently reinterpreted.
- Cloud session writes use the tracking session's sport, validate the envelope
  against definitions, and exclude local video identity/path data. Existing cloud
  template entitlements/storage/rules are not added or deployed.
- Repository composition keeps local template storage separate from capture state.
  Failed loads do not overwrite the library; failed writes retain the draft and
  expose retry. Bundled templates remain usable when the local library fails.

## Implemented formats

The larger illustrative schema in `architecture.md` remains a future design.
The current, deliberately smaller template file has:

- `documentType: trackingTemplate`, `schemaVersion: 1`;
- `id`, `revision`, `sportId`, `name`, `description`, `subjectKind`;
- ordered `trackers` containing complete `TrackingDefinition` snapshots;
- optional `sourceTemplateId`.

Bundled `trackingTemplates` entries instead contain `trackerIds` resolved against
the containing taxonomy's definitions. Both formats are validated before use.

The local repository uses `flow_lens.tracking_templates.v1`. Tracking-session
files now emit `documentType: trackingSession`, `schemaVersion: 2`, sport and
video identity, visible tracker IDs, hidden subjects, subject bindings, and the
applied template ID/revision. Existing unversioned session files remain readable;
a consistent sport is inferred from their saved definitions. Template files and
session files are intentionally distinct and cannot be imported interchangeably.

## Validation

- `flutter test`: **229 tests passed**.
- `flutter analyze`: **no issues found** after the final null-safety fix.
- `dart format lib test`: completed.
- New tests cover six starter sets, basketball/volleyball catalog fixtures,
  snapshot validation, old session migration, hide/restore totals, atomic apply,
  subject bindings, idempotence, undo, incompatible definitions, sport/video
  isolation, reverse intervals, local persistence/retry, and template file
  interchange.
- Widget tests exercise preview/apply/create-subject/undo at 390×844 and 1024×768
  with 200% text scaling, plus saving and reopening a local template. Existing
  panel and dock tests also pass.
- Windows debug build and application startup succeeded; final hot restart
  succeeded. The running app does not enable the Flutter driver extension;
  interaction coverage comes from widget tests rather than an automated click
  tour of the running native player.

## Remaining work

- Atomic outcome observations, typed recording coverage, incident links, and
  event-derived/calculated metrics. Current buttons are independent manual counts.
- Explicit unobserved spans, exclusive interval groups, duplicate-interval checks,
  and a recovery/editor workflow for unmatched starts in old imported files.
  Such old starts remain in raw history and are not automatically resumed.
- Per-slot context variants, portable hotkey suggestions, and richer template
  result definitions. Existing session hotkeys are retained, not copied into
  templates; hidden/unbound controls cannot capture through those hotkeys.
- Durable local template revision history beyond the current revision. Current
  local rename increments revision, and saved sessions retain their own snapshots;
  content customization is saved as a new template copy.
- Premium account template storage/sync, entitlement policy, conflict resolution,
  cloud revisions and emulator-tested security rules.
- Production soccer, basketball and volleyball assets, competition variants,
  and coaching validation of the larger candidate metric catalog.
