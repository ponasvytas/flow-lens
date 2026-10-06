# Candidate metric catalog

This is a prioritized opportunity list, not a proposal to display every metric
simultaneously. Hockey definitions build on the existing
[coding dictionary](../hockey-taxonomy-validation/coding-dictionary.md) and
[taxonomy review](../hockey-taxonomy-review.md). External sources inform the
design; the operational rules below are proposed Flow Lens rules unless an
official source is explicitly cited.

## Organizing rules

Use sport → family → metric, with outcome and context separate from coaching
grade. "Completed" describes a pass result; "Positive" describes a coach's
assessment. A count of positive clips is not a pass-completion measure.

For each definition record: stable ID, revision, plain-language definition,
unit, eligible subjects, capture/source type, attribution rule, start/stop or
counting boundary, optional context, dependencies, and coverage requirements.

| Notation | Meaning |
| --- | --- |
| C | Discrete count or outcome observation |
| T | Time interval measured on the video timeline |
| D | Calculated result, never an independent increment button |
| A | Coaching assessment under a written rubric; optional grade |
| P1 | First useful release scope, with safeguards appropriate to capture type |
| P2 | Next expansion after context, outcome, and coverage support |
| P3 | Specialist work or additional data/instrumentation needed |
| Existing | Current tracker or direct current event counterpart exists; this does not imply all proposed context or formulas are implemented |
| New | New definition, observation subtype, or calculation required |

## Hockey: shots and attacking outcomes

| Metric | Type / priority | Subject | Capture definition and requirements | Current fit |
| --- | --- | --- | --- | --- |
| Shot outcomes | C / P1 | Shooter, team | One of goal, saved, missed target, blocked, unknown per attempt; record release timestamp and side. | Existing five event outcomes |
| Shot attempts | D / P1 | Shooter, team | Count unique shot incidents, including unknown outcome. Never add shooting and goalie observations of one incident. | Independent counter exists; derive in outcome templates |
| Shots on target | D / P1 | Shooter, team | Awarded goals plus saved shots under the selected rules; keep unknown classifications visible. | Existing aggregate manual counter |
| Shooting percentage | D / P2 | Shooter, team | Goals / shots on target; state denominator and unknown outcome count. See formula rules below. | New calculation |
| Shot context | C / P2 | Shooter, team | Rebound, one-timer, rush, screened, deflected; contextual facets of a shot, not extra attempts. | Event context exists; tracking capture missing |
| Shot location / target | C / P2 | Shooter | Coarse rink zone or marked location with rink orientation and camera confidence; goal-mouth target separately. | New structured spatial capture |
| Chances under a coaching rubric | C+A / P2 | Player, team | Define the qualifying chance before capture; record qualifying and nonqualifying opportunities if reporting a rate. | New, subjective |
| Screens / net drives | C+A / P2 | Player | One purposeful screen or drive episode; capture outcome/quality separately. | Existing event counters |
| Primary / secondary assists | C / P2 | Player | Link contributors to a goal under competition scoring rules. Do not infer from nearest prior pass alone. | New attribution |
| Expected goals / expected assists | D / P3 | Player, team | Requires a specified validated model, spatial/context inputs, and missing-data policy. | Not supported by manual labels alone |

## Hockey: passing and possession

| Metric | Type / priority | Subject | Capture definition and requirements | Current fit |
| --- | --- | --- | --- | --- |
| Pass outcomes | C / P1 | Passer | Completed, intercepted, incomplete, unknown. Intercepted is exclusive of generic incomplete. Count the attempt once. | Existing |
| Pass attempts / completion | D / P2 | Passer, team | Derive from the complete outcome set; show completed, known attempts, and unknowns. | Manual attempted/completed exist; calculation new |
| Receptions | C / P1 | Receiver | Intended receiver establishes control; distinguish passer and receiver roles. Do not imply two passes. | Pass Received needs precise definition |
| Puck involvements | C / P1 | Player | Proposed replacement for vague touch count: one control episode from gaining control until release/loss; accidental deflections separate. | Puck Touch exists; changed meaning needs a new ID |
| Controlled puck time | T / P1 | Player | Start when control is established; stop on release, loss, whistle, or observation gap. Repeated stick contacts stay in one interval. | Timer exists; protocol new |
| Team possession time | T / P2 | Team | Define whether controlled teammate passes remain team possession; explicit contested/unknown/stoppage states. Not the sum of individual touch times. | New team-level definition |
| Loose-puck recoveries | C / P1 | Player | Gain a free puck without directly dispossessing a controlled opponent; exclude already counted battle resolutions. | Existing |
| Direct takeaways | C / P1 | Player | Directly dispossess a controlled opponent under the taxonomy rule; attribute control/recovery separately if needed. | Existing |
| Controlled interceptions | C / P1 | Player | Gain control by intercepting a pass; deflection without control is different. | Existing |
| Possession losses by cause | C / P2 | Player, team | One verified control-loss incident; annotate pass/carry/reception/other. An incomplete pass or lost loose-puck battle does not necessarily qualify. | Broad legacy loss counter overlaps event types |
| Retention under pressure | D / P2 | Player | Retained outcomes / resolved pressured opportunities, with a defined opportunity boundary. | Pressure context exists; dependencies new |
| Pass method / execution | C+A / P2 | Player | Board, stretch, lateral, one-touch; separately tape-to-tape/reachable/difficult reception and coaching grade. | Event context exists |

