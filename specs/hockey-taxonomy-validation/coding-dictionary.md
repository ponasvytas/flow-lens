# Hockey coding dictionary

Revision: `hockey-2`. Generated from `assets/sports/hockey.json`.

Use the [validation protocol](README.md) for perspective, timestamps, counting and grading rules.

Each active row is a selectable observation. Context descriptors refine it; grades assess execution separately.

## Shot (`shot`)

One primary outcome per shot attempt; technique and quality are separate. Timestamp release.

| Choice / stable ID | Coding definition |
| --- | --- |
| Goal / `shot_goal` | Awarded goal. Timestamp the scoring shot release; attribute the shooting team. A disallowed goal must be corrected. Grade assesses execution, not the score. |
| Blocked / `shot_blocked` | Shot attempt prevented from reaching the net by a defending skater. Link a defensive Shot block to this attempt; timestamp release. |
| Saved / `shot_saved` | On-target shot stopped by the goalie, without a goal. Excludes goals and defensive shot blocks. Timestamp release. |
| Missed target / `shot_missed` | Shot that does not enter and is not a save or defensive block; includes wide, high, post and crossbar. Timestamp release. |
| Outcome unclear / `shot_unknown` | A shot attempt is visible but its result cannot be established. Do not infer a result from the grade. |

Context: Shot context, Shot technique, Miss detail.

## Pass (`pass`)

Classify each intended pass by outcome; method and precision are independent. Timestamp release.

| Choice / stable ID | Coding definition |
| --- | --- |
| Completed / `pass_completed` | Intended teammate gains control from the pass, including bank, area and lead passes. Timestamp release. |
| Intercepted / `pass_intercepted` | Opponent gains control by intercepting an intended pass. Takes precedence over generic Incomplete. Timestamp release. |
| Incomplete / `pass_incomplete` | Intended pass does not reach controlled teammate possession and is not an interception. Possession may remain contested or with our team. |
| Outcome unclear / `pass_unknown` | Pass attempt is visible but completion/control cannot be established. |

Context: Pass method, Pass execution, Pressure, Possession after action.

## Puck possession (`possession`)

Possession actions outside separately recorded passes and resolved battles.

| Choice / stable ID | Coding definition |
| --- | --- |
| Recovery / `possession_recovery` | Establish control of an available loose puck without a direct opponent dispossession. Exclude already counted battle resolutions. Timestamp control. |
| Controlled carry / `possession_carry` | Move while maintaining puck control. Mark the coaching moment; do not count every stride as a new carry. |
| Lost control / `possession_lost` | Lose controlled possession outside a classified pass or resolved battle. Use notes for reception/carry cause if visible. |

Context: Pressure, Possession after action, Contact.

## Battle (`battle`)

A genuine puck contest, resolved by team control. Contact alone is not success.

| Choice / stable ID | Coding definition |
| --- | --- |
| Won / `battle_won` | Our analysis team establishes controlled possession from a genuine puck contest. Timestamp resolution; touching the puck alone is not control. |
| Lost / `battle_lost` | The opponent establishes controlled possession from a genuine puck contest. Timestamp resolution; this does not assign blame to an individual. |
| No possession change / `battle_unchanged` | A genuine contest ends with the original controlling team retaining control. Do not also label this as a new possession gain. |
| Unclear / `battle_unknown` | A puck contest is visible but control at its resolution cannot be established. |

Context: Possession after action, Battle location, Contact.

## Zone exits (`zone_exit`)

Attempts to leave the defensive zone. Crossing the line and retaining control are separate facts.

| Choice / stable ID | Coding definition |
| --- | --- |
| Carry-out / `zone_exit_carry` | Puck crosses the blue line to leave the defensive zone by carry. Timestamp crossing; record retained possession or recovery independently. |
| Pass-out / `zone_exit_pass` | Puck crosses the blue line to leave the defensive zone by pass. Timestamp crossing; record retained possession or recovery independently. |
| Clear-out / `zone_exit_clear` | Puck crosses the blue line to leave the defensive zone by clear. Timestamp crossing; record retained possession or recovery independently. |
| Exit denied / `zone_exit_denied` | An observable attempt to leave the defensive zone ends before crossing the line. Record intended method; timestamp the denial. |

Context: Pressure, Possession after action, Crossed blue line, Intended transition, Dump/clear recovered by.

## Zone entries (`zone_entry`)

Attempts to enter the offensive zone. Count each attempt once; record retained/recovered control separately.

