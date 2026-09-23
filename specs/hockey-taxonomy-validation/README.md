# Hockey dictionary validation

Status: tooling and protocol prepared; independent coach validation has not been performed.

Use the `hockey-2` dictionary in `assets/sports/hockey.json`. The companion
[coding dictionary](coding-dictionary.md) lists every active type and its definition.
Retain the exact taxonomy revision with the completed worksheets and source clips.

## Review protocol

1. Agree the analysis team, age group/checking rules, video coverage, and coaching
   question. Decide whether the sample is selective clips or complete tracking.
   Choose acceptable agreement and tagging-time targets before inspecting results.
2. Assemble varied clips: completed/intercepted passes, board passes, blocked and
   rebound shots, pressured exits, dump-in recoveries, contested faceoffs, goalie
   rebounds, penalties and ambiguous/occluded outcomes. Include negative examples.
3. Give each targeted observation a stable `clip_id`. A single play can contain
   multiple observations; give them separate suffixes, such as `play-12-shot` and
   `play-12-goalie`. Share the play ID in the optional incident context. Never
   match annotations solely by equal timestamps.
4. Two coaches independently fill copies of [worksheet.csv](worksheet.csv).
   Use the same observation boundaries and clip IDs. Record grade only when
   assessed; blank grade means ungraded. `context_json` is an object containing
   dictionary field IDs and string values; blank means no context recorded.
   Time each decision in seconds. Do not reconcile while coding.
5. Compare the two completed files from the project root:

   ```powershell
   python tool/compare_hockey_reviews.py reviewer-a.csv reviewer-b.csv > agreement.json
   ```

6. Inspect missing clips, category/type/grade agreement, confusion pairs, context
   disagreements and median tagging times. Missing rows are reported separately,
   never counted as agreement. No overlap produces a null fraction. Context
   differences include omitted fields; timing uses shared clips with recorded times.
7. Rewatch disagreements together. Record the chosen definition and reason in an
   adjudication log; revise ambiguous definitions and test a fresh set of clips.
   Archive the original independent sheets. Agreement does not establish ground
   truth or validate statistical rates from a selective sample.

## Common coding rules

- Grade is coaching judgment, separate from outcome. Positive is beneficial
  execution from the stated analysis perspective; Negative is detrimental;
  Neutral is an assessed neutral observation; Ungraded means no assessment.
- Unknown is an observed attempt whose outcome cannot be resolved. An omitted
  context field means not recorded. Do not infer team/player/strength from grade.
- Timestamp shots and passes at release; transitions at crossing or denial;
  possession recovery and battle/faceoff outcomes at established control;
  penalties/stoppages at the official signal. Review the lead-up with clip windows.
- Controlled possession means an observable ability to direct the next play.
  Mere contact/deflection is insufficient. A new deliberate release is a new
  shot/pass attempt; continued jostling without resolution is the same battle.
- One shot gets one primary shot outcome. A goalie save and a defensive action
  may describe the same incident; do not sum them as additional shots.
- A pass interception, possession loss, and opponent takeaway may describe one
  turnover. Use the incident reference and choose one canonical counting source.
- Track counts are independent manual observations. They are not synchronized
  with Record events and must not be added to Record totals.

## Delivered application behavior

- Twelve capture categories, 55 active choices, and 16 archived legacy choices.
  `hockey_v1.json` preserves the original dictionary; all original category/type
  pairs remain resolvable. Old records and quick presets keep saved grades/labels.
- Tap Alt, use 1–9 for the current page, PgUp/PgDn to change pages, then choose
  subtype and grade. Grade keys: 1 Positive, 2 Neutral, 3 Negative, 0 Ungraded.
  Enter saves a selected subtype without requiring a grade; Escape closes entry.
  Number-row and numpad keys are supported. Text entry retains its normal keys.
- Search All events, edit optional context in the popup, or save context/grade
  variants as distinct quick-menu slots. Suggested menus focus on match,
  transition, player-development and goalie review.
- Record and Track choices are sourced from the same taxonomy asset. Existing
  aggregate tracker IDs retain their counting definitions. JSON event/session
  exports include context and definition/revision snapshots; context is filterable.
- Loaded cloud sessions retain their own taxonomy snapshot. An old session
  continues using its historical dictionary; it is not silently upgraded.

Technical checks verify data compatibility and interaction behavior. Coaches
must still complete the independent review before the dictionary is considered
validated for their team and competition.
