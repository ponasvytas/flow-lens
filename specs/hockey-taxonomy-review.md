# Hockey taxonomy review

Implementation note: the approved recommendations are now represented by the
`hockey-2` asset and application changes. See the
[coding dictionary and validation protocol](hockey-taxonomy-validation/README.md).
The review below describes the original v1 findings; independent coach validation
remains pending.

Original review date: 2026-09-15. The findings below describe v1 before implementation; see the implementation note above for current status.

This review covers all 31 sub-events in the seven current categories, the hockey tracking presets, and the constraints imposed by event entry, quick menus, filtering, and persistence. It assumes ice-hockey video coaching for both player development and team analysis. Recommendations are a coaching vocabulary design, not a claim of compliance with a particular league's official statistical definitions. Checking rules and team terminology should be profile settings.

## Main recommendation

Keep the familiar Category → Sub-event → Grade interaction. Improve what those choices mean, and let additional context be optional during review.

The present taxonomy mixes four different things:

- Observable actions: pass, block, zone entry.
- Results: goal, turnover, battle won.
- Methods or context: stretch pass, rebound shot.
- Assessments: positioning, breakdown, positive/negative grade.

That makes tagging ambiguous and reports difficult to interpret. A stretch pass can be tape-to-tape or intercepted. A rebound shot can be a goal, saved, missed, or blocked. A completed pass can be a poor decision. Each of these needs one primary event plus independent descriptors, rather than forcing the reviewer to choose only one fact.

Each event family should document its own organizing principle: shots and passes can have result-based sub-events; defensive coaching observations can have action-based sub-events. Within a family, do not mix a method, a result, and an assessment as competing choices. Longer term, store action/outcome/context separately even when the capture UI combines them into one shortcut.

## Audit of every current sub-event

Current defaults below are positive (+), negative (−), or neutral (0). A recommendation to change a definition does not authorize relabeling historical events with that new meaning.

