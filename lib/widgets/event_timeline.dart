import 'package:flutter/material.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';

class EventTimeline extends StatelessWidget {
  final List<GameEvent> events;
  final Duration totalDuration;
  final Function(GameEvent) onEventTap;
  final SportTaxonomy? taxonomy;

  const EventTimeline({
    required this.events,
    required this.totalDuration,
    required this.onEventTap,
    this.taxonomy,
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
              // Icon width is 16px, so subtract half (8px) to center it on the timestamp
              // The padding is already applied by video_progress_bar.dart, so use full width
              const iconWidth = 16.0;
              final left = (width * clampedPercent) - (iconWidth / 2);

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
    // Get icon from taxonomy
    IconData iconData = Icons.circle;
    if (taxonomy != null) {
      final category = taxonomy!.getCategoryById(event.categoryId);
      if (category != null) {
        iconData = category.getIcon();
      }
    }

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
