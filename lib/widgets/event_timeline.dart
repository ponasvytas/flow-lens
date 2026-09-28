import 'package:flutter/material.dart';

import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../utils/perf.dart';
import '../theme/flow_theme.dart';

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
    if (totalDuration <= Duration.zero) return const SizedBox.shrink();
    Perf.rebuildCount('EventTimeline');
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Semantics(
          label: '${events.length} event markers on the video timeline',
          child: Tooltip(
            message: 'Select the nearest event marker',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final event = nearestTimelineEvent(
                  events,
                  totalDuration,
                  width,
                  details.localPosition.dx,
                );
                if (event != null) onEventTap(event);
              },
              child: CustomPaint(
                size: Size(width, 24),
                painter: EventTimelinePainter(
                  events: events,
                  totalDuration: totalDuration,
                  taxonomy: taxonomy,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

GameEvent? nearestTimelineEvent(
  List<GameEvent> events,
  Duration duration,
  double width,
  double localX, {
  double hitRadius = 12,
}) {
  if (events.isEmpty || duration <= Duration.zero || width <= 0) return null;
  GameEvent? nearest;
  var nearestDistance = double.infinity;
  for (final event in events) {
    final fraction = event.timestamp.inMicroseconds / duration.inMicroseconds;
    final x = width * fraction.clamp(0.0, 1.0);
    final distance = (x - localX).abs();
    if (distance < nearestDistance) {
      nearest = event;
      nearestDistance = distance;
    }
  }
  return nearestDistance <= hitRadius ? nearest : null;
}

class EventTimelinePainter extends CustomPainter {
  final List<GameEvent> events;
  final Duration totalDuration;
  final SportTaxonomy? taxonomy;

  const EventTimelinePainter({
    required this.events,
    required this.totalDuration,
    this.taxonomy,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    for (final event in events) {
      final fraction =
          event.timestamp.inMicroseconds / totalDuration.inMicroseconds;
      final center = Offset(size.width * fraction.clamp(0.0, 1.0), centerY);
      final gradeColor = switch (event.grade) {
        EventGrade.positive => FlowTheme.positive,
        EventGrade.negative => FlowTheme.negative,
        EventGrade.neutral => FlowTheme.neutral,
        null => FlowTheme.muted,
      };
      canvas.drawCircle(center, 7, Paint()..color = FlowTheme.videoStage);
      canvas.drawCircle(
        center,
        6,
        Paint()
          ..color = gradeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(center, 2, Paint()..color = gradeColor);
    }
  }

  @override
  bool shouldRepaint(EventTimelinePainter oldDelegate) =>
      !identical(events, oldDelegate.events) ||
      totalDuration != oldDelegate.totalDuration ||
      taxonomy != oldDelegate.taxonomy;
}
