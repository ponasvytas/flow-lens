import 'tracking_models.dart';

/// Built-in hockey tracker definitions.
///
/// Users can pick from these when configuring a tracking session.
/// Custom trackers use [TrackingDefinition] directly with [isBuiltIn] = false.
class HockeyTrackingPresets {
  HockeyTrackingPresets._();

  // -------------------------------------------------------------------------
  // Counter presets
  // -------------------------------------------------------------------------

  static const passAttempted = TrackingDefinition(
    id: 'hockey_pass_attempted',
    label: 'Pass Attempted',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'pass',
    isBuiltIn: true,
  );

  static const passCompleted = TrackingDefinition(
    id: 'hockey_pass_completed',
    label: 'Pass Completed',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'pass',
    isBuiltIn: true,
  );

  static const passReceived = TrackingDefinition(
    id: 'hockey_pass_received',
    label: 'Pass Received',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'pass',
    isBuiltIn: true,
  );

  static const shotAttempt = TrackingDefinition(
    id: 'hockey_shot_attempt',
    label: 'Shot Attempt',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'shot',
    isBuiltIn: true,
  );

  static const shotOnNet = TrackingDefinition(
    id: 'hockey_shot_on_net',
    label: 'Shot on Net',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'shot',
    isBuiltIn: true,
  );

  static const goal = TrackingDefinition(
    id: 'hockey_goal',
    label: 'Goal',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'shot',
    isBuiltIn: true,
  );

  static const puckTouch = TrackingDefinition(
    id: 'hockey_puck_touch',
    label: 'Puck Touch',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  static const puckBattleWon = TrackingDefinition(
    id: 'hockey_puck_battle_won',
    label: 'Puck Battle Won',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  static const puckBattleLost = TrackingDefinition(
    id: 'hockey_puck_battle_lost',
    label: 'Puck Battle Lost',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  static const turnover = TrackingDefinition(
    id: 'hockey_turnover',
    label: 'Turnover',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'pass',
    isBuiltIn: true,
  );

  static const takeaway = TrackingDefinition(
    id: 'hockey_takeaway',
    label: 'Takeaway',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const interception = TrackingDefinition(
    id: 'hockey_interception',
    label: 'Interception',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const zoneEntry = TrackingDefinition(
    id: 'hockey_zone_entry',
    label: 'Zone Entry',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const controlledZoneEntry = TrackingDefinition(
    id: 'hockey_controlled_zone_entry',
    label: 'Controlled Zone Entry',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const dumpIn = TrackingDefinition(
    id: 'hockey_dump_in',
    label: 'Dump-In',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const zoneExit = TrackingDefinition(
    id: 'hockey_zone_exit',
    label: 'Zone Exit',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const controlledZoneExit = TrackingDefinition(
    id: 'hockey_controlled_zone_exit',
    label: 'Controlled Zone Exit',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const checkApplied = TrackingDefinition(
    id: 'hockey_check_applied',
    label: 'Check / Pressure Applied',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const blockedShot = TrackingDefinition(
    id: 'hockey_blocked_shot',
    label: 'Blocked Shot',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const faceoffWon = TrackingDefinition(
    id: 'hockey_faceoff_won',
    label: 'Faceoff Won',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  static const faceoffLost = TrackingDefinition(
    id: 'hockey_faceoff_lost',
    label: 'Faceoff Lost',
    kind: TrackerKind.counter,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  // -------------------------------------------------------------------------
  // Timer presets
  // -------------------------------------------------------------------------

  static const timeWithPuck = TrackingDefinition(
    id: 'hockey_time_with_puck',
    label: 'Time with Puck',
    kind: TrackerKind.timer,
    timerMode: TimerMode.toggle,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  static const shiftTime = TrackingDefinition(
    id: 'hockey_shift_time',
    label: 'Shift Time',
    kind: TrackerKind.timer,
    timerMode: TimerMode.toggle,
    sportId: 'hockey',
    isBuiltIn: true,
  );

  static const timeMoving = TrackingDefinition(
    id: 'hockey_time_moving',
    label: 'Time Moving',
    kind: TrackerKind.timer,
    timerMode: TimerMode.hold,
    sportId: 'hockey',
    isBuiltIn: true,
  );

  static const timeStationary = TrackingDefinition(
    id: 'hockey_time_stationary',
    label: 'Time Stationary',
    kind: TrackerKind.timer,
    timerMode: TimerMode.hold,
    sportId: 'hockey',
    isBuiltIn: true,
  );

  static const timeInOffensiveZone = TrackingDefinition(
    id: 'hockey_time_in_offensive_zone',
    label: 'Time in Offensive Zone',
    kind: TrackerKind.timer,
    timerMode: TimerMode.toggle,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const timeInDefensiveZone = TrackingDefinition(
    id: 'hockey_time_in_defensive_zone',
    label: 'Time in Defensive Zone',
    kind: TrackerKind.timer,
    timerMode: TimerMode.toggle,
    sportId: 'hockey',
    categoryId: 'teamPlay',
    isBuiltIn: true,
  );

  static const timePressuring = TrackingDefinition(
    id: 'hockey_time_pressuring',
    label: 'Time Pressuring Puck Carrier',
    kind: TrackerKind.timer,
    timerMode: TimerMode.hold,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const timeDefendingSlot = TrackingDefinition(
    id: 'hockey_time_defending_slot',
    label: 'Time Defending Slot',
    kind: TrackerKind.timer,
    timerMode: TimerMode.hold,
    sportId: 'hockey',
    categoryId: 'defense',
    isBuiltIn: true,
  );

  static const timeInBattle = TrackingDefinition(
    id: 'hockey_time_in_battle',
    label: 'Time in Puck Battle',
    kind: TrackerKind.timer,
    timerMode: TimerMode.hold,
    sportId: 'hockey',
    categoryId: 'battle',
    isBuiltIn: true,
  );

  // -------------------------------------------------------------------------
  // Aggregate lists
  // -------------------------------------------------------------------------

  static const List<TrackingDefinition> allCounters = [
    passAttempted,
    passCompleted,
    passReceived,
    shotAttempt,
    shotOnNet,
    goal,
    puckTouch,
    puckBattleWon,
    puckBattleLost,
    turnover,
    takeaway,
    interception,
    zoneEntry,
    controlledZoneEntry,
    dumpIn,
    zoneExit,
    controlledZoneExit,
    checkApplied,
    blockedShot,
    faceoffWon,
    faceoffLost,
  ];

  static const List<TrackingDefinition> allTimers = [
    timeWithPuck,
    shiftTime,
    timeMoving,
    timeStationary,
    timeInOffensiveZone,
    timeInDefensiveZone,
    timePressuring,
    timeDefendingSlot,
    timeInBattle,
  ];

  static const List<TrackingDefinition> all = [
    ...allCounters,
    ...allTimers,
  ];
}
