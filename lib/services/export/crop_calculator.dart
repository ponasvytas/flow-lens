import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';

/// Converts a [Matrix4] view transform (as stored in [GameEvent.viewTransform])
/// into an FFmpeg-compatible crop region in source-video pixel coordinates.
///
/// The view transform encodes how the video frame is panned/zoomed on screen:
///   - Scale factor > 1 means the user zoomed in.
///   - Translation values encode the pan offset.
///
/// The returned [Rect] is in source-video pixel space (top-left origin)
/// with integer-aligned coordinates suitable for FFmpeg's `crop=w:h:x:y`.
class CropCalculator {
  /// Convert a view transform matrix to a crop rectangle.
  ///
  /// [transform] — the Matrix4 stored on the event (already normalized to a
  ///   unit viewport where 1.0 = full video width/height).
  /// [videoWidth] / [videoHeight] — source video dimensions in pixels.
  ///
  /// Returns `null` if the transform represents no zoom (scale ≈ 1.0).
  static Rect? transformToCropRect(
    Matrix4 transform,
    int videoWidth,
    int videoHeight,
  ) {
    final scale = transform.getMaxScaleOnAxis();
    if (scale <= 1.01) return null; // no meaningful zoom

    // The transform maps video coordinates to viewport coordinates:
    //   viewport = transform * video
    //
    // The visible region in video space is the inverse-transform of the
    // unit viewport [0..viewportW, 0..viewportH].
    //
    // Since the transform was normalized against a 1×1 viewport:
    //   visible width  = 1 / scale
    //   visible height = 1 / scale
    //   visible left   = -tx / scale   (tx = transform.row0[3])
    //   visible top    = -ty / scale   (ty = transform.row1[3])

    final tx = transform.entry(0, 3);
    final ty = transform.entry(1, 3);

    final visibleWidth = 1.0 / scale;
    final visibleHeight = 1.0 / scale;
    final visibleLeft = -tx / scale;
    final visibleTop = -ty / scale;

    // Map from normalized [0..1] space to pixel space.
    var cropX = (visibleLeft * videoWidth).roundToDouble();
    var cropY = (visibleTop * videoHeight).roundToDouble();
    var cropW = (visibleWidth * videoWidth).roundToDouble();
    var cropH = (visibleHeight * videoHeight).roundToDouble();

    // Clamp to valid bounds.
    if (cropX < 0) cropX = 0;
    if (cropY < 0) cropY = 0;
    if (cropX + cropW > videoWidth) cropW = videoWidth - cropX;
    if (cropY + cropH > videoHeight) cropH = videoHeight - cropY;

    // FFmpeg requires even dimensions for most codecs.
    cropW = (cropW / 2).floorToDouble() * 2;
    cropH = (cropH / 2).floorToDouble() * 2;
    cropX = (cropX / 2).floorToDouble() * 2;
    cropY = (cropY / 2).floorToDouble() * 2;

    if (cropW < 2 || cropH < 2) return null;

    return Rect.fromLTWH(cropX, cropY, cropW, cropH);
  }
}
