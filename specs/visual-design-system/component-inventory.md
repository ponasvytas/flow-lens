# Component Inventory

This inventory turns the current UI into design-system targets. It should be
completed with screenshots before implementation.

## App shell

- App title bar
- Video stage
- Mode switcher
- Dock layout
- Floating panel chrome
- Responsive mobile shell

Design questions:

- Should modes live in a top bar, side rail, segmented control, or command bar?
- Which controls stay visible across all modes?
- How much chrome should surround the video?

## Video controls

- Play/pause
- Seek forward/back
- Speed controls
- Volume/mute
- Load video
- URL input
- Timeline
- Event markers

Design questions:

- Which controls are always visible on touch devices?
- What is the compact phone layout?
- How do event markers avoid visual noise?

## Event tagging

- Event category buttons
- Event type buttons
- Grade selection
- Smart HUD
- Quick actions
- Hotkey hints

Design questions:

- What does a configured player quick-action set look like?
- How should positive/negative/neutral be colored?
- How much taxonomy depth is visible in Player mode?

## Review and navigation

- Event navigation panel
- Event table
- Filter controls
- Current event preview
- Lead-in/lead-out controls

Design questions:

- What is the simplest review experience?
- How should events be grouped and scanned?
- What is editable in Review mode vs Analyst mode?

## Tracking

- Subject cards
- Tracker controls
- Counter state
- Timer state
- Tracking session setup

Design questions:

- How many trackers can fit on tablet without overload?
- What is the best touch layout for player self-tracking?
- How should active timers stand out?

## Drawing and annotation

- Drawing tool panel
- Color picker
- Stroke width
- Laser pointer
- Clear actions

Design questions:

- Are drawing tools advanced-only or available in Review mode?
- How does touch drawing avoid accidental video controls?
- Should the drawing toolbar float, dock, or become a bottom sheet?

## Settings and export

- Settings screen
- Export dialog
- File save/load flows
- Future account/premium surfaces

Design questions:

- Which surfaces can use more standard Material components?
- Which future premium/account screens might benefit from shadcn/Forui-style
  components?
