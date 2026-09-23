import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controllers/event_entry_controller.dart';
import '../controllers/events_controller.dart';
import '../controllers/quick_events_controller.dart';
import '../models/dock_layout_state.dart';
import '../models/game_event.dart';
import '../models/quick_event.dart';
import '../models/sport_taxonomy.dart';
import 'event_buttons_panel.dart';
import 'smart_hud.dart';

/// Shared by the persistent Categories tool and temporary event entry.
class EventEntrySurface extends StatelessWidget {
  const EventEntrySurface({
    super.key,
    required this.events,
    required this.entry,
    required this.quickEvents,
    required this.taxonomy,
    required this.dockEdge,
    required this.onCategory,
    required this.onUpdate,
    required this.onDelete,
    required this.onSave,
    required this.onCancel,
    this.categoriesOnly = false,
  });

  final EventsController events;
  final EventEntryController entry;
  final QuickEventsController quickEvents;
  final SportTaxonomy taxonomy;
  final PanelDockEdge dockEdge;
  final ValueChanged<String> onCategory;
  final ValueChanged<GameEvent> onUpdate;
  final ValueChanged<GameEvent> onDelete;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool categoriesOnly;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([events, entry, quickEvents]),
    builder: (context, _) {
      final event = categoriesOnly ? null : entry.draft;
      if (event == null) {
        return EventButtonsPanel(
          taxonomy: taxonomy,
          dockEdge: dockEdge,
          showNumbers: entry.showCategoryNumbers,
          entryPage: entry.page,
          searchController: entry.categorySearch,
          onEntryPageChanged: (page) =>
              entry.setPage(page, taxonomy.captureCategories.length),
          onEventTriggered: onCategory,
        );
      }
      final inQuickMenu = quickEvents.items.any(
        (item) =>
            item.categoryId == event.categoryId &&
            item.eventTypeId == event.eventTypeId &&
            item.grade == event.grade &&
            mapEquals(item.context, event.context),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SmartHUD(
            key: ValueKey(event.id),
            event: event,
            taxonomy: taxonomy,
            onUpdateEvent: onUpdate,
            onDeleteEvent: onDelete,
            onSave: onSave,
            onDismiss: onCancel,
            isAltPressed: entry.isEntryActive,
            showTagNumbers: entry.showLabelNumbers,
            showGradeNumbers: entry.showGradeNumbers,
            entryPage: entry.page,
            onEntryPageChanged: (page) => entry.setPage(
              page,
              taxonomy
                      .getCategoryById(event.categoryId)
                      ?.captureEventTypes
                      .length ??
                  0,
            ),
          ),
          if (event.eventTypeId != null)
            TextButton.icon(
              icon: const Icon(Icons.playlist_add),
              label: Text(inQuickMenu ? 'In quick menu' : 'Add to quick menu'),
              onPressed: inQuickMenu
                  ? null
                  : () => quickEvents.add(
                      QuickEvent(
                        categoryId: event.categoryId,
                        eventTypeId: event.eventTypeId!,
                        grade: event.grade,
                        context: event.context,
                        slotId:
                            'quick-${DateTime.now().microsecondsSinceEpoch}',
                        taxonomyRevision: event.taxonomyRevision,
                        categoryLabel: event.label,
                        eventLabel: event.detail,
                        definition: event.definition,
                      ),
                    ),
            ),
        ],
      );
    },
  );
}
