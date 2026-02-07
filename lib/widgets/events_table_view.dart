import 'package:flutter/material.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../controllers/events_controller.dart';

class EventsTableView extends StatefulWidget {
  final EventsController controller;
  final SportTaxonomy taxonomy;
  final Function(GameEvent) onEventTap;
  final VoidCallback onClose;

  const EventsTableView({
    required this.controller,
    required this.taxonomy,
    required this.onEventTap,
    required this.onClose,
    super.key,
  });

  @override
  State<EventsTableView> createState() => _EventsTableViewState();
}

class _EventsTableViewState extends State<EventsTableView> {
  final Set<String> _selectedEventIds = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {
        // Clear selection if filtered events changed
        _selectedEventIds.removeWhere(
          (id) => !widget.controller.filteredEvents.any((e) => e.id == id),
        );
      });
    }
  }

  bool get _isAllSelected {
    final events = widget.controller.filteredEvents;
    return events.isNotEmpty && _selectedEventIds.length == events.length;
  }

  void _toggleSelectAll() {
    setState(() {
      if (_isAllSelected) {
        _selectedEventIds.clear();
      } else {
        _selectedEventIds.clear();
        _selectedEventIds.addAll(
          widget.controller.filteredEvents.map((e) => e.id),
        );
      }
    });
  }

  void _toggleEventSelection(String eventId) {
    setState(() {
      if (_selectedEventIds.contains(eventId)) {
        _selectedEventIds.remove(eventId);
      } else {
        _selectedEventIds.add(eventId);
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  String _getCategoryName(String categoryId) {
    final category = widget.taxonomy.getCategoryById(categoryId);
    return category?.name ?? categoryId;
  }

  String _getEventTypeName(GameEvent event) {
    if (event.eventTypeId != null) {
      final eventType = widget.taxonomy.getEventTypeById(event.eventTypeId!);
      if (eventType != null) {
        return eventType.name;
      }
    }
    // Fallback to detail if available, otherwise label
    return event.detail ?? event.label;
  }

  String _getImpactName(EventGrade? grade) {
    if (grade == null) return 'Neutral';
    return switch (grade) {
      EventGrade.positive => 'Positive',
      EventGrade.negative => 'Negative',
      EventGrade.neutral => 'Neutral',
    };
  }

  Color _getImpactColor(EventGrade? grade) {
    if (grade == null) return Colors.grey;
    return switch (grade) {
      EventGrade.positive => Colors.green,
      EventGrade.negative => Colors.red,
      EventGrade.neutral => Colors.grey,
    };
  }

  void _showCategoryFilter() {
    // Get unique category IDs from actual events
    final usedCategoryIds = widget.controller.allEvents
        .map((e) => e.categoryId)
        .toSet();
    
    // Build list of categories that are actually used
    final availableCategories = <MapEntry<String, String>>[];
    for (final categoryId in usedCategoryIds) {
      final category = widget.taxonomy.getCategoryById(categoryId);
      if (category != null) {
        availableCategories.add(MapEntry(category.categoryId, category.name));
      }
    }
    
    // Sort by name for better UX
    availableCategories.sort((a, b) => a.value.compareTo(b.value));

    _showColumnFilter(
      title: 'Filter by Category',
      availableValues: availableCategories,
      currentSelection: widget.controller.filter.categoryIds,
      onApply: (selected) {
        final newFilter = widget.controller.filter.copyWith(
          categoryIds: selected.isEmpty ? null : selected,
        );
        widget.controller.setFilter(newFilter);
      },
    );
  }

  void _showEventTypeFilter() {
    // Get unique event identifiers from actual events
    final availableEventTypes = <MapEntry<String, String>>[];
    final seenKeys = <String>{};
    
    for (final event in widget.controller.allEvents) {
      String key;
      String displayName;
      
      if (event.eventTypeId != null) {
        // Use taxonomy-based event type
        key = event.eventTypeId!;
        final eventType = widget.taxonomy.getEventTypeById(key);
        displayName = eventType?.name ?? key;
      } else {
        // Use label/detail as identifier for events without eventTypeId
        key = event.detail ?? event.label;
        displayName = key;
      }
      
      if (!seenKeys.contains(key)) {
        seenKeys.add(key);
        availableEventTypes.add(MapEntry(key, displayName));
      }
    }
    
    // Sort by name for better UX
    availableEventTypes.sort((a, b) => a.value.compareTo(b.value));

    _showColumnFilter(
      title: 'Filter by Event',
      availableValues: availableEventTypes,
      currentSelection: widget.controller.filter.eventTypeIds,
      onApply: (selected) {
        final newFilter = widget.controller.filter.copyWith(
          eventTypeIds: selected.isEmpty ? null : selected,
        );
        widget.controller.setFilter(newFilter);
      },
    );
  }

  void _showImpactFilter() {
    // Get unique grades from actual events
    final usedGrades = widget.controller.allEvents
        .where((e) => e.grade != null)
        .map((e) => e.grade!)
        .toSet();
    
    // Build list of impacts that are actually used
    final availableImpacts = <MapEntry<String, String>>[];
    for (final grade in usedGrades) {
      final name = switch (grade) {
        EventGrade.positive => 'Positive',
        EventGrade.negative => 'Negative',
        EventGrade.neutral => 'Neutral',
      };
      availableImpacts.add(MapEntry(grade.name, name));
    }
    
    // Sort by name for better UX
    availableImpacts.sort((a, b) => a.value.compareTo(b.value));

    _showColumnFilter(
      title: 'Filter by Impact',
      availableValues: availableImpacts,
      currentSelection: widget.controller.filter.impacts?.map((g) => g.name).toSet(),
      onApply: (selected) {
        final grades = selected.isEmpty
            ? null
            : selected
                .map((name) => EventGrade.values.firstWhere((g) => g.name == name))
                .toSet();
        final newFilter = widget.controller.filter.copyWith(
          impacts: grades,
        );
        widget.controller.setFilter(newFilter);
      },
    );
  }

  void _showColumnFilter({
    required String title,
    required List<MapEntry<String, String>> availableValues,
    required Set<String>? currentSelection,
    required Function(Set<String>) onApply,
  }) {
    showDialog(
      context: context,
      builder: (context) => _ColumnFilterDialog(
        title: title,
        availableValues: availableValues,
        currentSelection: currentSelection ?? {},
        onApply: onApply,
      ),
    );
  }

  void _confirmDelete(GameEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text(
          'Are you sure you want to delete this event?\n\n'
          '${_getCategoryName(event.categoryId)} - ${_getEventTypeName(event)} at ${_formatDuration(event.timestamp)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.controller.deleteEvent(event);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Event deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete() {
    final selectedEvents = widget.controller.filteredEvents
        .where((e) => _selectedEventIds.contains(e.id))
        .toList();

    if (selectedEvents.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${selectedEvents.length} Events'),
        content: Text(
          'Are you sure you want to delete ${selectedEvents.length} selected event(s)?\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete all selected events
              for (final event in selectedEvents) {
                widget.controller.deleteEvent(event);
              }
              setState(() {
                _selectedEventIds.clear();
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${selectedEvents.length} event(s) deleted'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    final events = widget.controller.filteredEvents;

    final content = Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF753b8f),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text(
                'Events',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_selectedEventIds.isNotEmpty)
                TextButton.icon(
                  onPressed: _confirmBulkDelete,
                  icon: const Icon(Icons.delete, color: Colors.white70, size: 18),
                  label: Text(
                    'Delete Selected (${_selectedEventIds.length})',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                  ),
                ),
              const SizedBox(width: 16),
              Text(
                'Showing ${events.length} / ${widget.controller.totalEventCount}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 16),
              if (widget.controller.filter.isActive)
                TextButton.icon(
                  onPressed: () => widget.controller.clearFilter(),
                  icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                  label: const Text(
                    'Clear Filters',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              IconButton(
                onPressed: widget.onClose,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border(bottom: BorderSide(color: Colors.grey[400]!)),
          ),
          child: Row(
            children: [
              // Select all checkbox
              SizedBox(
                width: 48,
                child: Checkbox(
                  value: _isAllSelected,
                  tristate: true,
                  onChanged: (_) => _toggleSelectAll(),
                ),
              ),
              _buildHeaderCell('Time', flex: 2),
              _buildHeaderCell(
                'Category',
                flex: 3,
                hasFilter: true,
                isFiltered: widget.controller.filter.categoryIds != null,
                onFilterTap: _showCategoryFilter,
              ),
              _buildHeaderCell(
                'Event',
                flex: 3,
                hasFilter: true,
                isFiltered: widget.controller.filter.eventTypeIds != null,
                onFilterTap: _showEventTypeFilter,
              ),
              _buildHeaderCell(
                'Impact',
                flex: 2,
                hasFilter: true,
                isFiltered: widget.controller.filter.impacts != null,
                onFilterTap: _showImpactFilter,
              ),
              _buildHeaderCell('', flex: 1), // Delete column
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: events.isEmpty
              ? Center(
                  child: Text(
                    widget.controller.filter.isActive
                        ? 'No events match the current filters'
                        : 'No events yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                )
              : ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  itemBuilder: (context, index) {
                    final event = events[index];
                    return InkWell(
                      onTap: () => widget.onEventTap(event),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Selection checkbox
                            SizedBox(
                              width: 48,
                              child: Checkbox(
                                value: _selectedEventIds.contains(event.id),
                                onChanged: (_) => _toggleEventSelection(event.id),
                              ),
                            ),
                            _buildDataCell(
                              _formatDuration(event.timestamp),
                              flex: 2,
                            ),
                            _buildDataCell(
                              _getCategoryName(event.categoryId),
                              flex: 3,
                            ),
                            _buildDataCell(
                              _getEventTypeName(event),
                              flex: 3,
                            ),
                            _buildDataCell(
                              _getImpactName(event.grade),
                              flex: 2,
                              color: _getImpactColor(event.grade),
                            ),
                            // Delete button
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                  color: Colors.red[400],
                                  tooltip: 'Delete event',
                                  onPressed: () => _confirmDelete(event),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    if (isDesktop) {
      return Dialog(
        child: Container(
          width: 800,
          height: 600,
          child: content,
        ),
      );
    } else {
      return Scaffold(
        body: SafeArea(child: content),
      );
    }
  }

  Widget _buildHeaderCell(
    String label, {
    required int flex,
    bool hasFilter = false,
    bool isFiltered = false,
    VoidCallback? onFilterTap,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            if (hasFilter)
              InkWell(
                onTap: onFilterTap,
                child: Icon(
                  isFiltered ? Icons.filter_alt : Icons.filter_alt_outlined,
                  size: 18,
                  color: isFiltered ? const Color(0xFF753b8f) : Colors.grey[600],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, Color? color}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: color ?? Colors.black87,
            fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _ColumnFilterDialog extends StatefulWidget {
  final String title;
  final List<MapEntry<String, String>> availableValues;
  final Set<String> currentSelection;
  final Function(Set<String>) onApply;

  const _ColumnFilterDialog({
    required this.title,
    required this.availableValues,
    required this.currentSelection,
    required this.onApply,
  });

  @override
  State<_ColumnFilterDialog> createState() => _ColumnFilterDialogState();
}

class _ColumnFilterDialogState extends State<_ColumnFilterDialog> {
  late Set<String> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set.from(widget.currentSelection);
  }

  bool get _isAllSelected =>
      _selection.length == widget.availableValues.length;

  void _toggleAll() {
    setState(() {
      if (_isAllSelected) {
        _selection.clear();
      } else {
        _selection = widget.availableValues.map((e) => e.key).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text(
                'Select All',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _isAllSelected,
              onChanged: (_) => _toggleAll(),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Divider(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: widget.availableValues.map((entry) {
                  return CheckboxListTile(
                    title: Text(entry.value),
                    value: _selection.contains(entry.key),
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          _selection.add(entry.key);
                        } else {
                          _selection.remove(entry.key);
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() => _selection.clear());
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(_selection);
            Navigator.of(context).pop();
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
