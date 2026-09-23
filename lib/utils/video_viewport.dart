import 'package:flutter/widgets.dart';

/// Keep the same video coordinates in view as the fitted canvas changes size.
Matrix4 resizeVideoTransform(
  Matrix4 transform,
  double oldWidth,
  double newWidth,
) {
  if (oldWidth <= 0 || newWidth <= 0 || oldWidth == newWidth) return transform;
  final resized = transform.clone();
  final ratio = newWidth / oldWidth;
  resized.setEntry(0, 3, transform.entry(0, 3) * ratio);
  resized.setEntry(1, 3, transform.entry(1, 3) * ratio);
  return resized;
}