| Current category / sub-event | Default | Finding and recommendation |
| --- | --- | --- |
| Shot / Goal | + | Keep. Define as an awarded goal, with team attribution. A goal is a result; it does not prove that the preceding decision or execution deserves a positive coaching grade. Goals disallowed later need a correction rule. |
| Shot / On Net | + | Ambiguous beside Goal: goals are also on target. For new tagging, use Saved / On target, no goal so shot outcomes are mutually exclusive. Preserve legacy On Net as ambiguous unless its historical meaning is known. |
| Shot / Wide | − | Too narrow: attempts can miss high or hit the post/crossbar without entering. Add Missed target for future use, with miss direction/post as optional descriptors. Do not reinterpret every historical Wide as a post or high miss. |
| Shot / Blocked | − | Keep as the shooting-side result. Link to a defensive Shot block observation when both are recorded. A blocked shot may still be the correct decision, so avoid compulsory negative grading. |
| Shot / Rebound | 0 | Ambiguous: a shot taken from a rebound, a save that produced a rebound, or a recovery? Replace for new use with explicit rebound-shot context, goalie rebound outcome, or puck recovery. Historical entries cannot be automatically separated. |
| Pass / Tape-to-Tape | + | Useful execution descriptor, incomplete definition of pass completion. Board, bank, area, and lead passes may all be completed. Add Completed as an outcome; keep Tape-to-tape as an optional precision descriptor. |
| Pass / Turnover | − | Only appropriate for possession loss attributable to a pass. Split new outcomes into Intercepted and Incomplete, with a possession-loss flag where observed. An incomplete pass does not necessarily transfer possession. Keep historical Turnover as pass-related possession loss with unspecified mechanism. |
| Pass / Stretch | 0 | A method/distance descriptor, not a competing result. Store alongside Completed, Intercepted, or Incomplete. Retain a quick preset for stretch passes if useful. |
| Pass / Icing | − | Move new tagging to Stoppages. Icing can follow a clearance or shot-like attempt as well as a pass. Attribute the offending team; do not assume identical icing treatment across competition rules or strength states. |
| Battle / Won | + | Keep, with a definition: our team establishes controlled possession from a genuine contest. Mere contact or touching the puck is insufficient. Define the capture point as resolution of the battle. |
| Battle / Lost | − | Keep using the same control-based definition from the same team's perspective. Do not infer the responsible individual from the team outcome alone. |
| Battle / Hit Given | + | Contact is not evidence of winning a battle. A hit that takes a defender out of the play may be poor. Move new tags to a Body check/contact action with contest and consequence as context; remove the automatic positive assumption. |
| Battle / Hit Taken | − | Receiving contact is not inherently a mistake; absorbing contact to complete a play may be excellent. Preserve contact received as a descriptor or optional development tag, independent of grade. |
| Defense / Block | + | Rename the visible label to Shot block if that is the intended meaning. If pass blocks were also logged here, preserve the old broad definition and introduce a precise new type. |
| Defense / Takeaway | + | Define narrowly enough to distinguish from Interception and Recovery: directly dispossessing an opponent who had control. A later teammate recovery can be linked but must not inflate one possession-gain metric. |
| Defense / Intercept | + | Use Interception: disrupting an intended pass and gaining control, or explicitly record deflection versus control as separate outcomes. Decide the definition before counting interceptions. |
| Defense / Giveaway | − | Move new tagging to possession loss, not a category implying it was committed by a defense player. Distinguish failed pass, failed carry, failed reception, and loss under pressure where observable. |
| Defense / Clear | + | Ambiguous about method, zone crossing, and retained control. Use Zone exit → Clear-out for a puck sent out without intended controlled possession; retain whether it crossed the line, was held in, or caused icing. Positive value is situational. |
| Defense / Breakdown | − | Too broad to support coaching feedback or reliable reviewer agreement. Replace new tagging with Gap control, Coverage, Pressure, or a team-play observation, plus a specific failure reason. Preserve old entries as unspecified defensive breakdowns. |
| Goalie / Goal Against | − | Keep as an objective goaltending outcome, attributed to the goalie/team. Do not equate every goal against with a goalie error. Record screen, deflection, lateral play, and shot context separately when available. |
| Goalie / Save | + | Keep. Separate save outcome from technical quality and rebound outcome. Link to the same shot rather than treating the save as another shot in totals. |
| Goalie / Rebound Control | − | Most obvious default-grade problem: the label sounds like a skill, but every selection begins negative. Prefer a save descriptor: Frozen, Directed to safe area, Dangerous rebound, or Unclear. Positioning of teammates/opponents affects whether a rebound was dangerous. |
| Goalie / Puck Play | 0 | Useful, but broad. Use Puck handling with action and outcome: stop rim, pass, clear, or leave/set puck; completed/retained/lost/unclear as applicable. Do not require every detail during live capture. |
| Goalie / Positioning | 0 | Keep as a coaching observation. Add optional criteria such as angle, depth, set position, and recovery. Grade only when the view supports an assessment. |
| Team Play / Breakout | 0 | A breakout is a sequence that can contain recovery, support, passes, and a zone exit. Preserve it as a sequence-level coaching tag; create a separate Zone exits family for countable exit attempts and outcomes. |
| Team Play / Zone Entry | 0 | Promote new entry tagging to its own family: carry-in, pass-in, dump-in, denied attempt. Record whether entry occurred and whether possession was retained/recovered separately. |
| Team Play / Regroup | 0 | Keep as a team-play sequence/observation. Explain that it is controlled reorganization before another attack, not any backward pass. The next entry's outcome is a linked consequence, not the definition of the regroup. |
| Team Play / Forecheck | 0 | Keep as a team-play observation, with pressure phase and consequence where needed. Distinguish evaluating the forecheck structure from recording an individual pressure or takeaway. |
| Team Play / Face Off | 0 | Promote to Faceoffs; use the consistent spelling Faceoff. Add Won, Lost, and Undetermined based on team control. Optional player and support assignments explain technique without guessing individual credit from team control. |
| Penalty / Us | − | Rename the display label to Our penalty or Penalty taken. Team-relative data must store the reference team. Add optional infraction and assessed duration; neither can be inferred from the current label. |
| Penalty / Them | + | Rename to Opponent penalty. Do not automatically call it Penalty drawn: an opponent can take an unforced or bench penalty. Record the player who drew a penalty only when that attribution is known. |

## Recommended catalog

These are proposed browseable families, not twelve buttons that must all occupy the quick menu. Their exact display order should come from a profile; new stable IDs should be allocated only after definitions are agreed. Existing IDs remain available for historical interpretation.

