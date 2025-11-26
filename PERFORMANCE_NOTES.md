# Performance Optimizations

## Applied Optimizations (Nov 25, 2025)

### 1. GPU Acceleration (lines 119-121)
- **Video Output**: `vo: 'gpu,wgpu'` for web mode
  - Tries WebGPU first, falls back to standard GPU
  - Native mode uses standard GPU acceleration

### 2. Smart Repaint Logic
- **DrawingPainter** (lines 1043-1053): Only repaints when drawing data changes
  - Checks all drawing properties before repainting
  - Prevents unnecessary redraws during video playback
  
- **LaserPainter** (lines 1144-1151): Only repaints when laser data changes
  - Monitors trails, cursor position, and color changes
  - Optimizes laser animation performance

### 3. RepaintBoundary Widgets
- **Video Layer** (line 610): Isolates video rendering from UI updates
- **Drawing Layer** (line 640): Isolates drawings from other repaints
- **Laser Layer** (line 703): Isolates laser pointer from other UI

**Benefits**: Each layer repaints independently, preventing cascading repaints

## Performance Tuning Options

### Laser Animation FPS
Located at line 295: `Duration(milliseconds: 16)` ≈ 60fps
- Reduce to 33ms for 30fps (lower CPU usage)
- Reduce to 50ms for 20fps (significant CPU savings)

### Animation Delays
- `laserDelayBeforeAnimation` (line 97): 3 seconds before erasure starts
- `laserAnimationDuration` (line 98): 1 second erasure duration

### Stroke Width
- Default: `strokeWidth = 5.0` (line 91)
- Thicker strokes = more pixels to draw

## Troubleshooting Slow Performance

If still experiencing slowness:

1. **Check browser console** for GPU warnings
2. **Try different video formats** (H.264 is most compatible)
3. **Reduce max zoom** (line 603): Change from 10.0 to 5.0
4. **Lower laser animation FPS** (line 295): 33ms or 50ms
5. **Clear old drawings** regularly with 'C' key

## Browser-Level Acceleration

For Chrome/Edge, enable hardware acceleration:
- Settings → System → "Use hardware acceleration when available"

For Firefox:
- about:preferences → General → Performance
- Uncheck "Use recommended performance settings"
- Check "Use hardware acceleration when available"
