import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../models/game_event.dart';
import 'event_timeline.dart';

/// Video progress bar with seek functionality
class VideoProgressBar extends StatelessWidget {
  final Player player;
  final List<GameEvent> events;
  final Function(GameEvent) onEventTap;

  const VideoProgressBar({
    required this.player,
    required this.events,
    required this.onEventTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10, // Lower position to show more video
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Timeline Events
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
            // Progress bar with time labels on sides
            StreamBuilder<Duration>(
              stream: player.stream.position,
              builder: (context, positionSnapshot) {
                return StreamBuilder<Duration>(
                  stream: player.stream.duration,
                  builder: (context, durationSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = durationSnapshot.data ?? Duration.zero;
                    final value = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return Row(
                      children: [
                        // Current time (left)
                        SizedBox(
                          width: 45,
                          child: Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
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
                              value: value.clamp(0.0, 1.0),
                              min: 0.0,
                              max: 1.0,
                              activeColor: Colors.blue,
                              inactiveColor: Colors.grey.shade700,
                              onChanged: (newValue) {
                                final newPosition = Duration(
                                  milliseconds:
                                      (newValue * duration.inMilliseconds)
                                          .round(),
                                );
                                player.seek(newPosition);
                              },
                            ),
                          ),
                        ),
                        // Duration (right)
                        SizedBox(
                          width: 45,
                          child: Text(
                            _formatDuration(duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
