import 'package:flutter/material.dart';
import '../controllers/events_controller.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';

/// Compact events table designed to be docked beside the video player.
///
/// Shows a scrollable list of events with minimal columns:
/// grade dot, timestamp, category, and event type.
/// The active event is highlighted and auto-scrolled into view.
class DockedEventsPanel extends StatefulWidget {
  final EventsController controller;
  final SportTaxonomy? taxonomy;
  final Function(GameEvent) onEventTap;
  final VoidCallback onClose;
  final Duration currentPosition;

  const DockedEventsPanel({
    required this.controller,
    required this.taxonomy,
    required this.onEventTap,
    required this.onClose,
    required this.currentPosition,
    super.key,
  });

  @override
  State<DockedEventsPanel> createState() => _DockedEventsPanelState();
}

class _DockedEventsPanelState extends State<DockedEventsPanel> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DockedEventsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll to active event when it changes
    final active = widget.controller.activeEvent;
    if (active != null && active.id != _lastScrolledToId) {
      _lastScrolledToId = active.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToEvent(active);
      });
    }
  }

  void _scrollToEvent(GameEvent event) {
    final events = widget.controller.filteredEvents;
    final index = events.indexWhere((e) => e.id == event.id);
    if (index == -1 || !_scrollController.hasClients) return;

    const itemHeight = 44.0; // Approximate row height
    final targetOffset = index * itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    // Only scroll if the item is outside the visible area
    if (targetOffset < currentOffset ||
        targetOffset > currentOffset + viewportHeight - itemHeight) {
      _scrollController.animateTo(
        (targetOffset - viewportHeight / 2 + itemHeight / 2)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  String _getCategoryName(String categoryId) {
    final category = widget.taxonomy?.getCategoryById(categoryId);
    return category?.name ?? categoryId;
  }

  String _getEventTypeName(GameEvent event) {
    if (event.eventTypeId != null && widget.taxonomy != null) {
      final eventType = widget.taxonomy!.getEventTypeById(event.eventTypeId!);
      if (eventType != null) return eventType.name;
    }
    return event.detail ?? event.label;
  }

  Color _getGradeColor(EventGrade? grade) {
    return switch (grade) {
      EventGrade.positive => Colors.green,
      EventGrade.negative => Colors.red,
      EventGrade.neutral => Colors.grey,
      null => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final events = List<GameEvent>.from(widget.controller.filteredEvents)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final activeId = widget.controller.activeEvent?.id;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        border: Border(
          left: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF753b8f),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Events',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${events.length}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: widget.onClose,
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Events list
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Text(
                      widget.controller.filter.isActive
                          ? 'No matches'
                          : 'No events',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: events.length,
                    itemExtent: 44,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isActive = event.id == activeId;
                      final isPast =
                          event.timestamp <= widget.currentPosition;

                      return _CompactEventRow(
                        timestamp: _formatDuration(event.timestamp),
                        category: _getCategoryName(event.categoryId),
                        eventType: _getEventTypeName(event),
                        gradeColor: _getGradeColor(event.grade),
                        isActive: isActive,
                        isPast: isPast,
                        hasZoom: event.viewTransform != null,
                        onTap: () => widget.onEventTap(event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompactEventRow extends StatelessWidget {
  final String timestamp;
  final String category;
  final String eventType;
  final Color gradeColor;
  final bool isActive;
  final bool isPast;
  final bool hasZoom;
  final VoidCallback onTap;

  const _CompactEventRow({
    required this.timestamp,
    required this.category,
    required this.eventType,
    required this.gradeColor,
    required this.isActive,
    required this.isPast,
    required this.hasZoom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF753b8f).withOpacity(0.35)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isActive ? const Color(0xFF9b5fb8) : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: Colors.white.withOpacity(0.04),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Grade dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: gradeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp
            SizedBox(
              width: 52,
              child: Text(
                timestamp,
                style: TextStyle(
                  color: isPast
                      ? Colors.white.withOpacity(0.5)
                      : Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Category
            SizedBox(
              width: 80,
              child: Text(
                category,
                style: TextStyle(
                  color: isPast
                      ? Colors.white.withOpacity(0.4)
                      : Colors.white.withOpacity(0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),

            // Event type
            Expanded(
              child: Text(
                eventType,
                style: TextStyle(
                  color: isPast
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Zoom indicator
            if (hasZoom)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.zoom_in,
                  size: 12,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