## Hockey: battles, faceoffs, and transitions

| Metric | Type / priority | Subject | Capture definition and requirements | Current fit |
| --- | --- | --- | --- | --- |
| Battle outcomes | C / P1 | Team, participant | Won, lost, no possession change, unknown based on control at resolution; one contested episode. | Existing |
| Battle win share | D / P2 | Team, participant | Won / (won + lost) for resolved wins/losses; display unchanged and unknown separately. Participant involvement is not sole credit. | New calculation |
| Battle duration | T / P2 | Participant, team | First genuine contest until resolution or loss of view; overlapping participants refer to the same incident. | Existing timer |
| Faceoff outcomes | C / P1 | Team; optional center | Team control establishes won/lost/unknown. This is the app's coaching protocol, not guaranteed official individual scorer credit. | Existing |
| Faceoff win share | D / P2 | Team, center involvement | Won / (won + lost), show unresolved draws and zone/strength filters. | New calculation |
| Exit method | C / P1 | Puck carrier/passer, team | Carry-out, pass-out, clear-out, denied; line crossing separate from retained possession. | Existing |
| Exit control outcome | C / P2 | Team | Retained, lost, contested, unknown after the exit, under a documented observation window. | Event context exists; tracker facet missing |
| Entry method | C / P1 | Puck carrier/passer, team | Carry-in, pass-in, dump-in, denied. Store intended method for denial. | Existing |
| Entry control outcome | C / P2 | Team | Retained, lost, contested, unknown after crossing. A pass across the line alone does not establish control. | Event context exists; tracker facet missing |
| Crossing success | D / P2 | Team | Crossed attempts / all entry or exit attempts with known crossing result. Keep method and control separate. | New calculation |
| Controlled transition share | D / P2 | Team | Retained controlled transitions / eligible attempts under a pinned protocol; show unresolved observations. | Ambiguous aggregate counters exist |
| Dump-in recovery | D / P2 | Team | Our recoveries / dump-ins with known recovery outcome; pin where the recovery window ends. | Context exists; linking/calculation new |
| Entry-to-shot conversion | D / P3 | Team | Entries followed by a linked shot in the same possession sequence / eligible entries. Stop linkage at turnover or whistle. | Sequence support needed |
| Breakout / regroup quality | A / P2 | Unit, team | Annotate a sequence and decision/execution criteria; do not sum with individual passes as total activity. | Existing observation counters |

## Hockey: defense, tactics, and workload

| Metric | Type / priority | Subject | Capture definition and requirements | Current fit |
| --- | --- | --- | --- | --- |
| Defensive shot blocks | C / P1 | Defender | Link block contact to originating shot; no additional shot attempt. | Existing |
| Pressure episodes | C / P2 | Defender | Continuous attempt to constrain puck carrier; a new episode requires a reset or different carrier. | Existing observation counter |
| Pressure duration | T / P2 | Defender | Episode start/end under an explicit distance/engagement rubric; stop when view becomes inadequate. | Existing timer |
| Pressure consequences | C / P2 | Defender, team | Forced error, retreat, dispossession, no effect, unknown; distinguish association from reliable attribution. | New outcome facet |
| Stick checks / body checks | C / P2 | Player | Distinct actions with outcome and contact received context. Body-check availability depends on competition profile. | Existing separate types; combined legacy counter retained |
| Gap / coverage decisions | A / P2 | Defender | Use a defined opportunity and rubric, with ungradable state. A tag count alone is not defensive effectiveness. | Existing observation counters |
| Slot-defense time | T / P3 | Defender/unit | Define slot boundary, relevant task, and visibility; location alone does not prove effective defense. | Existing vague timer |
| Forecheck / backcheck / cycle | A or T / P2 | Unit, team | Define a sequence boundary, formation/context, and intended result. | Observation counters exist; spans new |
| Support / outlet availability | A / P2 | Player | Identify a support opportunity and whether an actionable passing option was created. | Existing observation counter |
| Offensive / neutral / defensive zone occupancy | T / P2 | Player or team | Distinguish player location from puck location; use an exclusive three-zone group plus unknown. | Two generic zone timers exist; semantics/new neutral state needed |
| Observed shift duration | T / P1 | Player | Visible entry to exit, bounded by camera coverage. State whether stoppages are included. | Existing Shift Time |
| Live-play time on ice | T+D / P2 | Player | Intersect on-ice intervals with verified live-play intervals; substitutions, intermissions, edits and missing footage handled. | Not established by Shift Time alone |
| Shift count / mean / longest | D / P2 | Player | Completed comparable shift intervals; incomplete shifts shown separately. | Raw intervals exist; result definitions new |
| Bench recovery time | T+D / P3 | Player | Gap between validated shifts within continuous footage; requires identifiable exits/entries. | New |
| Moving / stationary / unknown | T / P3 | Player | Needs a motion threshold, camera-relative movement rule, and full visibility. No inference about effort or speed. | Two independent hold timers exist |
| Distance, speed, acceleration, workload | D / P3 | Player | Requires calibrated tracking or sensor integration; manual duration is insufficient. | New instrumentation |