| Family | Proposed primary choices for new tagging | Optional descriptors / boundary |
| --- | --- | --- |
| Shots | Goal; Saved / on target, no goal; Missed target; Blocked | Technique, location, rebound shot, one-timer, rush, screen, deflection, post/crossbar. One primary outcome per attempt. Unclear outcome is allowed when the video is inconclusive. |
| Passing | Completed; Intercepted; Incomplete; Outcome unclear | Stretch, lateral, bank/board, area/lead, backward, one-touch; target, reception, pressure, possession lost. Intercepted takes precedence over generic Incomplete. |
| Puck possession | Recovery; Controlled carry; Lost control | Recovery source, pressured/unpressured, reception error, zone. Exclude pass outcomes and already-coded battle outcomes from independent turnover totals. |
| Puck battles | Won; Lost; No possession change; Unclear | Board/open-ice/net-front; participants; contact applied/received. Repeated pressure on a controlled puck is not automatically a new battle. |
| Zone exits | Carry-out; Pass-out; Clear-out; Exit denied | Record intended method for denied attempts; crossed line, possession retained, held in, or icing. Preserve Breakout as a sequence annotation rather than forcing every breakout into an exit subtype. |
| Zone entries | Carry-in; Pass-in; Dump-in; Entry denied | Intended method for denied attempts; crossed line, retained control, recovery after dump-in, offside. Crossing the line and retaining possession are separate facts. |
| Defensive play | Shot block; Takeaway; Interception; Pressure; Stick check; Body check; Gap control; Coverage | Distinguish countable discrete actions from assessments. Forced turnover, lane denial, or recovery can be linked consequences. Body-check options depend on the competition profile. |
| Team play & support | Breakout sequence; Forecheck; Backcheck; Regroup; Cycle; Support/outlet; Screen; Net drive | These are tactical moments or sequences. They should not be summed with discrete shot/pass events to produce an activity total. Later support start/end spans where useful. |
| Faceoffs | Won; Lost; Undetermined | Zone, side, strength, center/support participants. Define win as team control under the chosen coding protocol; this may differ from an official scorer's credit. |
| Goaltending | Save; Goal against; Puck handling; Positioning | Save technique and rebound disposition belong to the save. Link shot/save/goal records. Goal against is not a technical-error verdict. |
| Penalties | Our penalty; Opponent penalty; Coincidental penalties | Infraction, assessed duration, penalized/drawing players, delayed penalty. Preserve multiple linked assessments for coincidental penalties instead of flattening them into one side. |
| Stoppages | Icing; Offside; Puck out of play; Puck covered/frozen; Other whistle | Offending team and linked action. A stoppage is not automatically a turnover, shot, or negative coaching grade. |

For attempts such as exits and entries, the UI can present a compact resolved choice (for example, “Carry-in — retained”) while storing method and outcome separately. Quick buttons can prefill both. A flat expansion into every method × outcome × zone × strength × grade combination would become unmanageable.

Do not add expected-goal estimates, precise shot-danger classes, or advanced possession claims merely by adding labels. Those need reliable rink coordinates, definitions, enough context, and appropriate validation. Manually tagged scoring chances can be useful, but should have a documented rubric and remain distinct from shots on target.

## Grade and perspective

Use grade only for the coach's assessment of decision/execution for the explicitly selected analysis subject. Use outcome for what happened. A team outcome and an individual performance assessment are not interchangeable.

Examples:

- A well-chosen one-timer hits the post: Missed target + Post; a positive coaching grade may be appropriate.
- A blind pass reaches a teammate: Completed; the decision may still receive a negative grade.
- A goalie makes a save but leaves a dangerous rebound: Save + Dangerous rebound; grade the execution separately.
- A player absorbs contact and completes a zone exit: contact received does not imply a negative grade.
- A defender forces a dump-in without touching the puck: positive entry denial/pressure assessment, even though there is no takeaway.

Introduce an explicit ungraded state. Neutral means the coach assessed the event as neutral; ungraded means no assessment was made or the view is insufficient. The model already permits a null grade, but parts of the UI show null as Neutral and event capture currently requires a grade. This is a workflow change, not just a JSON edit.

Suggested defaults: no automatic coaching grade for general taxonomy selections; preserve explicitly chosen grades in quick presets. As an interim change before ungraded capture is supported, neutral is a less misleading default for Hit Given, Hit Taken, Rebound Control, Clear, Saved, and other descriptive observations. Never rewrite saved grades when defaults change.

