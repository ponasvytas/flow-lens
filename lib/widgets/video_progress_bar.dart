import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/game_event.dart';
import '../controllers/scrub_seek_coordinator.dart';
import '../utils/perf.dart';
import 'event_timeline.dart';

/// Video progress bar with seek functionality
class VideoProgressBar extends StatelessWidget {
  final Player player;
  final List<GameEvent> events;
  final Function(GameEvent) onEventTap;
  final VoidCallback? onScrubStart;

  const VideoProgressBar({
    required this.player,
    required this.events,
    required this.onEventTap,
    this.onScrubStart,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Perf.rebuildCount('VideoProgressBar');
    return Positioned(
      bottom: 10, // Lower position to show more video
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timeline Events — only rebuilds when duration changes, NOT on
            // every position tick.
            StreamBuilder<Duration>(
              stream: player.stream.duration,
              builder: (context, durationSnapshot) {
                final duration = durationSnapshot.data ?? Duration.zero;
                return Padding(
                  padding: const EdgeInsets.only(
                    left: 60.0,
                    right: 60.0,
                    top: 2.0,
                  ), // Match time label width (45px each + 10px padding)
                  child: EventTimeline(
                    events: events,
                    totalDuration: duration,
                    onEventTap: onEventTap,
                  ),
                );
              },
            ),
            // Seekbar — single StreamBuilder combining position + duration
            _SeekBar(player: player, onScrubStart: onScrubStart),
          ],
        ),
      ),
    );
  }
}

/// Extracted seekbar that owns its own stream subscriptions so rebuilds
/// are confined here and don't propagate to [EventTimeline].
///
/// Uses local drag state so the slider thumb follows the finger/mouse
/// immediately, and only seeks on release (onChangeEnd).
class _SeekBar extends StatefulWidget {
  final Player player;
  final VoidCallback? onScrubStart;

  const _SeekBar({required this.player, this.onScrubStart});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  bool _isDragging = false;
  double _dragValue = 0.0;
  late ScrubSeekCoordinator _scrub;

  @override
  void initState() {
    super.initState();
    _scrub = _createCoordinator();
  }

  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player) _scrub = _createCoordinator();
  }

  ScrubSeekCoordinator _createCoordinator() => ScrubSeekCoordinator(
    seek: widget.player.seek,
    pause: widget.player.pause,
    play: widget.player.play,
    isPlaying: () => widget.player.state.playing,
  );

  @override
  Widget build(BuildContext context) {
    Perf.rebuildCount('_SeekBar');
    return StreamBuilder<Duration>(
      stream: widget.player.stream.position,
      builder: (context, positionSnapshot) {
        Perf.rebuildCount('_SeekBar.stream');
        final position = positionSnapshot.data ?? Duration.zero;
        final duration = widget.player.state.duration;
        final streamValue = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        // Use drag value while dragging, stream value otherwise
        final displayValue = _isDragging ? _dragValue : streamValue;
        final displayPosition = _isDragging
            ? Duration(
                milliseconds: (_dragValue * duration.inMilliseconds).round(),
              )
            : position;

        return Row(
          children: [
            // Current time (left)
            SizedBox(
              width: 45,
              child: Text(
                _formatDuration(displayPosition),
                style: const TextStyle(color: Colors.white, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
            // Seekbar (center, expanded)
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 14.0,
                  ),
                ),
                child: Slider(
                  value: displayValue.clamp(0.0, 1.0),
                  min: 0.0,
                  max: 1.0,
                  activeColor: Colors.blue,
                  inactiveColor: Colors.grey.shade700,
                  onChangeStart: (value) {
                    _scrub.begin();
                    widget.onScrubStart?.call();
                    setState(() {
                      _isDragging = true;
                      _dragValue = value;
                    });
                  },
                  onChanged: (newValue) {
                    setState(() {
                      _dragValue = newValue;
                    });
                  },
                  onChangeEnd: (newValue) async {
                    final newPosition = Duration(
                      milliseconds: (newValue * duration.inMilliseconds)
                          .round(),
                    );
                    final current = await _scrub.complete(newPosition);
                    if (!mounted || !current) return;
                    setState(() {
                      _isDragging = false;
                    });
                  },
                ),
              ),
            ),
            // Duration (right)
            SizedBox(
              width: 45,
              child: Text(
                _formatDuration(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
