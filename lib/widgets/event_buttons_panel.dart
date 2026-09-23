import 'package:flutter/material.dart';
import '../models/sport_taxonomy.dart';
import '../models/dock_layout_state.dart';
import '../controllers/event_entry_controller.dart';
import 'event_entry_pager.dart';

class EventButtonsPanel extends StatefulWidget {
  final Function(String categoryId) onEventTriggered;
  final SportTaxonomy? taxonomy;
  final bool showNumbers;
  final int entryPage;
  final ValueChanged<int>? onEntryPageChanged;
  final PanelDockEdge dockEdge;

  const EventButtonsPanel({
    required this.onEventTriggered,
    this.taxonomy,
    this.showNumbers = false,
    this.entryPage = 0,
    this.onEntryPageChanged,
    this.dockEdge = PanelDockEdge.floating,
    super.key,
  });

  @override
  State<EventButtonsPanel> createState() => _EventButtonsPanelState();
}

class _EventButtonsPanelState extends State<EventButtonsPanel> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final taxonomy = widget.taxonomy;
    final dockEdge = widget.dockEdge;
    final showNumbers = widget.showNumbers;
    final onEventTriggered = widget.onEventTriggered;
    if (taxonomy == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Loading categories...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    final vertical =
        dockEdge == PanelDockEdge.left || dockEdge == PanelDockEdge.right;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final all = taxonomy.captureCategories;
          final choices = showNumbers
              ? all
                    .skip(widget.entryPage * EventEntryController.pageSize)
                    .take(EventEntryController.pageSize)
                    .toList()
              : all.where((c) => c.matches(_query)).toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!showNumbers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Find event category',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in choices.asMap().entries)
                    SizedBox(
                      width: vertical ? constraints.maxWidth : 132,
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            onEventTriggered(entry.value.categoryId),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 56),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: Icon(
                          entry.value.getIcon(),
                          size: 22,
                          color: entry.value.getColor(),
                        ),
                        label: Text(
                          '${showNumbers ? '${entry.key + 1}. ' : ''}${entry.value.name}',
                        ),
                      ),
                    ),
                ],
              ),
              if (showNumbers)
                EventEntryPager(
                  page: widget.entryPage,
                  count: all.length,
                  onChanged: widget.onEntryPageChanged,
                ),
            ],
          );
        },
      ),
    );
  }
}