| Choice / stable ID | Coding definition |
| --- | --- |
| Carry-in / `zone_entry_carry` | Puck crosses the blue line to enter the offensive zone by carry. Timestamp crossing; record retained possession or recovery independently. |
| Pass-in / `zone_entry_pass` | Puck crosses the blue line to enter the offensive zone by pass. Timestamp crossing; record retained possession or recovery independently. |
| Dump-in / `zone_entry_dump` | Puck crosses the blue line to enter the offensive zone by dump. Timestamp crossing; record retained possession or recovery independently. |
| Entry denied / `zone_entry_denied` | An observable attempt to enter the offensive zone ends before crossing the line. Record intended method; timestamp the denial. |

Context: Pressure, Possession after action, Crossed blue line, Intended transition, Dump/clear recovered by.

## Defense (`defense`)

Discrete defensive actions and technical observations; consequences can be linked to the same play.

| Choice / stable ID | Coding definition |
| --- | --- |
| Takeaway / `defense_takeaway` | Directly dispossess an opponent who controlled the puck. Excludes pass interception and uncontested recovery. Link the same possession-change incident. |
| Interception / `defense_intercept` | Gain controlled possession by intercepting an intended opponent pass. A deflection without control is not an interception. |
| Shot block / `defense_shot_block` | Defending skater blocks a shot attempt. Excludes blocked passes. Link to the originating shot; timestamp contact. |
| Pressure / `defense_pressure` | Reduce the puck carrier time or options through proximity and positioning. Record consequence separately; pressure need not produce a takeaway. |
| Stick check / `defense_stick_check` | Use the stick to challenge the puck or restrict an option. A successful contact need not establish possession. |
| Body check / `defense_body_check` | Apply body contact to challenge an eligible opponent under the competition rules. Contact is not inherently positive; record checking rules and consequence. |
| Gap control / `defense_gap` | Assess defender distance, angle and speed relative to the attacker at the marked moment. Specify the observed issue in context. |
| Coverage / `defense_coverage` | Assess assignment, positioning and lane protection at the marked moment. Do not infer a breakdown cause without evidence. |

Context: Pressure, Contact, Defensive result, Coaching focus, Checking rules.

## Team Play (`teamPlay`)

Tactical observations and sequences; do not sum these with discrete action totals.

| Choice / stable ID | Coding definition |
| --- | --- |
| Breakout / `teamplay_breakout` | Sequence-level observation of recovery, support and puck movement out of the defensive zone. Not an additional discrete zone-exit attempt. |
| Regroup / `teamplay_regroup` | Controlled team reorganization before another attack, usually in the neutral zone. A backward pass alone is not a regroup. |
| Forecheck / `teamplay_forecheck` | Coaching observation of coordinated pressure on an opponent breakout. Individual pressure/takeaway records may link to the same sequence. |
| Backcheck / `teamplay_backcheck` | Team or player recovery pressure toward the defensive zone; assess positioning and assignment at the marked moment. |
| Cycle / `teamplay_cycle` | Coordinated possession rotation in the offensive zone. A sequence observation, not a new pass count. |
| Support / outlet / `teamplay_support` | Off-puck movement or positioning that creates a usable puck-carrier option. Note timing and lane availability. |
| Screen / `teamplay_screen` | Off-puck positioning that obstructs the goalie view. Record whether the view supports the observation. |
| Net drive / `teamplay_net_drive` | Off-puck route toward the net that creates space, a passing option or rebound presence. Grade decision/execution separately. |

Context: Pressure, Possession after action, Coaching focus.

## Faceoffs (`faceoff`)

Resolve a legal draw by team controlled possession under this coding protocol.

| Choice / stable ID | Coding definition |
| --- | --- |
| Won / `faceoff_won` | Our team establishes controlled possession following the draw. Timestamp control; this is team outcome, not individual center credit. |
| Lost / `faceoff_lost` | Opponent establishes controlled possession following the draw. Timestamp control; do not infer individual blame. |
| Undetermined / `faceoff_unknown` | The draw occurs but resulting team control cannot be established. |

Context: Possession after action.

## Goalie (`goalie`)

Goalie observations linked to the originating shot where applicable. Outcomes do not imply execution quality.