The minimum useful context is an analysis team/reference side and, optionally, the actor/player. Then add zone, strength state, and period. Record whether context was selected, inferred, or unknown. Side-based labels such as Our penalty are unreliable across imports without the original reference team. A goalie-side observation and shooting-side observation can refer to the same play and must not imply the same grade perspective.

## Counting and consistent coding

The application is currently suited to selecting meaningful clips. A coach who tags only highlights does not produce a complete statistical sample. Mark a session/profile as selective review or exhaustive tracking before showing rates.

| Question | Required coding rule |
| --- | --- |
| How many shot attempts? | Count canonical shot events once. For a fully coded sample: goals + saved/on-target non-goals + misses + blocks, with unknowns reported separately. A goalie save or defensive block linked to that shot is not an extra attempt. |
| How many shots on target? | Under the proposed resolved shot vocabulary, goals + saved/on-target non-goals. State the chosen convention and handle ambiguous legacy On Net separately. |
| What is pass completion? | Completed / all classified pass attempts; disclose unknown outcomes and selective sampling. Tape-to-tape alone cannot supply the numerator. |
| What is controlled-entry success? | Report both crossing the line and retained possession. State the denominator: all entry attempts or only controlled-entry attempts. A successful dump-in recovery is a separate measure. |
| How many turnovers? | Count each possession-change incident once, with cause and responsibility where supported. Do not sum pass turnover, giveaway, battle lost, and an opponent takeaway as four turnovers. |
| What is faceoff win rate? | Won / (won + lost), with undetermined draws reported separately, using a documented control rule. |
| How good was the forecheck? | Requires an observation protocol and suitable opportunities/denominator; raw numbers of positive clips are not a success rate. |

Document what starts and ends an attempt, what constitutes control, how to timestamp it, and when a sequence becomes a new event. For example, timestamp a shot at release, a pass at release, and a resolved battle at control change. Use configurable pre/post clip windows to show the lead-up; do not make timestamps depend on the observer's reaction time.

Use a shared play/incident reference for linked observations, not timestamp equality: distinct actions can occur at the same time, and two reviewers may mark the same play a fraction of a second apart. Derived totals should be explicit views over canonical events, not automatic addition of every annotation.

## Fit with Flow Lens

| Current implementation | Consequence for a revision |
| --- | --- |
| Hockey asset has 7 categories and 31 event types. | Current coverage is a useful starter, but transitions, recoveries, faceoff outcomes, and off-puck play need better resolution. |
| `EventTypeTaxonomy` contains only ID, name, and default impact. | Add definition/help, aliases, enabled/archived status, and applicable descriptors/outcome definitions to the schema. |
| `GameEvent` stores category/type, timestamp, grade, labels, and zoom. | It lacks team/player context, incident links, taxonomy revision, and structured descriptors. These cannot be delivered solely by adding asset entries. |
| Staged keyboard entry dispatches categories 1–6 and sub-events 1–5. | The seventh category, Penalty, and Defense's sixth sub-event, Breakdown, are already inaccessible through staged number entry. Make dispatch data-driven and support paging/search before expanding the catalog. |
| Quick-event identity is `categoryId/eventTypeId`. | Moving a type breaks that pair; a menu also cannot currently contain the same type with two different grades. Give quick-menu slots their own stable identity if supporting variants and descriptor presets. |
| Quick menus and presets store category/type IDs, without a taxonomy revision. | Version/migrate presets along with event sessions. An event migration alone is insufficient. |
| UI often resolves current names from the active taxonomy. | Relabeling an old ID with a narrower/new meaning can silently reinterpret saved footage despite stored label/detail text. Preserve historical definitions/snapshots. |
| Record and Track use separate event models and catalogs. | Align their terminology and definitions. Tracking presets already include controlled entries/exits, dump-ins, completed passes, and faceoff outcomes missing from Record. Faceoff counters are currently categorized under Battle while the Record faceoff is under Team Play. |
| Track counters/timers are manually entered and independent of Record events. | Define a source of truth per metric. Do not double-count manual tracking increments and events derived from tagged clips. |
| Positive/negative colors and grades are embedded in several views. | Use shared semantics for outcomes, grades, and unknowns across quick buttons, event lists, filters, timeline, and export. |

