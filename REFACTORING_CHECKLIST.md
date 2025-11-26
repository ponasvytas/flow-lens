# Refactoring Progress Checklist

## Phase 1: Foundation (1.5 hours)

### 1.1 Event Buttons Widget (20 min)
- [ ] Create `lib/widgets/event_buttons.dart`
- [ ] Define `EventButtons` StatelessWidget
- [ ] Move shot/turnover button code (lines 869-890)
- [ ] Add to main.dart imports
- [ ] Replace in build method
- [ ] Test: Buttons work correctly
- [ ] Commit changes

### 1.2 Shortcuts Panel Widget (25 min)
- [ ] Create `lib/widgets/shortcuts_panel.dart`
- [ ] Define `ShortcutsPanel` StatelessWidget
- [ ] Move shortcuts UI code (lines 892-915)
- [ ] Move `_buildShortcutsPanel()` method
- [ ] Move `_buildShortcutRow()` method
- [ ] Add to main.dart imports
- [ ] Replace in build method
- [ ] Test: Panel toggles, shortcuts display
- [ ] Commit changes

### 1.3 Video Picker Widget (15 min)
- [ ] Create `lib/widgets/video_picker.dart`
- [ ] Define `VideoPicker` StatelessWidget
- [ ] Move picker buttons code (lines 917-937)
- [ ] Add to main.dart imports
- [ ] Replace in build method
- [ ] Test: Video picker works
- [ ] Commit changes

### Phase 1 Checkpoint
- [ ] App launches successfully
- [ ] All Phase 1 components work
- [ ] No visual regressions
- [ ] Build method reduced to ~280 lines

---

## Phase 2: Stateful Widgets (2 hours)

### 2.1 Draggable Control Bar Widget (45 min)
- [ ] Create `lib/widgets/control_bar.dart`
- [ ] Define `DraggableControlBar` StatefulWidget
- [ ] Create `_DraggableControlBarState`
- [ ] Move control bar position state to widget
- [ ] Move control bar code (lines 747-763)
- [ ] Move `_buildControlBar()` method
- [ ] Add all required callbacks as parameters
- [ ] Add to main.dart imports
- [ ] Remove `_controlBarPosition` from main state
- [ ] Replace in build method
- [ ] Test: Control bar drags smoothly
- [ ] Test: **Performance improvement visible**
- [ ] Commit changes

### 2.2 Drawing Tools Panel Widget (60 min)
- [ ] Create `lib/widgets/drawing_tools_panel.dart`
- [ ] Define `DrawingToolsPanel` StatelessWidget
- [ ] Move tools panel code (lines 765-867)
- [ ] Add tool/color state as parameters
- [ ] Add callbacks for tool/color changes
- [ ] Add to main.dart imports
- [ ] Replace in build method
- [ ] Test: Tool selection works
- [ ] Test: Color selection works
- [ ] Test: Drawing mode toggle works
- [ ] Commit changes

### Phase 2 Checkpoint
- [ ] Control bar dragging is smooth
- [ ] Drawing tools panel works perfectly
- [ ] Build method reduced to ~150 lines
- [ ] **Noticeable performance improvement**

---

## Phase 3: Complex Stateful (1.5-2 hours)

### 3.1 Laser Pointer Overlay Widget (60 min)
- [ ] Create `lib/widgets/laser_pointer_overlay.dart`
- [ ] Define `LaserPointerOverlay` StatefulWidget
- [ ] Create `_LaserPointerOverlayState`
- [ ] Move laser cursor position state to widget
- [ ] Move throttling state variables to widget
- [ ] Move laser overlay code (lines 668-745)
- [ ] Add callbacks for drawing events
- [ ] Add to main.dart imports
- [ ] Remove laser cursor state from main
- [ ] Replace in build method
- [ ] Test: Laser cursor tracks smoothly
- [ ] Test: **Laser performance dramatically better**
- [ ] Commit changes

