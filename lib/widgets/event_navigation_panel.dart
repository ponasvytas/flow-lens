import 'package:flutter/material.dart';
import '../controllers/events_controller.dart';
import '../models/game_event.dart';
import '../models/events_filter.dart';

/// Panel shown in Review mode for navigating filtered events sequentially.
///
/// Shows the current position within filtered results (e.g. "3 / 12"),
/// Prev / Next buttons, and a tappable filter summary that opens the
/// events table for filter editing.
class EventNavigationPanel extends StatelessWidget {
  final EventsController controller;
  final VoidCallback onOpenEventsTable;
  final void Function(GameEvent event) onNavigateTo;

  const EventNavigationPanel({
    required this.controller,
    required this.onOpenEventsTable,
    required this.onNavigateTo,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = controller.filteredEvents;
    final active = controller.activeEvent;

    // Find current index within filtered list
    int currentIndex = -1;
    if (active != null) {
      currentIndex = filtered.indexWhere((e) => e.id == active.id);
    }

    final total = filtered.length;
    final hasEvents = total > 0;
    final hasPrev = hasEvents && currentIndex > 0;
    final hasNext = hasEvents && currentIndex < total - 1;

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
                enabled: hasPrev,
                onTap: () {
                  final event = filtered[currentIndex - 1];
                  controller.selectEvent(event);
                  onNavigateTo(event);
                },
              ),

              // Counter
              Text(
                positionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),

              // Next
              _NavButton(
                icon: Icons.skip_next,
                tooltip: 'Next event',
                enabled: hasNext,
                onTap: () {
                  final target = currentIndex == -1
                      ? filtered.first
                      : filtered[currentIndex + 1];
                  controller.selectEvent(target);
                  onNavigateTo(target);
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Filter summary chip
          GestureDetector(
            onTap: onOpenEventsTable,
            child: _FilterSummary(filter: controller.filter, total: total),
          ),
        ],
      ),
    );
  }
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
          padding: const EdgeInsets.all(6),
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
    final label = filter.isActive ? 'Filtered · $total events' : 'All events · $total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filter.isActive
            ? const Color(0xFF753b8f).withOpacity(0.6)
            : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: filter.isActive
              ? const Color(0xFF9b5fb8).withOpacity(0.7)
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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.open_in_new, size: 11, color: Colors.white38),
        ],
      ),
    );
  }
}
