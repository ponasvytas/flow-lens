import 'package:flutter/material.dart';
import '../models/game_event.dart';

class EventTimeline extends StatelessWidget {
  final List<GameEvent> events;
  final Duration totalDuration;
  final Function(GameEvent) onEventTap;

  const EventTimeline({
    required this.events,
    required this.totalDuration,
    required this.onEventTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (totalDuration.inMilliseconds == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return SizedBox(
          height: 24, // Height for the timeline markers
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: events.map((event) {
              // Calculate position (0.0 to 1.0)
              final percent =
                  event.timestamp.inMilliseconds / totalDuration.inMilliseconds;

              // Clamp to ensure it stays within bounds
              final clampedPercent = percent.clamp(0.0, 1.0);

              // Calculate left offset
              // Subtract half the icon width (e.g., 8px) to center it on the timestamp
              final left = (width * clampedPercent) - 8;

              return Positioned(
                left: left,
                child: GestureDetector(
                  onTap: () => onEventTap(event),
                  child: Tooltip(
                    message:
                        '${event.label} (${_formatDuration(event.timestamp)})',
                    child: _buildEventMarker(event),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildEventMarker(GameEvent event) {
    // Map category to icon
    final iconData = switch (event.category) {
      EventCategory.shot => Icons.sports_hockey,
      EventCategory.pass => Icons.sync_alt,
      EventCategory.battle => Icons.close,
      EventCategory.defense => Icons.shield,
      EventCategory.teamPlay => Icons.groups,
      EventCategory.penalty => Icons.gavel,
    };

    // Map grade to color
    final color = event.color; // Uses the getter from GameEvent

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white, // Background for contrast
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Center(child: Icon(iconData, size: 10, color: color)),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
