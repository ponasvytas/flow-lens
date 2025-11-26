# Build Method Refactoring Plan

## Overview

**Current**: 372-line monolithic build method  
**Goal**: Extract into 7-8 smaller StatefulWidgets  
**Expected Improvement**: 50-70% rebuild cost reduction  
**Total Time**: 4-6 hours across 3 sessions  

---

## Component Analysis

### Layers in Build Method:
1. **Video Canvas** (lines 600-666) - Video with zoom/pan and drawing
2. **Laser Overlay** (lines 668-745) - Cursor tracking (HIGH rebuild frequency)
3. **Control Bar** (lines 747-763) - Draggable controls (MEDIUM rebuild frequency)
4. **Drawing Tools** (lines 765-867) - Tool/color selection (LOW rebuild frequency)
5. **Event Buttons** (lines 869-890) - Shot/Turnover buttons (ZERO rebuilds)
6. **Shortcuts UI** (lines 892-915) - Keyboard shortcuts panel (ZERO rebuilds)
7. **Video Picker** (lines 917-937) - Initial load buttons (ZERO rebuilds)

### Rebuild Impact:
| Component | Rebuilds/sec | Impact | Priority |
|-----------|-------------|---------|----------|
| Laser Overlay | 20-30 | HIGH | 1 |
| Control Bar | Variable | MEDIUM | 2 |
| Drawing Tools | <1 | LOW | 3 |
| Others | 0 | NONE | 4 |

---

## 🎯 Phase 1: Foundation (1.5 hours)

**Goal**: Extract simple StatelessWidgets with no state  
**Risk**: LOW | **Improvement**: 10-15%

### 1.1 Extract Event Buttons (20 min) ★☆☆☆☆

**Lines**: 869-890

```dart
// lib/widgets/event_buttons.dart
class EventButtons extends StatelessWidget {
  final VoidCallback onShot;
  final VoidCallback onTurnover;

  const EventButtons({required this.onShot, required this.onTurnover, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 40, right: 20,
          child: FloatingActionButton.extended(
            onPressed: onShot,
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.sports_hockey),
            label: const Text("SHOT ON GOAL"),
          ),
        ),
        Positioned(
          bottom: 40, left: 20,
          child: FloatingActionButton.extended(
            onPressed: onTurnover,
            backgroundColor: Colors.blueGrey,
            icon: const Icon(Icons.error_outline),
            label: const Text("TURNOVER"),
          ),
        ),
      ],
    );
  }
}
```

**Usage**: `EventButtons(onShot: () => _logEvent("SHOT"), onTurnover: () => _logEvent("TURNOVER"))`

---

### 1.2 Extract Shortcuts Panel (25 min) ★★☆☆☆

**Lines**: 892-915 + _buildShortcutsPanel method

```dart
// lib/widgets/shortcuts_panel.dart
class ShortcutsPanel extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;

  const ShortcutsPanel({required this.isVisible, required this.onToggle, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 110, left: 20,
          child: FloatingActionButton(
            onPressed: onToggle,
            backgroundColor: isVisible ? Colors.blue : Colors.grey.shade700,
            mini: true,
            child: const Icon(Icons.keyboard),
          ),
        ),
        if (isVisible)
          Positioned(
            top: 100, left: 20,
            child: Material(
              color: Colors.transparent,
              child: _buildPanel(),  // Move panel code here
            ),
          ),
      ],
    );
  }
  // ... panel building methods
}
```

---

### 1.3 Extract Video Picker (15 min) ★☆☆☆☆

**Lines**: 917-937

```dart
// lib/widgets/video_picker.dart
class VideoPicker extends StatelessWidget {
  final VoidCallback onPickVideo;
  final VoidCallback onLoadTestVideo;

  const VideoPicker({required this.onPickVideo, required this.onLoadTestVideo, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(onPressed: onPickVideo, child: const Text("Select Game Video")),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onLoadTestVideo,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Load Test Video (URL)"),
          ),
        ],
      ),
    );
  }
}
```

**Checkpoint #1**:
- ✓ App launches, all buttons work
- ✓ No visual changes
- ✓ Build method now ~280 lines

---

## 🚀 Phase 2: Stateful Widgets (2 hours)

**Goal**: Extract widgets with localized state  
**Risk**: MEDIUM | **Improvement**: 30-40%

### 2.1 Extract Draggable Control Bar (45 min) ★★★☆☆

**Lines**: 747-763 + _buildControlBar method  
**Key**: Manages position state internally

```dart
// lib/widgets/control_bar.dart
class DraggableControlBar extends StatefulWidget {
  final Player player;
  final Function(double) onSpeedChange;
  final Function(Duration) onJumpForward;
  final Function(Duration) onJumpBackward;
  final VoidCallback onTogglePlayPause;

  const DraggableControlBar({/* params */, super.key});

  @override
  State<DraggableControlBar> createState() => _DraggableControlBarState();
}

class _DraggableControlBarState extends State<DraggableControlBar> {
  late Offset _position;  // ⭐ State moved here

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _position ??= Offset(MediaQuery.of(context).size.width / 2 - 175, 20);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {  // ⭐ Only rebuilds THIS widget (100 lines)
            _position = Offset(_position.dx + details.delta.dx, _position.dy + details.delta.dy);
          });
        },
        child: _buildControlBarContent(),  // Move control bar UI here
      ),
    );
  }
}
```

**Impact**: Dragging now rebuilds 100 lines instead of 372!

---

### 2.2 Extract Drawing Tools Panel (60 min) ★★★☆☆

**Lines**: 765-867  
**Key**: StatelessWidget (state stays in parent)