| Choice / stable ID | Coding definition |
| --- | --- |
| Goal Against / `goalie_goal_against` | Awarded goal conceded by the observed goalie/team. Timestamp shot release. This result does not establish goalie error. |
| Save / `goalie_save` | The goalie prevents an on-target shot from scoring. Timestamp shot release and link the shot incident; assess rebound disposition separately. |
| Puck Play / `goalie_puck_play` | Goalie handles the puck outside a save: stop a rim, pass, clear, or set the puck. Record action outcome when observed. |
| Positioning / `goalie_positioning` | Coaching observation of goalie angle, depth, set position, or recovery at the marked instant. Grade only what the view supports. |

Context: Shot context, Possession after action, Rebound disposition, Goalie puck action, Positioning focus.

## Penalty (`penalty`)

Assessed penalties attributed to the reference team; retain individual assessments for coincidental penalties.

| Choice / stable ID | Coding definition |
| --- | --- |
| Our penalty / `penalty_us` | Penalty assessed to the analysis team. Record the assessed infraction and duration if known; do not infer either from grade. |
| Opponent penalty / `penalty_them` | Penalty assessed to the opponent. Do not infer which player drew it, or that it was drawn by a player. |
| Coincidental penalties / `penalty_coincidental` | Linked penalties assessed to both teams on the same incident. Preserve separate assessments in linked notes/events; do not infer strength state. |

Context: Infraction, Assessed duration, Penalty drawn by, Checking rules.

## Stoppages (`stoppage`)

Whistles and stoppages linked to an action if known. Not automatically turnovers or negative grades.

| Choice / stable ID | Coding definition |
| --- | --- |
| Icing / `stoppage_icing` | Icing called under the competition rules. Attribute offending side if known; do not infer a pass attempt or turnover. |
| Offside / `stoppage_offside` | Offside called under the competition rules. Link the entry attempt if known. |
| Puck out of play / `stoppage_puck_out` | Play stops because the puck leaves the playing area. Do not infer delay-of-game without an assessed penalty. |
| Puck covered / frozen / `stoppage_covered` | Play stops because the puck is covered or frozen. Link a goalie save when applicable; not an extra shot. |
| Other whistle / `stoppage_other` | Other observable stoppage. Describe the reason in notes; leave unknown when the footage does not establish it. |

Context: .

## Historical choices

These remain resolvable in saved events and existing quick menus. They are excluded from new-choice pickers. No deterministic conversion can resolve their historical ambiguity; rewatch footage before recoding.

| Original pair | Saved meaning / limitation |
| --- | --- |
| `shot/shot_on_net` | Legacy on-net observation; may include goals. Do not infer a non-goal save. |
| `shot/shot_wide` | Legacy shot marked wide; high misses and posts were not explicitly distinguished. |
| `shot/shot_rebound` | Legacy rebound observation; may refer to a rebound shot, rebound allowed, or recovery. |
| `pass/pass_tape_to_tape` | Legacy precise pass to a teammate stick; not a count of all completed passes. |
| `pass/pass_turnover` | Legacy possession loss attributed to a pass; mechanism unspecified. |
| `pass/pass_stretch` | Legacy long advancing pass; completion and possession outcome unspecified. |
| `pass/pass_icing` | Legacy icing observation filed under Passing; do not infer a pass attempt. |
| `battle/battle_hit_given` | Legacy contact applied; does not imply a battle win or good execution. |
| `battle/battle_hit_taken` | Legacy contact received; does not imply a battle loss or poor execution. |
| `defense/defense_block` | Legacy block observation; the blocked object was not specified. |
| `defense/defense_giveaway` | Legacy possession loss; action and responsible role unspecified. |
| `defense/defense_clear` | Legacy clearance observation; crossing the blue line and retained possession unspecified. |
| `defense/defense_breakdown` | Legacy defensive breakdown; technical cause unspecified. |
| `teamPlay/teamplay_zone_entry` | Legacy zone-entry observation; method and possession outcome unspecified. |
| `teamPlay/teamplay_faceoff` | Legacy faceoff observation; win/loss outcome unspecified. |
| `goalie/goalie_rebound_control` | Legacy rebound-control assessment; rebound disposition unspecified. Preserve the recorded grade. |

## Optional context fields

