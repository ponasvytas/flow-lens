# Event Tracking Implementation Plan

## Overview
This document outlines the plan to implement a comprehensive event tracking system for the Hockey Video Analyst app. The system allows users (coaches/players) to log game events, grade them (Positive/Negative/Neutral), and categorize them (Micro vs. Macro play) using a streamlined "Tap & Tag" workflow.

## 1. Data Model

We will create a robust data structure to support filtering and analysis.

### 1.1 Enums
```dart
enum EventCategory {
  shot,       // Offensive chances (Us)
  pass,       // Puck movement
  battle,     // 1v1, Hits, Board play
  defense,    // Defensive plays / Shots Against
  teamPlay,   // Macro: Breakouts, Entries, Regroups
  penalty     // Stoppages / Infractions
}

enum EventGrade {
  positive, // Good (Green)
  negative, // Bad (Red)
  neutral   // Neutral (Grey/White)
}
```

### 1.2 GameEvent Class
```dart
class GameEvent {
  final String id;
  final Duration timestamp;
  final EventCategory category;
  final EventGrade grade;
  final String label; // e.g., "Breakout", "Wrist Shot", "Goal"
  final String? detail; // Optional context e.g., "Intercepted", "Wide"

  // Helper to determine color based on grade
  Color get color => switch (grade) {
    EventGrade.positive => Colors.green,
    EventGrade.negative => Colors.red,
    EventGrade.neutral => Colors.grey,
  };
}
```

## 2. User Interface Components

### 2.1 The "Command Center" (Button Grid)
A 2x3 grid located in the bottom-right corner of the screen.

| Column A (Offense/Micro) | Column B (Defense/Macro) |
| :--- | :--- |
| **[Shot]** 🏒 | **[Defense]** 🛡️ |
| **[Pass]** 🔄 | **[Team Play]** 📋 |
| **[Battle]** ⚔️ | **[Penalty]** 👮 |

*   **Behavior**: Tapping a button **immediately** logs the timestamp and creates a default event.

### 2.2 The "Smart HUD" (Context Overlay)
A semi-transparent panel that appears *immediately above* the button grid when an event is triggered.

*   **Visibility**: Appears on button tap, fades out after 4 seconds if no interaction.
*   **Layout**:
    *   **Row 1 (Grade)**: [Good (Green)] [Neutral (Grey)] [Bad (Red)]
    *   **Row 2 (Tags)**: Context-specific buttons based on the selected category.

#### Context Mappings (HUD Logic)

| Category | Default Grade | Row 2 Tags (Examples) | Auto-Grade Logic |
| :--- | :--- | :--- | :--- |
| **Shot** | Neutral | Goal, On Net, Wide, Blocked | Goal -> Positive |
| **Pass** | Neutral | Tape-to-Tape, Stretch, Turnover | Turnover -> Negative |
| **Battle** | Neutral | Won, Lost, Hit Given, Hit Taken | Won -> Pos, Lost -> Neg |
| **Defense** | Negative | Goal Against, Save, Block, Clear | Save/Block -> Positive |
| **Team Play**| Neutral | Breakout, Entry, Regroup, Forecheck | (User selects Grade) |
| **Penalty** | Negative | Us, Them | Them -> Positive |

### 2.3 Timeline Visualization
*   Events will appear as markers on the video timeline.
*   **Shape**: Indicates Category (e.g., Circle=Shot, Square=Team Play).
*   **Color**: Indicates Grade (Green/Red/Grey).
*   **Tooltip**: Hovering shows the Label (e.g., "Breakout (Fail)").

## 3. Implementation Steps

### Phase 1: Foundation (Data & State)
1.  Create `lib/models/game_event.dart` with Enums and Class definitions.
2.  Update `main.dart` (or a new `EventManager` class) to hold `List<GameEvent>`.
3.  Add methods: `addEvent()`, `updateEvent()`, `deleteEvent()`.

### Phase 2: The Input UI
4.  Create `lib/widgets/event_buttons_panel.dart`.
    *   Implement the 2x3 Grid layout.
    *   Style buttons with icons and labels.
5.  Create `lib/widgets/smart_hud.dart`.
    *   Implement the popup logic (Timer, Fade animation).
    *   Implement the dynamic button generation based on `EventCategory`.

### Phase 3: Integration
6.  Integrate `EventButtonsPanel` into `main.dart` Stack (replacing the old `EventButtons`).
7.  Wire up the "Tap -> Log -> Show HUD" flow.
8.  Implement the "Auto-Grade" logic (e.g., tapping "Goal" updates the event to Positive).

### Phase 4: Visualization
9.  Create `lib/widgets/timeline_markers.dart`.
10. Overlay markers on the `VideoProgressBar` (or create a dedicated event track above it).
11. Implement seek-to-event functionality (clicking a marker jumps video).

## 4. Future Considerations (Post-MVP)
*   **JSON Export**: Save events to a file for external analysis.
*   **Filtering**: "Show only Negative Breakouts".
*   **Stats Dashboard**: "Faceoff Win %", "Shot Attempts".
