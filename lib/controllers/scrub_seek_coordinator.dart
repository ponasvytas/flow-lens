import 'dart:async';

typedef ScrubSeek = Future<void> Function(Duration position);
typedef ScrubCommand = Future<void> Function();

/// Ensures a scrub performs one seek on release and stale completions cannot
/// resume playback after a newer scrub or cancellation.
class ScrubSeekCoordinator {
  ScrubSeekCoordinator({
    required ScrubSeek seek,
    required ScrubCommand pause,
    required ScrubCommand play,
    required bool Function() isPlaying,
  }) : _seek = seek,
       _pause = pause,
       _play = play,
       _isPlaying = isPlaying;

  final ScrubSeek _seek;
  final ScrubCommand _pause;
  final ScrubCommand _play;
  final bool Function() _isPlaying;
  int _generation = 0;
  bool _wasPlaying = false;

  void begin() {
    _generation++;
    _wasPlaying = _isPlaying();
    if (_wasPlaying) unawaited(_pause());
  }

  Future<bool> complete(Duration position) async {
    final generation = _generation;
    await _seek(position);
    if (generation != _generation) return false;
    if (_wasPlaying) await _play();
    return generation == _generation;
  }

  void cancel() => _generation++;
}