## Hockey: goaltending, special teams, and game context

| Metric | Type / priority | Subject | Capture definition and requirements | Current fit |
| --- | --- | --- | --- | --- |
| Saves / goals against | C / P1 | Goalie | Attribute goalie and shooting team; link shot incident. Exclude empty-net goals from an individual goalie's shots faced. | Existing |
| Shots faced / save percentage | D / P2 | Goalie | Saves + eligible goals against; saves / shots faced. Separate shootout and other competition-specific situations. | New calculation |
| Rebound disposition | C / P2 | Goalie | Frozen, directed safe, dangerous, unknown on each eligible save, under a defined rubric. | Event context exists; tracking facets new |
| Rebound control share | D / P2 | Goalie | Safe/frozen eligible outcomes / resolved eligible saves; rubric and exclusions explicit. | New calculation |
| Goalie puck handling | C+A / P2 | Goalie | Stop rim/pass/clear/set puck with retained/lost/unknown outcome. | Existing broad counter |
| Positioning / recovery technique | A / P2 | Goalie | Angle, depth, set position, recovery; mark ungradable camera views. | Existing observation counter |
| Penalties assessed | C / P1 | Team; known player | Our/opponent/coincidental assessments; preserve each assessment in a linked incident. | Existing |
| Penalty minutes | D / P2 | Player, team | Sum assessed durations under competition rules. Coincidental, misconduct and double-minor handling must be specified. | Assessed-duration capture/dependencies needed |
| Penalties drawn | C / P2 | Player | Only attribute when observable; opponent penalty is not automatically drawn by a player. | New attribution |
| Power-play / penalty-kill opportunities | C+T / P2 | Team | Use rule-aware advantage episodes and opportunity definitions, not raw penalty counts. | New structured states |
| Power-play / penalty-kill percentage | D / P3 | Team | PP goals / PP opportunities; successful kills / defined PK opportunities. Handle majors, overlapping penalties and rule variants. | New rule-aware calculations |
| Icing / offside / other stoppages | C / P1 | Team | Actual call with offending side where known; not inferred turnover or player blame. | Existing |
| Shot-attempt share (Corsi-style) | D / P3 | Team or on-ice unit | For / (for + against) including goals, saves, misses, blocks; full bilateral coverage and explicit strength filter. On-ice attribution needs lineup intervals. | New calculated analysis |
| Unblocked-attempt share (Fenwick-style) | D / P3 | Team or on-ice unit | Same coverage, excludes blocked attempts. Not identical to measured possession time. | New calculated analysis |
| Per-60 results | D / P3 | Player, unit, team | Metric count × 3600 / eligible live-play seconds; numerator and denominator must use identical strength/subject/window filters. | Validated exposure needed |

## Calculations and missing data

Define coverage per **metric family, subject, and video interval**. One global
"complete game" flag cannot make a partially tracked player or outcome complete.
Track whether all opportunities were observed separately from whether their
outcomes were visible. Zero, unknown, not observed, and not applicable are
different states.

| Result | Formula | Required interpretation |
| --- | --- | --- |
| Attempts | Number of distinct eligible incidents | Include recorded unknown outcomes; do not merge duplicate viewpoints without incident identity. |
| Pass completion among known outcomes | completed / (completed + intercepted + incomplete) | Unknowns separately displayed; a headline completion rate requires sufficiently resolved, complete coverage under a declared policy. |
| Faceoff win share among decided draws | won / (won + lost) | Unknown draws shown. Player involvement is not official faceoff credit. |
| Battle win share among wins/losses | won / (won + lost) | Unchanged and unknown counts shown; the label must disclose the narrower denominator. |
| On-target shots | goals + saved | Unknown shot outcomes cannot be assumed off target. |
| Shooting percentage | goals / (goals + saved) | Only eligible shots with known classification; incomplete classification suppresses the unqualified headline rate. |
| Save percentage | saves / (saves + eligible goals against) | Same goalie, coverage and rule scope; unknown shots or goalie attribution need an explicit incomplete state. |
| Mean observed shift | completed observed shift duration / completed shifts | Label as observed elapsed video time unless live-play time has been established. |
| Team possession share | our controlled duration / (our + opponent controlled duration) | State excluded contested/unknown/stoppage duration; this is a control-time share, not automatically a vendor's possession statistic. |

