# Minimal phone support

Implemented for quick-event recording and event review. A window uses the phone
workspace when its width is below 600 logical pixels, or when its height is
below 600 and its width is below 1024. Wider short windows keep the desktop or
tablet workspace. Tablet landscape widths from 900 to 1199 use a single side
tool panel so the video remains visible.

- Portrait: video above one scrollable tool panel.
- Landscape: video beside one scrollable tool panel.
- The tool selector defaults to Quick events in Record and Event Navigation in
  Review. All available tools can be selected without dragging or resizing.
- Hide tools gives more space to the video. Phone tool selection and hiding are
  temporary; they do not update saved desktop dock visibility, collapse or sizes.
- Playback, back five seconds, speed and mute remain in the transport bar.
- Quick events use full-width buttons. Capture feedback and Undo occupy their
  own area, outside the scrolling buttons.
- Events use a phone list with selection, sorting, filters, navigation, deletion
  and the existing export action. Review's All events button opens this list.
- Settings, account and cloud sessions use full-screen presentation in narrow or
  short windows. Quick-event pickers and category filters use full-screen phone
  dialogs with scrolling content and reachable actions above the keyboard.

No new mobile video-loading, encoding, cloud or background-playback capabilities
are introduced. Track and drawing remain accessible through existing tools; this
change does not redesign those workflows for phones.

## Validation

`test/phone_workspace_test.dart` exercises actual window metrics as well as
layout constraints at 320 x 568, 390 x 844, 667 x 375 and 844 x 390, with normal
and doubled text sizes. It covers capture/Undo, feedback separation, scrolling,
back navigation, review, rotation, preserved video subtree and desktop layout
state, phone event selection/sorting, settings, and keyboard-open quick editing.
The video in these widget tests is synthetic; they do not validate media decoding.

Before claiming device validation, check on iPhone Safari and Android Chrome:

1. Load a local video and record several quick events while playing.
2. Undo, rotate, change speed and seek backwards; verify video and event position.
3. Open Review, navigate events, filter the list and return to the video.
4. Edit the quick menu with the keyboard open in both orientations.
5. Check browser chrome, safe areas, pinch zoom and background/resume.
6. Return to a large window and confirm the saved workspace is unchanged.

Real-device validation remains outstanding.