| Field / ID | Values | Guidance |
| --- | --- | --- |
| Analysis team / `analysisTeam` | Free text | Team whose perspective is used for Our/Opponent and coaching grades. |
| Acting side / `side` | Our team, Opponent, Unknown |  |
| Player / goalie / `actor` | Free text | Name or jersey number; leave unset when unknown. |
| Zone / `zone` | Defensive, Neutral, Offensive, Unknown |  |
| Strength / `strength` | Even strength, Power play, Penalty kill, Empty net, Other, Unknown |  |
| Period / `period` | 1, 2, 3, Overtime, Shootout, Other |  |
| Recording coverage / `coverage` | Selective clips, Complete tracking | Complete tracking only when all relevant opportunities were coded; selective clips do not support success rates. |
| Linked play ID / `incident` | Free text | Use the same ID for observations of the same play. Do not count a shot, save and block as separate attempts. |
| Coaching note / `notes` | Free text |  |
| Shot context / `shotContext` | Rebound shot, One-timer, Rush, Screened, Deflected, Other |  |
| Shot technique / `shotTechnique` | Wrist, Snap, Slap, Backhand, Tip/deflection, Other, Unknown |  |
| Miss detail / `miss` | Wide, High, Post/crossbar, Unknown |  |
| Pass method / `passMethod` | Direct, Stretch, Bank/board, Area/lead, Lateral, Backward, One-touch, Other |  |
| Pass execution / `passExecution` | Tape-to-tape, Reachable, Difficult reception, Unknown |  |
| Pressure / `pressure` | Pressured, Unpressured, Unknown |  |
| Possession after action / `possession` | Retained, Lost, Contested, Unknown |  |
| Battle location / `battleLocation` | Boards, Open ice, Net front, Other |  |
| Contact / `contact` | Applied, Received, Both, None, Unknown |  |
| Crossed blue line / `crossedLine` | Yes, No, Unknown |  |
| Intended transition / `intendedMethod` | Carry, Pass, Dump/clear, Unknown |  |
| Dump/clear recovered by / `recovered` | Our team, Opponent, Neither yet, Unknown |  |
| Defensive result / `defensiveResult` | Possession gained, Lane denied, Forced dump, Forced turnover, Beaten, No change, Unknown |  |
| Coaching focus / `coverageIssue` | Gap, Assignment, Support, Timing, Lane, Other |  |
| Rebound disposition / `rebound` | Frozen, Directed safely, Dangerous rebound, Unclear |  |
| Goalie puck action / `goalieAction` | Stop rim, Pass, Clear, Set/leave puck, Other |  |
| Positioning focus / `goaliePosition` | Angle, Depth, Set position, Recovery, Other |  |
| Infraction / `infraction` | Free text | Use the competition rule terminology; no assumed duration. |
| Assessed duration / `penaltyDuration` | Free text | As assessed (for example 2 min, 5 min, misconduct). |
| Penalty drawn by / `drawnBy` | Free text | Only identify a player when attribution is supported. |
| Checking rules / `checkingRules` | Body checking permitted, Body checking not permitted, Unknown |  |

## Manual tracking dictionary

Track counts are an independent source. Aggregate counters retain their original scope; do not add an aggregate to its component counters or to Record totals.

