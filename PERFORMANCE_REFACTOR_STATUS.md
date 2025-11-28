# Performance Refactoring Status

## ✅ Completed: Isolate Active Drawing State

**Objective**: Prevent full-app rebuilds during high-frequency drawing gestures.

**Changes Implemented**:

1.  **Created `DrawingInteractionOverlay`**:
    -   A dedicated `StatefulWidget` that handles `onPanStart`, `onPanUpdate`, and `onPanEnd`.
    -   Maintains local state for the stroke currently being drawn (`_currentStroke`).
    -   Only rebuilds itself (the overlay) during drawing, not the entire `HockeyAnalyzerScreen`.
    -   Passes completed shapes back to the parent via callbacks (`onStrokeCompleted`, etc.).

2.  **Updated `VideoCanvas`**:
    -   Removed active drawing state parameters (`currentStroke`, `lineStart`, etc.).
    -   Added `DrawingInteractionOverlay` to the widget tree.
    -   Now accepts callbacks for completed shapes.
    -   Uses `RepaintBoundary` around the static drawing layer to prevent unnecessary repaints of completed strokes.

3.  **Updated `main.dart`**:
    -   Removed `currentStroke`, `lineStart`, `currentDrawPosition` state variables.
    -   Removed `_onStartDrawing`, `_onUpdateDrawing`, `_onEndDrawing` methods.
    -   Added `_onStrokeCompleted`, `_onLineCompleted`, `_onArrowCompleted` methods to handle data persistence.
    -   Updated `VideoCanvas` instantiation to match the new API.

**Impact**:
-   **Before**: Every mouse movement during drawing triggered a rebuild of `HockeyAnalyzerScreen` (including Video, Control Bar, Title Bar, etc.).
-   **After**: Mouse movements only rebuild `DrawingInteractionOverlay`. The rest of the app remains static.

## 🔜 Next Steps

1.  **Isolate Laser Pointer State**:
    -   Apply a similar pattern to the Laser Pointer tool.
    -   Currently, `LaserPointerOverlay` is a separate widget, but check if it triggers parent rebuilds. (It seems to be already isolated in `LaserPointerOverlay`, but `main.dart` might still be managing some state).

2.  **Optimize Control Bar**:
    -   Ensure the draggable control bar doesn't rebuild the video player when moved.