Some catalog growth will require more icons in the taxonomy's icon map. Preserve familiar Shot, Pass, Defense, Goalie, and Penalty symbols where possible. Replace Battle's close/X icon, which resembles delete or negative grade. Use recognizable icons for transitions, possession, and faceoffs, with visible labels; color alone cannot communicate the category. Do not use green/red as category colors to mean success/failure—the grade already carries that meaning.

Suggested focus presets:

- General match review: Shots, Passing, Puck battles, Zone exits, Zone entries, Defensive play.
- Transition review: Recovery, exit attempts, regroup, entry attempts, turnovers, and linked support.
- Player development: Passing/reception, possession, battles, off-puck support, defensive decisions.
- Goalie review: Shot context, Save, Goal against, rebound disposition, puck handling, positioning.
- Special teams: Existing event families with strength-state context; avoid duplicate Power-play shot and Penalty-kill clear taxonomies.

These are starting presets, not hidden restrictions. All events remains searchable, and quick menus remain small and customizable. Do not make twelve-family navigation mandatory for each touch capture.

## Migration approach

1. Write and agree a coding dictionary before changing meanings: definition, example, exclusion, perspective, timestamp rule, and counting rule for each type.
2. Fix keyboard coverage and make null/neutral behavior explicit. Add help and search support for an expanded catalog.
3. Introduce taxonomy identity/content revision and a historical snapshot or equivalent immutable reference. `schemaVersion` describes the data format; it is not enough to identify a changed hockey dictionary.
4. Preserve old categories/types as legacy definitions. Display-label changes are safe only where meaning is unchanged, such as Face Off → Faceoff. Do not casually rename stable identifiers such as `teamPlay` merely to normalize casing.
5. Add new precise types and aliases for search. New recordings use the revised dictionary. Historical ambiguities remain explicit: Rebound cannot be split from the old data alone; On Net cannot be assumed to exclude goals; Breakdown cannot be assigned a specific defensive cause.
6. Migrate stored events, quick-menu slots, presets, filters, tracking references, and cloud/session exports together where a deterministic mapping exists. Preserve original IDs/labels/revision and provide unresolved legacy lookup rather than dropping records.
7. Do not infer method, team, player, zone, or strength from a grade. Do not infer objective success from Positive or failure from Negative.
8. Validate migrations by preserving event counts, timestamps, user grades, saved selections, and quick-menu behavior. Check that old sessions still render and export without unavailable-event placeholders.

The existing custom-taxonomy plan already calls for stable IDs, archived items, and session revision/snapshot references. Reuse that design rather than create a separate hockey-only migration mechanism.

## Practical rollout and validation

First release: clarify terminology and definitions, remove the misleading hit/rebound grading assumptions for future captures, fix keyboard reachability, and introduce clearly defined transition/faceoff choices with historical compatibility. Do not bundle a destructive category reorganization into a cosmetic rename.

Next release: introduce optional context/outcomes, ungraded capture, incident linking, and aligned Record/Track presets. Rich combinations should be editable in Review and prefillable in Quick events.

Validate the dictionary with two reviewers independently coding the same varied clips: completed/intercepted passes, board passes, blocked/rebound shots, pressured exits, dump-in recoveries, contested faceoffs, goalie rebounds, and penalties. Record disagreements and tagging time. Use clip-level agreement and confusion patterns to refine definitions before treating totals as statistics; choose acceptance thresholds with the coaching team rather than inventing a universal number.

Success means a coach can answer a useful question consistently—why exits fail, whether entries retain control, which battles lead to possession, how a goalie manages rebounds—without slowing ordinary touch capture or changing the meaning of older work.

## Repository evidence

- `assets/sports/hockey.json`: complete current vocabulary and defaults.
- `lib/models/sport_taxonomy.dart`: taxonomy structure and icon/color mappings.
- `lib/models/game_event.dart`: event fields and serialization.
- `lib/models/tracking_presets.dart`: the separate hockey tracking catalog.
- `lib/main.dart`: staged keyboard dispatch, grading, and event completion.
- `lib/widgets/smart_hud.dart`: event-type selection and grade defaults.
- `lib/models/quick_event.dart` and `lib/controllers/quick_events_controller.dart`: quick-menu identity and lookup.
- `lib/widgets/events_table_view.dart` and `lib/widgets/docked_events_panel.dart`: taxonomy-name resolution and null-grade presentation.
- `specs/premium-cloud-architecture/phases/05-custom-taxonomies.md`: existing historical taxonomy/versioning plan.