| Tracker / stable ID | Definition |
| --- | --- |
| Pass Attempted / `hockey_pass_attempted` | Manual count of pass attempted. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Pass / Completed / `hockey_pass_completed` | Intended teammate gains control from the pass, including bank, area and lead passes. Timestamp release. |
| Pass Received / `hockey_pass_received` | Manual count of pass received. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Shot Attempt / `hockey_shot_attempt` | Manual count of shot attempt. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Shots on target (including goals) / `hockey_shot_on_net` | Count each on-target attempt once, including goals. Do not also add the Goal counter to this aggregate. |
| Shot / Goal / `hockey_goal` | Awarded goal. Timestamp the scoring shot release; attribute the shooting team. A disallowed goal must be corrected. Grade assesses execution, not the score. |
| Puck Touch / `hockey_puck_touch` | Manual count of puck touch. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Battle / Won / `hockey_puck_battle_won` | Our analysis team establishes controlled possession from a genuine puck contest. Timestamp resolution; touching the puck alone is not control. |
| Battle / Lost / `hockey_puck_battle_lost` | The opponent establishes controlled possession from a genuine puck contest. Timestamp resolution; this does not assign blame to an individual. |
| Possession losses (all causes) / `hockey_turnover` | Count each possession-change incident once across passes, carries and battles. Do not sum this aggregate with its causes. |
| Defense / Takeaway / `hockey_takeaway` | Directly dispossess an opponent who controlled the puck. Excludes pass interception and uncontested recovery. Link the same possession-change incident. |
| Defense / Interception / `hockey_interception` | Gain controlled possession by intercepting an intended opponent pass. A deflection without control is not an interception. |
| Zone Entry / `hockey_zone_entry` | Manual count of zone entry. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Controlled Zone Entry / `hockey_controlled_zone_entry` | Manual count of controlled zone entry. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Zone entries / Dump-in / `hockey_dump_in` | Puck crosses the blue line to enter the offensive zone by dump. Timestamp crossing; record retained possession or recovery independently. |
| Zone Exit / `hockey_zone_exit` | Manual count of zone exit. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Controlled Zone Exit / `hockey_controlled_zone_exit` | Manual count of controlled zone exit. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Check / pressure applied / `hockey_check_applied` | Manual combined count of checks or pressure actions. Not an inference of possession gained or good execution. |
| Defense / Shot block / `hockey_blocked_shot` | Defending skater blocks a shot attempt. Excludes blocked passes. Link to the originating shot; timestamp contact. |
| Faceoffs / Won / `hockey_faceoff_won` | Our team establishes controlled possession following the draw. Timestamp control; this is team outcome, not individual center credit. |
| Faceoffs / Lost / `hockey_faceoff_lost` | Opponent establishes controlled possession following the draw. Timestamp control; do not infer individual blame. |
| Time with Puck / `hockey_time_with_puck` | Manual duration of time with puck. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Shift Time / `hockey_shift_time` | Manual duration of shift time. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time Moving / `hockey_time_moving` | Manual duration of time moving. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time Stationary / `hockey_time_stationary` | Manual duration of time stationary. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time in Offensive Zone / `hockey_time_in_offensive_zone` | Manual duration of time in offensive zone. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time in Defensive Zone / `hockey_time_in_defensive_zone` | Manual duration of time in defensive zone. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time Pressuring Puck Carrier / `hockey_time_pressuring` | Manual duration of time pressuring puck carrier. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time Defending Slot / `hockey_time_defending_slot` | Manual duration of time defending slot. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Time in Puck Battle / `hockey_time_in_battle` | Manual duration of time in puck battle. Record all relevant opportunities before using rates; do not add manual counts to derived Record totals. |
| Shot / Blocked / `event_shot_blocked` | Shot attempt prevented from reaching the net by a defending skater. Link a defensive Shot block to this attempt; timestamp release. |
| Shot / Saved / `event_shot_saved` | On-target shot stopped by the goalie, without a goal. Excludes goals and defensive shot blocks. Timestamp release. |
| Shot / Missed target / `event_shot_missed` | Shot that does not enter and is not a save or defensive block; includes wide, high, post and crossbar. Timestamp release. |
| Shot / Outcome unclear / `event_shot_unknown` | A shot attempt is visible but its result cannot be established. Do not infer a result from the grade. |
| Pass / Intercepted / `event_pass_intercepted` | Opponent gains control by intercepting an intended pass. Takes precedence over generic Incomplete. Timestamp release. |
| Pass / Incomplete / `event_pass_incomplete` | Intended pass does not reach controlled teammate possession and is not an interception. Possession may remain contested or with our team. |
| Pass / Outcome unclear / `event_pass_unknown` | Pass attempt is visible but completion/control cannot be established. |
| Battle / No possession change / `event_battle_unchanged` | A genuine contest ends with the original controlling team retaining control. Do not also label this as a new possession gain. |
| Battle / Unclear / `event_battle_unknown` | A puck contest is visible but control at its resolution cannot be established. |
| Defense / Pressure / `event_defense_pressure` | Reduce the puck carrier time or options through proximity and positioning. Record consequence separately; pressure need not produce a takeaway. |
| Defense / Stick check / `event_defense_stick_check` | Use the stick to challenge the puck or restrict an option. A successful contact need not establish possession. |
| Defense / Body check / `event_defense_body_check` | Apply body contact to challenge an eligible opponent under the competition rules. Contact is not inherently positive; record checking rules and consequence. |
| Defense / Gap control / `event_defense_gap` | Assess defender distance, angle and speed relative to the attacker at the marked moment. Specify the observed issue in context. |
| Defense / Coverage / `event_defense_coverage` | Assess assignment, positioning and lane protection at the marked moment. Do not infer a breakdown cause without evidence. |
| Goalie / Goal Against / `event_goalie_goal_against` | Awarded goal conceded by the observed goalie/team. Timestamp shot release. This result does not establish goalie error. |
| Goalie / Save / `event_goalie_save` | The goalie prevents an on-target shot from scoring. Timestamp shot release and link the shot incident; assess rebound disposition separately. |
| Goalie / Puck Play / `event_goalie_puck_play` | Goalie handles the puck outside a save: stop a rim, pass, clear, or set the puck. Record action outcome when observed. |
| Goalie / Positioning / `event_goalie_positioning` | Coaching observation of goalie angle, depth, set position, or recovery at the marked instant. Grade only what the view supports. |
| Team Play / Breakout / `event_teamplay_breakout` | Sequence-level observation of recovery, support and puck movement out of the defensive zone. Not an additional discrete zone-exit attempt. |
| Team Play / Regroup / `event_teamplay_regroup` | Controlled team reorganization before another attack, usually in the neutral zone. A backward pass alone is not a regroup. |
| Team Play / Forecheck / `event_teamplay_forecheck` | Coaching observation of coordinated pressure on an opponent breakout. Individual pressure/takeaway records may link to the same sequence. |
| Team Play / Backcheck / `event_teamplay_backcheck` | Team or player recovery pressure toward the defensive zone; assess positioning and assignment at the marked moment. |
| Team Play / Cycle / `event_teamplay_cycle` | Coordinated possession rotation in the offensive zone. A sequence observation, not a new pass count. |
| Team Play / Support / outlet / `event_teamplay_support` | Off-puck movement or positioning that creates a usable puck-carrier option. Note timing and lane availability. |
| Team Play / Screen / `event_teamplay_screen` | Off-puck positioning that obstructs the goalie view. Record whether the view supports the observation. |
| Team Play / Net drive / `event_teamplay_net_drive` | Off-puck route toward the net that creates space, a passing option or rebound presence. Grade decision/execution separately. |
| Penalty / Our penalty / `event_penalty_us` | Penalty assessed to the analysis team. Record the assessed infraction and duration if known; do not infer either from grade. |
| Penalty / Opponent penalty / `event_penalty_them` | Penalty assessed to the opponent. Do not infer which player drew it, or that it was drawn by a player. |
| Penalty / Coincidental penalties / `event_penalty_coincidental` | Linked penalties assessed to both teams on the same incident. Preserve separate assessments in linked notes/events; do not infer strength state. |
| Puck possession / Recovery / `event_possession_recovery` | Establish control of an available loose puck without a direct opponent dispossession. Exclude already counted battle resolutions. Timestamp control. |
| Puck possession / Controlled carry / `event_possession_carry` | Move while maintaining puck control. Mark the coaching moment; do not count every stride as a new carry. |
| Puck possession / Lost control / `event_possession_lost` | Lose controlled possession outside a classified pass or resolved battle. Use notes for reception/carry cause if visible. |
| Zone exits / Carry-out / `event_zone_exit_carry` | Puck crosses the blue line to leave the defensive zone by carry. Timestamp crossing; record retained possession or recovery independently. |
| Zone exits / Pass-out / `event_zone_exit_pass` | Puck crosses the blue line to leave the defensive zone by pass. Timestamp crossing; record retained possession or recovery independently. |
| Zone exits / Clear-out / `event_zone_exit_clear` | Puck crosses the blue line to leave the defensive zone by clear. Timestamp crossing; record retained possession or recovery independently. |
| Zone exits / Exit denied / `event_zone_exit_denied` | An observable attempt to leave the defensive zone ends before crossing the line. Record intended method; timestamp the denial. |
| Zone entries / Carry-in / `event_zone_entry_carry` | Puck crosses the blue line to enter the offensive zone by carry. Timestamp crossing; record retained possession or recovery independently. |
| Zone entries / Pass-in / `event_zone_entry_pass` | Puck crosses the blue line to enter the offensive zone by pass. Timestamp crossing; record retained possession or recovery independently. |
| Zone entries / Entry denied / `event_zone_entry_denied` | An observable attempt to enter the offensive zone ends before crossing the line. Record intended method; timestamp the denial. |
| Faceoffs / Undetermined / `event_faceoff_unknown` | The draw occurs but resulting team control cannot be established. |
| Stoppages / Icing / `event_stoppage_icing` | Icing called under the competition rules. Attribute offending side if known; do not infer a pass attempt or turnover. |
| Stoppages / Offside / `event_stoppage_offside` | Offside called under the competition rules. Link the entry attempt if known. |
| Stoppages / Puck out of play / `event_stoppage_puck_out` | Play stops because the puck leaves the playing area. Do not infer delay-of-game without an assessed penalty. |
| Stoppages / Puck covered / frozen / `event_stoppage_covered` | Play stops because the puck is covered or frozen. Link a goalie save when applicable; not an extra shot. |
| Stoppages / Other whistle / `event_stoppage_other` | Other observable stoppage. Describe the reason in notes; leave unknown when the footage does not establish it. |