When denominator is zero, show "No eligible opportunities" rather than 0%.
When footage is selective, show observed counts and coverage; do not call them
whole-game rates. When counts are inconsistent after corrections, mark the
calculation invalid rather than clamping it into a plausible range.

Example: 8 completed, 2 intercepted, 1 incomplete, and 1 unknown pass means
12 recorded attempts and 8/11 known-outcome completion (72.7%), with one unresolved
outcome. It does not establish an unqualified 72.7% full-game completion rate.

Duration groups also need rules. Player puck time and shift time can overlap.
For one entity, moving and stationary should not overlap; zone occupancy should
not count offensive and defensive time simultaneously. Missing visibility is a
separate state rather than automatic stationary time or opponent possession.

## Other team sports: tests of the abstraction

These are examples for future sport assets, not enabled product support. Reuse
capture primitives and templates; define each sport's semantics independently.

| Sport / family | Candidate measurements | Example quick set | Important distinction |
| --- | --- | --- | --- |
| Soccer / distribution | Pass outcomes, receiving control, progressive passes, key passes, retention under pressure | Completed / intercepted / incomplete / unknown | Progression needs pitch orientation and distance/zone rules; key pass links to a shot. |
| Soccer / duels and defense | Ground/aerial duel outcomes, tackles, interceptions, recoveries, pressure episodes | Won / lost / unresolved duel | A pressure is not a tackle; a tackle is not necessarily team possession gained. |
| Soccer / attacking | Goal, saved, blocked, off-target; box entries, crosses, chances created | Four shot outcomes plus unknown | Offside/disallowed goals and own goals need separate handling. |
| Soccer / goalkeeper | Saves, eligible goals conceded, claims/punches, distribution outcomes | Save / conceded / claim / distribution | Claims of crosses are not saves. |
| Soccer / possession and exposure | Possession sequences, possession time, player minutes, transition outcomes | Our control / opponent control / contested | Provider possession methodologies differ; define ours. |
| Basketball / shooting | 2-point made/missed, 3-point made/missed, free-throw made/missed | Field goals: 2 made / 2 missed / 3 made / 3 missed | Points, FG%, eFG% and TS% are distinct; TS% needs a declared possession/FTA convention. |
| Basketball / possession | Offensive/defensive rebounds, turnovers, steals, assists | O-rebound / D-rebound / turnover / steal | A steal and opponent turnover can be one incident; not every turnover credits a steal. |
| Basketball / team play | Paint touches, screen outcomes, deflections, transition chances, possession duration | Paint touch / deflection / contested shot | Counting an opportunity differs from judging successful execution. |
| Basketball / lineup and exposure | Player minutes, substitutions, lineup possessions, points for/against | On court / off court plus scoring stream | Plus-minus and per-possession ratings need lineup/possession completeness. |
| Volleyball / serving | Ace, in-play serve, service error, unknown | Ace / in play / error / unknown | Serve effectiveness needs linked reception quality; an ace is not also a separate extra serve. |
| Volleyball / attack | Kill, attack error, continued rally, unknown | Kill / error / in play / unknown | Hitting efficiency = (kills − errors) / attempts; can be negative. |
| Volleyball / reception | Reception quality under a pinned 0–3 rubric, reception errors | Four reception grades | These rubric values are not generic positive/negative event grades. |
| Volleyball / defense | Digs, block solos/assists, block touches, rally outcomes | Dig / block point / block touch | Team blocks and individual block assists have different aggregation rules. |
| Volleyball / rotations | Side-out success, break-point success, setter distribution, rotation results | Rally won / lost with serving side | Rally, set, rotation and serve ownership replace hockey period/strength concepts. |

Other sport profiles should introduce appropriate families, subject roles,
period/set structure, units, rule variants, and templates through data. Avoid
sport-name conditionals throughout widgets and controllers.

## Definition validation with coaches

Before promoting a new metric to a built-in default, have two reviewers code the
same short continuous segment independently. Compare opportunity boundaries,
outcomes, attribution and duration boundaries; record disagreements and refine
the dictionary. Use the existing hockey validation worksheet as a starting point.
Do not invent a universal reliability threshold without considering the metric
and the decision it supports.

Prioritize a small catalog that two coaches can apply consistently over a larger
catalog of plausible but ambiguous statistics.
