import 'package:flutter/material.dart';
import '../models/sport_taxonomy.dart';
import '../models/dock_layout_state.dart';
import '../controllers/event_entry_controller.dart';
import 'tool_action_grid.dart';

class EventButtonsPanel extends StatelessWidget {
  final Function(String categoryId) onEventTriggered;
  final SportTaxonomy? taxonomy;
  final bool showNumbers;
  final int entryPage;
  final ValueChanged<int>? onEntryPageChanged;
  final PanelDockEdge dockEdge;
  final TextEditingController? searchController;

  const EventButtonsPanel({
    required this.onEventTriggered,
    this.taxonomy,
    this.showNumbers = false,
    this.entryPage = 0,
    this.onEntryPageChanged,
    this.dockEdge = PanelDockEdge.floating,
    this.searchController,
    super.key,
  });

  static String _label(
    CategoryTaxonomy category,
    int index,
    bool numbered,
    int page,
  ) {
    final number = index - page * EventEntryController.pageSize;
    return '${numbered && number >= 0 && number < EventEntryController.pageSize ? '${number + 1}. ' : ''}${category.name}';
  }

  static ToolsetLayout layoutFor(
    SportTaxonomy? taxonomy, {
    bool showNumbers = false,
    int page = 0,
  }) => ToolsetLayout.actions(
    [
      for (final entry
          in (taxonomy?.captureCategories ?? <CategoryTaxonomy>[])
              .asMap()
              .entries)
        _label(entry.value, entry.key, showNumbers, page),
      showNumbers ? 'Shortcuts' : 'Find',
    ],
    tileWidth: 72,
    minimumTileWidth: 64,
  );

  void _search(BuildContext context) {
    final controller = searchController ?? TextEditingController();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Find event category'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Find event category',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              Flexible(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final category in taxonomy!.captureCategories)
                          if (category.matches(value.text.trim()))
                            ListTile(
                              leading: Icon(
                                category.getIcon(),
                                color: category.getColor(),
                              ),
                              title: Text(category.name),
                              onTap: () {
                                Navigator.pop(context);
                                onEventTriggered(category.categoryId);
                              },
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    ).whenComplete(() {
      if (searchController == null) controller.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (taxonomy == null) {
      return const Center(child: Text('Loading categories...'));
    }
    final all = taxonomy!.captureCategories;
    final layout = layoutFor(
      taxonomy,
      showNumbers: showNumbers,
      page: entryPage,
    );
    return ToolActionGrid(
      title: 'Categories',
      layout: layout,
      children: [
        for (final entry in all.asMap().entries)
          ToolActionButton(
            key: ValueKey('category-${entry.value.categoryId}'),
            dismissPalette: true,
            label: layout.labels![entry.key],
            icon: entry.value.getIcon(),
            color: entry.value.getColor(),
            onPressed: () => onEventTriggered(entry.value.categoryId),
          ),
        if (showNumbers)
          ToolActionButton(
            label: 'Shortcuts',
            icon: Icons.keyboard,
            tooltip:
                'Next shortcut page (${entryPage + 1}/${(all.length / EventEntryController.pageSize).ceil()})',
            onPressed: onEntryPageChanged == null
                ? null
                : () => onEntryPageChanged!(
                    (entryPage + 1) %
                        (all.length / EventEntryController.pageSize).ceil(),
                  ),
          )
        else
          ToolActionButton(
            label: 'Find',
            dismissPalette: true,
            tooltip: 'Find event category',
            icon: Icons.search,
            onPressed: () => _search(context),
          ),
      ],
    );
  }
}
