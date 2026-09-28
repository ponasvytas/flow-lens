import 'package:flutter/material.dart';
import '../controllers/events_controller.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../theme/flow_theme.dart';

/// Compact events table designed to be docked beside the video player.
///
/// Shows a scrollable list of events with minimal columns:
/// category icon, timestamp, event hierarchy, and grade.
/// The active event is highlighted and auto-scrolled into view.
class DockedEventsPanel extends StatefulWidget {
  final EventsController controller;
  final SportTaxonomy? taxonomy;
  final Function(GameEvent) onEventTap;
  final VoidCallback onClose;
  final Duration currentPosition;
  final bool showHeader;

  const DockedEventsPanel({
    required this.controller,
    required this.taxonomy,
    required this.onEventTap,
    required this.onClose,
    required this.currentPosition,
    this.showHeader = true,
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

  double get _rowHeight =>
      16 + 40 * MediaQuery.textScalerOf(context).scale(14) / 14;

  void _scrollToEvent(GameEvent event) {
    final events = widget.controller.chronologicalFilteredEvents;
    final index = events.indexWhere((e) => e.id == event.id);
    if (index == -1 || !_scrollController.hasClients) return;

    final itemHeight = _rowHeight;
    final targetOffset = index * itemHeight;
    final viewportHeight = _scrollController.position.viewportDimension;
    final currentOffset = _scrollController.offset;

    // Only scroll if the item is outside the visible area
    if (targetOffset < currentOffset ||
        targetOffset > currentOffset + viewportHeight - itemHeight) {
      _scrollController.animateTo(
        (targetOffset - viewportHeight / 2 + itemHeight / 2).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
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

  String _getEventTypeName(GameEvent event) {
    if (event.detail != null) return event.detail!;
    if (event.eventTypeId != null && widget.taxonomy != null) {
      final eventType = widget.taxonomy!.getEventTypeById(event.eventTypeId!);
      if (eventType != null) return eventType.name;
    }
    return event.detail ?? event.label;
  }

  Color _getGradeColor(EventGrade? grade) {
    return switch (grade) {
      EventGrade.positive => FlowTheme.positive,
      EventGrade.negative => FlowTheme.negative,
      EventGrade.neutral => FlowTheme.neutral,
      null => FlowTheme.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final events = widget.controller.chronologicalFilteredEvents;
    final activeId = widget.controller.activeEvent?.id;

    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: FlowTheme.panel,
        border: Border(left: BorderSide(color: FlowTheme.border, width: 1)),
      ),
      child: Column(
        children: [
          // Header
          if (widget.showHeader)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: FlowTheme.panel,
                border: Border(bottom: BorderSide(color: FlowTheme.border)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.view_sidebar_outlined,
                    color: FlowTheme.accent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Events',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${events.length}',
                    style: TextStyle(color: FlowTheme.muted, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Close events list',
                    icon: const Icon(Icons.close, size: 20),
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
                      style: TextStyle(color: FlowTheme.muted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: events.length,
                    itemExtent: _rowHeight,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final isActive = event.id == activeId;
                      final isPast = event.timestamp <= widget.currentPosition;

                      return _CompactEventRow(
                        timestamp: _formatDuration(event.timestamp),
                        category: event.label,
                        eventType: _getEventTypeName(event),
                        categoryIcon:
                            widget.taxonomy
                                ?.getCategoryById(event.categoryId)
                                ?.getIcon() ??
                            Icons.label_outline,
                        categoryColor:
                            widget.taxonomy
                                ?.getCategoryById(event.categoryId)
                                ?.getColor() ??
                            FlowTheme.muted,
                        grade: event.grade,
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
  final IconData categoryIcon;
  final Color categoryColor;
  final EventGrade? grade;
  final Color gradeColor;
  final bool isActive;
  final bool isPast;
  final bool hasZoom;
  final VoidCallback onTap;

  const _CompactEventRow({
    required this.timestamp,
    required this.category,
    required this.eventType,
    required this.categoryIcon,
    required this.categoryColor,
    required this.grade,
    required this.gradeColor,
    required this.isActive,
    required this.isPast,
    required this.hasZoom,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradeLabel = switch (grade) {
      EventGrade.positive => 'Positive',
      EventGrade.negative => 'Negative',
      EventGrade.neutral => 'Neutral',
      null => 'Ungraded',
    };
    return Semantics(
      selected: isActive,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? FlowTheme.accent.withValues(alpha: 0.12) : null,
            border: Border(
              left: BorderSide(
                color: isActive ? FlowTheme.accent : Colors.transparent,
                width: 3,
              ),
              bottom: const BorderSide(color: FlowTheme.border),
            ),
          ),
          child: Row(
            children: [
              Icon(categoryIcon, color: categoryColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: '$category ? $eventType',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlowTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        eventType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timestamp,
                style: TextStyle(
                  color: isActive
                      ? FlowTheme.accent
                      : isPast
                      ? FlowTheme.muted
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: gradeLabel,
                child: Icon(
                  switch (grade) {
                    EventGrade.positive => Icons.thumb_up,
                    EventGrade.negative => Icons.thumb_down,
                    EventGrade.neutral => Icons.remove,
                    null => Icons.radio_button_unchecked,
                  },
                  color: gradeColor,
                  size: 16,
                  semanticLabel: gradeLabel,
                ),
              ),
              if (hasZoom)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Tooltip(
                    message: 'Saved zoom',
                    child: Icon(
                      Icons.zoom_in,
                      size: 16,
                      color: FlowTheme.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
