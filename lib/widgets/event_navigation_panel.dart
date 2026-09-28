import 'package:flutter/material.dart';
import '../controllers/events_controller.dart';
import '../models/game_event.dart';
import '../models/events_filter.dart';
import '../utils/responsive_layout.dart';

/// Panel shown in Review mode for navigating filtered events sequentially.
///
/// Shows the current position within filtered results (e.g. "3 / 12"),
/// Prev / Next buttons, and a tappable filter summary that opens the
/// events table for filter editing.
///
/// Navigation is based on the current seekbar position:
/// - **Previous**: last event before current position (skips back further
///   if within [proximityThreshold] of that event). Loops to last event.
/// - **Next**: first event after current position. Loops to first event.
class EventNavigationPanel extends StatelessWidget {
  final EventsController controller;
  final VoidCallback onOpenEventsTable;
  final void Function(GameEvent event) onNavigateTo;
  final Duration currentPosition;

  /// If the seekbar is within this duration of the nearest earlier event,
  /// "Previous" will skip past it to the one before.
  static const proximityThreshold = Duration(seconds: 10);

  const EventNavigationPanel({
    required this.controller,
    required this.onOpenEventsTable,
    required this.onNavigateTo,
    required this.currentPosition,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = controller.chronologicalFilteredEvents;
    final total = sorted.length;
    final hasEvents = total > 0;

    // Use effective position that accounts for lead-in: if the seekbar is
    // up to proximityThreshold *before* an event, we consider ourselves
    // "at" that event (since navigation seeks to timestamp − leadIn).
    final effectivePosition = currentPosition + proximityThreshold;

    // Find the "current" event index: the last event at or before effectivePosition
    final currentIndex = eventIndexAtOrBefore(sorted, effectivePosition);

    // Determine previous target
    GameEvent? prevTarget;
    if (hasEvents) {
      if (currentIndex > 0) {
        prevTarget = sorted[currentIndex - 1];
      } else {
        // At first event or before all events — loop to last
        prevTarget = sorted.last;
      }
    }

    // Determine next target
    GameEvent? nextTarget;
    if (hasEvents) {
      final nextIndex = currentIndex + 1;
      if (nextIndex < sorted.length) {
        nextTarget = sorted[nextIndex];
      } else {
        // Past last event — loop to first
        nextTarget = sorted.first;
      }
    }

    final positionLabel = hasEvents
        ? '${currentIndex == -1 ? '-' : currentIndex + 1} / $total'
        : 'No events';

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Prev
              _NavButton(
                icon: Icons.skip_previous,
                tooltip: 'Previous event',
                enabled: prevTarget != null,
                onTap: () => onNavigateTo(prevTarget!),
              ),

              // Counter
              Flexible(
                child: Text(
                  positionLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Next
              _NavButton(
                icon: Icons.skip_next,
                tooltip: 'Next event',
                enabled: nextTarget != null,
                onTap: () => onNavigateTo(nextTarget!),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Filter summary chip
          if (usesPhoneLayout(context))
            OutlinedButton.icon(
              onPressed: onOpenEventsTable,
              icon: const Icon(Icons.list_alt),
              label: Text(
                controller.filter.isActive
                    ? 'Filtered events ($total)'
                    : 'All events ($total)',
              ),
            )
          else
            GestureDetector(
              onTap: onOpenEventsTable,
              child: _FilterSummary(filter: controller.filter, total: total),
            ),
        ],
      ),
    );
  }
}

/// Returns the last event at or before [position], or -1 when all are later.
/// [events] must be ordered by timestamp.
int eventIndexAtOrBefore(List<GameEvent> events, Duration position) {
  var low = 0;
  var high = events.length;
  while (low < high) {
    final middle = low + ((high - low) >> 1);
    if (events[middle].timestamp <= position) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low - 1;
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Icon(
            icon,
            color: enabled ? Colors.white : Colors.white24,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  final EventsFilter filter;
  final int total;

  const _FilterSummary({required this.filter, required this.total});

  @override
  Widget build(BuildContext context) {
    final label = filter.isActive
        ? 'Filtered · $total events'
        : 'All events · $total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filter.isActive
            ? const Color(0xFF753b8f).withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filter.isActive
              ? const Color(0xFF9b5fb8).withValues(alpha: 0.7)
              : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filter.isActive ? Icons.filter_alt : Icons.filter_alt_off,
            size: 13,
            color: Colors.white70,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.open_in_new, size: 11, color: Colors.white38),
        ],
      ),
    );
  }
}
