import 'dart:async';

import 'package:flutter/foundation.dart';

typedef PreviewSeek = Future<void> Function(Duration position);
typedef PreviewCommand = Future<void> Function();

/// Coordinates event lead-in/lead-out playback using video-position updates.
///
/// Generation checks make late seek/play completions harmless after navigation,
/// user interaction, video replacement, or disposal.
class EventPreviewCoordinator extends ChangeNotifier {
  EventPreviewCoordinator({
    required PreviewSeek seek,
    required PreviewCommand play,
    required PreviewCommand pause,
    required Duration Function() duration,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) : _seek = seek,
       _play = play,
       _pause = pause,
       _duration = duration,
       _onError = onError;

  final PreviewSeek _seek;
  final PreviewCommand _play;
  final PreviewCommand _pause;
  final Duration Function() _duration;
  final void Function(Object error, StackTrace stackTrace)? _onError;

  int _generation = 0;
  Duration? _pauseAt;
  bool _active = false;
  bool _disposed = false;

  bool get isActive => _active;
  Duration? get pauseAt => _pauseAt;

  Future<void> preview({
    required Duration eventTimestamp,
    required Duration leadIn,
    required Duration leadOut,
  }) async {
    final generation = ++_generation;
    final videoDuration = _duration();
    final start = _clamp(eventTimestamp - leadIn, videoDuration);
    final end = _clamp(eventTimestamp + leadOut, videoDuration);
    _pauseAt = end;
    _active = true;
    notifyListeners();
    try {
      await _seek(start);
      if (!_isCurrent(generation)) return;
      if (end <= start || videoDuration <= Duration.zero) {
        await _pause();
        if (_isCurrent(generation)) _finish();
        return;
      }
      await _play();
      if (!_isCurrent(generation)) return;
    } catch (error, stackTrace) {
      if (_isCurrent(generation)) {
        _finish();
        _onError?.call(error, stackTrace);
      }
    }
  }

  void onPosition(Duration position) {
    final target = _pauseAt;
    if (!_active || target == null || position < target) return;
    final generation = _generation;
    _active = false;
    _pauseAt = null;
    notifyListeners();
    unawaited(_pauseAtGeneration(generation));
  }

  Future<void> _pauseAtGeneration(int generation) async {
    try {
      await _pause();
    } catch (error, stackTrace) {
      if (_isCurrent(generation, requireActive: false)) {
        _onError?.call(error, stackTrace);
      }
    }
  }

  void cancel() {
    if (!_active && _pauseAt == null) {
      _generation++;
      return;
    }
    _generation++;
    _finish();
  }

  bool _isCurrent(int generation, {bool requireActive = true}) =>
      !_disposed && generation == _generation && (!requireActive || _active);

  void _finish() {
    _active = false;
    _pauseAt = null;
    if (!_disposed) notifyListeners();
  }

  static Duration _clamp(Duration value, Duration duration) {
    if (value <= Duration.zero) return Duration.zero;
    if (duration > Duration.zero && value > duration) return duration;
    return value;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _active = false;
    _pauseAt = null;
    super.dispose();
  }
}