```dart
// lib/widgets/drawing_tools_panel.dart
class DrawingToolsPanel extends StatelessWidget {
  final bool isDrawingMode;
  final DrawingTool currentTool;
  final Color drawingColor;
  final VoidCallback onToggleDrawingMode;
  final VoidCallback onResetZoom;
  final VoidCallback onClearDrawing;
  final Function(DrawingTool) onToolChange;
  final Function(Color) onColorChange;

  const DrawingToolsPanel({/* params */, super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 200, right: 20,
      child: Column(
        children: [
          // Toggle drawing, reset zoom, tools, colors
          // All the FloatingActionButtons go here
        ],
      ),
    );
  }
}
```

**Checkpoint #2**:
- ✓ Control bar drags smoothly (much better performance!)
- ✓ Drawing tools work
- ✓ Build method now ~150 lines

---

## 🔥 Phase 3: Complex Stateful (1.5-2 hours)

**Goal**: Extract high-frequency rebuild widgets  
**Risk**: HIGH | **Improvement**: 20-30%

### 3.1 Extract Laser Pointer Overlay (60 min) ★★★★☆

**Lines**: 668-745  
**Key**: Cursor position and throttling state moved here

```dart
// lib/widgets/laser_pointer_overlay.dart
class LaserPointerOverlay extends StatefulWidget {
  final bool isActive;
  final bool isDrawingMode;
  final List<LaserTrail> trails;
  final Color color;
  final double strokeWidth;
  final Function(Offset) onStartDrawing;
  final Function(Offset) onUpdateDrawing;
  final VoidCallback onEndDrawing;

  const LaserPointerOverlay({/* params */, super.key});

  @override
  State<LaserPointerOverlay> createState() => _LaserPointerOverlayState();
}

class _LaserPointerOverlayState extends State<LaserPointerOverlay> {
  Offset? _cursorPosition;  // ⭐ State moved here
  List<DrawingPoint> _currentStroke = [];
  DateTime? _lastCursorUpdate;  // ⭐ Throttling state here
  DateTime? _lastDragUpdate;

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.width * (9 / 16),
        child: MouseRegion(
          cursor: SystemMouseCursors.none,
          onHover: (event) {
            final now = DateTime.now();
            if (_lastCursorUpdate == null ||
                now.difference(_lastCursorUpdate!) > const Duration(milliseconds: 50)) {
              setState(() {  // ⭐ Only rebuilds overlay, not parent
                _cursorPosition = event.localPosition;
              });
              _lastCursorUpdate = now;
            }
          },
          // ... rest of gesture handling
        ),
      ),
    );
  }
}
```

**Impact**: Cursor tracking now rebuilds small overlay instead of entire app!

---

### 3.2 Extract Video Canvas (60 min) ★★★★★

**Lines**: 600-666  
**Key**: Video, zoom, and drawing layer

```dart
// lib/widgets/video_canvas.dart
class VideoCanvas extends StatelessWidget {
  final VideoController controller;
  final TransformationController transformationController;
  final bool isDrawingMode;
  final DrawingTool currentTool;
  // ... all drawing state as parameters
  final Function(Offset) onStartDrawing;
  final Function(Offset) onUpdateDrawing;
  final VoidCallback onEndDrawing;
  final VoidCallback onClearDrawing;

  const VideoCanvas({/* params */, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InteractiveViewer(
        transformationController: transformationController,
        panEnabled: !isDrawingMode,
        scaleEnabled: !isDrawingMode,
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * (9 / 16),
          child: Stack(
            children: [
              RepaintBoundary(child: Video(controller: controller)),
              if (currentTool != DrawingTool.laser)
                _buildDrawingLayer(),  // Drawing canvas with gestures
            ],
          ),
        ),
      ),
    );
  }
}
```

**Checkpoint #3 (Final)**:
- ✓ All features work identically
- ✓ Build method now <100 lines
- ✓ **Performance: Smooth at all times**

---

## 📊 Expected Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Build method size | 372 lines | <100 lines | 73% smaller |
| Control bar drag lag | Noticeable | None | ✅ Solved |
| Laser cursor smoothness | Stuttery | Smooth | ✅ Solved |
| Tool switching | Slight lag | Instant | ✅ Solved |
| Overall rebuild cost | HIGH | LOW | 50-70% reduction |

---

## 🔄 Workflow Per Component

1. **Create** `lib/widgets/[name].dart`
2. **Define** widget interface (parameters, callbacks)
3. **Copy** code from build method
4. **Adapt** setState calls to callback invocations
5. **Replace** in main.dart with widget instantiation
6. **Test** hot reload and verify
7. **Commit** `git commit -m "Extract [Name] widget"`

---

## 💡 Key Principles

- **Smallest state scope**: Keep state as close to usage as possible
- **Immutable parameters**: Use callbacks for parent updates
- **const constructors**: Use when possible for free performance
- **RepaintBoundary**: Already in place, keep them
- **Test incrementally**: Each extraction should work before moving on

---

## 🎯 Success Criteria

### Quantitative:
- Build method <100 lines (down from 372)
- Control bar dragging causes 0 parent rebuilds
- Laser cursor tracks with 0 parent rebuilds
- Tool selection causes 0 video canvas rebuilds

### Qualitative:
- App feels more responsive
- No visual regressions
- Code is more maintainable
- Easy to add new features

---

## 📝 Notes

- **Phase 1** can be done in one session (easy wins)
- **Phase 2** adds significant value (control bar smoothness)
- **Phase 3** maximizes performance (laser smoothness)
- Can stop after Phase 2 if time-constrained (70% of benefit)
- Each phase is independently valuable

---

## 🚦 Start Here

Begin with Phase 1.1 (Event Buttons) - it's the easiest and builds confidence with the pattern!