### 3.2 Video Canvas Widget (60 min)
- [ ] Create `lib/widgets/video_canvas.dart`
- [ ] Define `VideoCanvas` StatelessWidget
- [ ] Move video player code (lines 600-666)
- [ ] Add all drawing state as parameters
- [ ] Add all drawing callbacks
- [ ] Add to main.dart imports
- [ ] Replace in build method
- [ ] Test: Video plays correctly
- [ ] Test: Zoom/pan works
- [ ] Test: Drawing on video works
- [ ] Test: Double-tap clear works
- [ ] Commit changes

### Phase 3 Checkpoint (Final)
- [ ] All features work identically to before
- [ ] Build method reduced to <100 lines
- [ ] **Performance excellent across all interactions**
- [ ] No visual regressions
- [ ] Code is cleaner and more maintainable

---

## Final Verification

### Functionality Tests
- [ ] Video loading works (both file and URL)
- [ ] Video playback controls work
- [ ] Speed adjustment works
- [ ] Jump forward/backward works
- [ ] Zoom in/out works
- [ ] Pan video works
- [ ] Drawing mode toggle works
- [ ] All drawing tools work (freehand, line, arrow)
- [ ] Laser pointer works smoothly
- [ ] Color selection works
- [ ] Clear drawing works (button and double-tap)
- [ ] Event logging works (shot, turnover)
- [ ] Keyboard shortcuts work (Space, K, C)
- [ ] Shortcuts panel toggles

### Performance Tests
- [ ] Control bar dragging: **Smooth, no lag**
- [ ] Laser cursor tracking: **Smooth at high speed**
- [ ] Drawing while zoomed: **No slowdown**
- [ ] Multiple laser trails animating: **Smooth**
- [ ] Tool switching: **Instant**
- [ ] Video playback: **Not affected by UI**

### Code Quality
- [ ] Build method <100 lines
- [ ] No code duplication
- [ ] All widgets properly documented
- [ ] Consistent naming conventions
- [ ] No unnecessary setState calls
- [ ] RepaintBoundaries in correct places

---

## Rollback Plan

If issues occur at any phase:

1. **Revert last commit**: `git revert HEAD`
2. **Check previous checkpoint**: `git log --oneline`
3. **Fix issues in isolated widget**
4. **Re-test thoroughly**
5. **Commit fix**: `git commit -m "Fix [issue]"`

---

## Time Tracking

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Phase 1.1 | 20 min | | |
| Phase 1.2 | 25 min | | |
| Phase 1.3 | 15 min | | |
| Phase 2.1 | 45 min | | |
| Phase 2.2 | 60 min | | |
| Phase 3.1 | 60 min | | |
| Phase 3.2 | 60 min | | |
| **Total** | **4-5 hours** | | |

---

## Quick Reference: Widget Extraction Pattern

```dart
// 1. Create widget file
// lib/widgets/my_component.dart

// 2. Define widget
class MyComponent extends StatelessWidget {  // or StatefulWidget
  // Parameters (from parent state)
  final Type paramName;
  
  // Callbacks (to update parent)
  final VoidCallback onAction;
  
  const MyComponent({
    required this.paramName,
    required this.onAction,
    super.key,
  });
  
  @override
  Widget build(BuildContext context) {
    // UI code from build method
    return Widget(...);
  }
}

// 3. Use in main.dart
import 'widgets/my_component.dart';

// In build method:
MyComponent(
  paramName: stateVariable,
  onAction: _handleAction,
)
```

---

## Tips

- **Start small**: Phase 1 builds confidence
- **Test frequently**: After each extraction
- **Commit often**: Makes rollback easier
- **Use hot reload**: Faster than hot restart
- **Check performance**: Should improve with each phase
- **Take breaks**: Between phases to maintain focus

---

## Success! 🎉

When all checkboxes are complete, you'll have:
- ✅ Clean, maintainable architecture
- ✅ 50-70% better performance
- ✅ Easier to add new features
- ✅ Smaller, focused components
- ✅ Better testability
