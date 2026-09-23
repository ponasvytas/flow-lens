import 'package:flutter/material.dart';
import '../controllers/quick_events_controller.dart';
import '../models/quick_event.dart';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../theme/flow_theme.dart';
import 'event_context_editor.dart';
import 'package:flutter/foundation.dart' show mapEquals;

String quickEventLabel(QuickEvent item, SportTaxonomy taxonomy) {
  final category = taxonomy.getCategoryById(item.categoryId);
  final type = category?.eventTypes
      .where((e) => e.eventTypeId == item.eventTypeId)
      .firstOrNull;
  return type == null
      ? 'Unavailable event'
      : '${item.categoryLabel ?? category!.name} ${item.eventLabel ?? type.name}';
}

class QuickEventsPanel extends StatelessWidget {
  const QuickEventsPanel({
    super.key,
    required this.controller,
    required this.taxonomy,
    required this.onRecord,
    required this.onAllEvents,
    this.vertical = true,
    this.feedback,
  });
  final QuickEventsController controller;
  final SportTaxonomy taxonomy;
  final ValueChanged<QuickEvent> onRecord;
  final VoidCallback onAllEvents;
  final bool vertical;
  final Widget? feedback;

  void _openEditor(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) =>
        QuickEventsEditor(controller: controller, taxonomy: taxonomy),
  );

  Widget _button(QuickEvent item) {
    final category = taxonomy.getCategoryById(item.categoryId);
    final available = category?.getEventTypeById(item.eventTypeId) != null;
    return OutlinedButton(
      key: ValueKey('quick-${item.id}'),
      onPressed: available ? () => onRecord(item) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 72),
        backgroundColor: FlowTheme.raised,
        padding: const EdgeInsets.all(12),
      ),
      child: Row(
        children: [
          Icon(
            category?.getIcon() ?? Icons.help_outline,
            color: available ? category?.getColor() : FlowTheme.muted,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quickEventLabel(item, taxonomy)),
                const SizedBox(height: 4),
                _GradeLabel(grade: item.grade),
              ],
            ),
          ),
          if (item.hotkey != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                item.hotkey!.toUpperCase(),
                style: const TextStyle(color: FlowTheme.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Padding(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final error = controller.error == null
              ? null
              : TextButton.icon(
                  onPressed: controller.ready
                      ? controller.retrySave
                      : controller.load,
                  icon: const Icon(Icons.refresh),
                  label: Text(controller.error!),
                );
          const empty = Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Choose the moments you want to track.',
              style: TextStyle(color: FlowTheme.muted),
            ),
          );
          if (!vertical) {
            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ?error,
                Row(
                  children: [
                    Expanded(
                      child: controller.items.isEmpty
                          ? empty
                          : _HorizontalQuickEvents(
                              child: Row(
                                children: [
                                  for (final item in controller.items)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: SizedBox(
                                        width:
                                            200 *
                                            MediaQuery.textScalerOf(
                                              context,
                                            ).scale(14) /
                                            14,
                                        child: _button(item),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Edit quick menu',
                      onPressed: controller.ready
                          ? () => _openEditor(context)
                          : null,
                      icon: const Icon(Icons.tune),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'All events',
                      onPressed: onAllEvents,
                      icon: const Icon(Icons.apps),
                    ),
                  ],
                ),
                ?feedback,
              ],
            );
            return SingleChildScrollView(child: content);
          }
          final choices = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?error,
              if (controller.items.isEmpty) empty,
              for (final item in controller.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _button(item),
                ),
            ],
          );
          final footer = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              ?feedback,
              OutlinedButton.icon(
                onPressed: controller.ready ? () => _openEditor(context) : null,
                icon: const Icon(Icons.tune, size: 20),
                label: const Text('Edit quick menu'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: onAllEvents,
                icon: const Icon(Icons.apps, size: 20),
                label: const Text('All events'),
              ),
            ],
          );
          if (constraints.hasBoundedHeight && constraints.maxHeight >= 200) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: SingleChildScrollView(child: choices)),
                footer,
              ],
            );
          }
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [choices, footer],
          );
          return constraints.hasBoundedHeight
              ? SingleChildScrollView(child: content)
              : content;
        },
      ),
    ),
  );
}

class _HorizontalQuickEvents extends StatefulWidget {
  const _HorizontalQuickEvents({required this.child});
  final Widget child;

  @override
  State<_HorizontalQuickEvents> createState() => _HorizontalQuickEventsState();
}

class _HorizontalQuickEventsState extends State<_HorizontalQuickEvents> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scrollController,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 12),
      child: widget.child,
    ),
  );
}

class _GradeLabel extends StatelessWidget {
  const _GradeLabel({required this.grade});
  final EventGrade? grade;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (grade) {
      EventGrade.positive => ('Positive', Icons.thumb_up, Colors.greenAccent),
      EventGrade.neutral => ('Neutral', Icons.remove, FlowTheme.muted),
      EventGrade.negative => ('Negative', Icons.thumb_down, Colors.redAccent),
      null => ('Ungraded', Icons.radio_button_unchecked, FlowTheme.muted),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(label, style: TextStyle(color: color, fontSize: 12)),
        ),
      ],
    );
  }
}

class _QuickEventPicker extends StatefulWidget {
  const _QuickEventPicker({required this.taxonomy, required this.existing});
  final SportTaxonomy taxonomy;
  final List<QuickEvent> existing;

  @override
  State<_QuickEventPicker> createState() => _QuickEventPickerState();
}

class _QuickEventPickerState extends State<_QuickEventPicker> {
  CategoryTaxonomy? _category;
  EventTypeTaxonomy? _type;
  EventGrade? _grade;
  String _query = '';
  Map<String, String> _context = {};

  void _back() => setState(() {
    if (_type != null) {
      _type = null;
      _grade = null;
    } else {
      _category = null;
    }
    _query = '';
  });

  @override
  Widget build(BuildContext context) {
    final category = _category;
    final type = _type;
    return AlertDialog(
      title: Text(
        type != null
            ? '3. Choose grade'
            : category != null
            ? '2. Choose sub-event'
            : '1. Choose main event',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (category != null) ...[
                Row(
                  children: [
                    Icon(category.getIcon(), color: category.getColor()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        type == null
                            ? category.name
                            : '${category.name} › ${type.name}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (type == null) ...[
                TextField(
                  key: ValueKey(category?.categoryId),
                  decoration: InputDecoration(
                    labelText: category == null
                        ? 'Find main event'
                        : 'Find sub-event',
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                if (category == null)
                  for (final choice in widget.taxonomy.captureCategories)
                    if (choice.matches(_query))
                      ListTile(
                        leading: Icon(
                          choice.getIcon(),
                          color: choice.getColor(),
                        ),
                        title: Text(choice.name),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => setState(() {
                          _category = choice;
                          _query = '';
                        }),
                      ),
                if (category != null)
                  for (final choice in category.captureEventTypes)
                    if (choice.matches(_query))
                      Builder(
                        builder: (context) {
                          return ListTile(
                            title: Text(choice.name),
                            subtitle: Text(choice.definition),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() {
                              _type = choice;
                              _grade = choice.defaultImpact;
                              _context = Map.of(choice.contextDefaults);
                            }),
                          );
                        },
                      ),
                if (category == null
                    ? !widget.taxonomy.captureCategories.any(
                        (c) => c.matches(_query),
                      )
                    : !category.captureEventTypes.any((t) => t.matches(_query)))
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No matching events.'),
                  ),
              ] else ...[
                const Text('Choose the grade to record with each tap.'),
                const SizedBox(height: 12),
                for (final grade in <EventGrade?>[
                  null,
                  EventGrade.positive,
                  EventGrade.neutral,
                  EventGrade.negative,
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _grade = grade),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _grade == grade
                            ? FlowTheme.raised
                            : null,
                        side: BorderSide(
                          color: _grade == grade
                              ? FlowTheme.accent
                              : FlowTheme.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _GradeLabel(grade: grade)),
                          if (_grade == grade)
                            const Icon(Icons.check, size: 18),
                        ],
                      ),
                    ),
                  ),
                EventContextEditor(
                  taxonomy: widget.taxonomy,
                  categoryId: category!.categoryId,
                  values: _context,
                  onChanged: (values) => setState(() => _context = values),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (category != null)
          TextButton(onPressed: _back, child: const Text('Back')),
        if (category != null && type != null)
          FilledButton(
            onPressed:
                widget.existing.any(
                  (item) =>
                      item.categoryId == category.categoryId &&
                      item.eventTypeId == type.eventTypeId &&
                      item.grade == _grade &&
                      mapEquals(item.context, _context),
                )
                ? null
                : () => Navigator.pop(
                    context,
                    QuickEvent(
                      categoryId: category.categoryId,
                      eventTypeId: type.eventTypeId,
                      grade: _grade,
                      slotId: 'quick-${DateTime.now().microsecondsSinceEpoch}',
                      taxonomyRevision: widget.taxonomy.revision,
                      categoryLabel: category.name,
                      eventLabel: type.name,
                      definition: type.definition,
                      context: _context,
                    ),
                  ),
            child: const Text('Add to quick menu'),
          ),
      ],
    );
  }
}

class QuickEventsEditor extends StatefulWidget {
  const QuickEventsEditor({
    super.key,
    required this.controller,
    required this.taxonomy,
  });
  final QuickEventsController controller;
  final SportTaxonomy taxonomy;
  @override
  State<QuickEventsEditor> createState() => _QuickEventsEditorState();
}

class _QuickEventsEditorState extends State<QuickEventsEditor> {
  List<QuickEvent>? _undo;
  Future<void> _add() async {
    final item = await showDialog<QuickEvent>(
      context: context,
      builder: (_) => _QuickEventPicker(
        taxonomy: widget.taxonomy,
        existing: widget.controller.items,
      ),
    );
    if (!mounted || item == null) return;
    _undo = widget.controller.items;
    widget.controller.add(item);
  }

  Future<String?> _name(String title, String initial) async {
    final text = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: text,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Preset name'),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) Navigator.pop(context, value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (text.text.trim().isNotEmpty) {
                Navigator.pop(context, text.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    // Dialog route transitions may still be using its field for this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => text.dispose());
    return result;
  }

  Future<void> _edit(QuickEvent item) async {
    final keyController = TextEditingController(text: item.hotkey ?? '');
    var grade = item.grade;
    var contextValues = item.context;
    String? error;
    final result = await showDialog<QuickEvent>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(quickEventLabel(item, widget.taxonomy)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: grade?.name ?? 'ungraded',
                  decoration: const InputDecoration(
                    labelText: 'Grade for quick capture',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'ungraded',
                      child: _GradeLabel(grade: null),
                    ),
                    for (final g in EventGrade.values)
                      DropdownMenuItem(
                        value: g.name,
                        child: _GradeLabel(grade: g),
                      ),
                  ],
                  onChanged: (value) => setLocalState(
                    () => grade = value == 'ungraded'
                        ? null
                        : EventGrade.values.byName(value!),
                  ),
                ),
                EventContextEditor(
                  taxonomy: widget.taxonomy,
                  categoryId: item.categoryId,
                  values: contextValues,
                  onChanged: (values) =>
                      setLocalState(() => contextValues = values),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: keyController,
                  maxLength: 1,
                  decoration: InputDecoration(
                    labelText: 'Keyboard shortcut',
                    helperText: 'One letter, or leave empty to clear.',
                    errorText: error,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final key = keyController.text.trim().toLowerCase();
                final message = widget.controller.hotkeyError(key, item.id);
                if (message != null) {
                  setLocalState(() => error = message);
                  return;
                }
                Navigator.pop(
                  context,
                  item.copyWith(
                    grade: grade,
                    clearGrade: grade == null,
                    context: contextValues,
                    hotkey: key,
                    clearHotkey: key.isEmpty,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => keyController.dispose(),
    );
    if (result != null) widget.controller.update(result);
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 760),
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final ctrl = widget.controller;
          final items = ctrl.items;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit quick menu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Done',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Changes apply to this game. Presets change only when you update them.',
                        style: TextStyle(color: FlowTheme.muted),
                      ),
                      if (ctrl.error != null)
                        TextButton(
                          onPressed: ctrl.retrySave,
                          child: Text(ctrl.error!),
                        ),
                      const SizedBox(height: 12),
                      if (_undo != null)
                        TextButton.icon(
                          onPressed: () {
                            ctrl.restoreItems(_undo!);
                            setState(() => _undo = null);
                          },
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo menu change'),
                        ),
                      FilledButton.tonalIcon(
                        onPressed: ctrl.ready ? _add : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add quick event'),
                      ),
                      const SizedBox(height: 8),
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: items.length,
                        onReorderItem: (oldIndex, newIndex) {
                          _undo = items;
                          ctrl.move(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            key: ValueKey(item.id),
                            color: FlowTheme.raised,
                            child: Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 12,
                                    right: 4,
                                  ),
                                  leading: Icon(
                                    widget.taxonomy
                                            .getCategoryById(item.categoryId)
                                            ?.getIcon() ??
                                        Icons.help_outline,
                                    color: widget.taxonomy
                                        .getCategoryById(item.categoryId)
                                        ?.getColor(),
                                  ),
                                  title: Text(
                                    quickEventLabel(item, widget.taxonomy),
                                  ),
                                  subtitle: Text(
                                    '${item.grade?.name ?? 'Ungraded'}${item.hotkey == null ? '' : ' · Key ${item.hotkey!.toUpperCase()}'}',
                                  ),
                                  onTap: () => _edit(item),
                                  trailing: ReorderableDragStartListener(
                                    index: index,
                                    child: const SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                ),
                                Wrap(
                                  children: [
                                    IconButton(
                                      onPressed: index == 0
                                          ? null
                                          : () {
                                              _undo = items;
                                              ctrl.move(index, index - 1);
                                            },
                                      tooltip: 'Move up',
                                      icon: const Icon(Icons.arrow_upward),
                                    ),
                                    IconButton(
                                      onPressed: index == items.length - 1
                                          ? null
                                          : () {
                                              _undo = items;
                                              ctrl.move(index, index + 1);
                                            },
                                      tooltip: 'Move down',
                                      icon: const Icon(Icons.arrow_downward),
                                    ),
                                    IconButton(
                                      onPressed: () => _edit(item),
                                      tooltip: 'Grade and hotkey',
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      onPressed: () {
                                        _undo = items;
                                        ctrl.remove(item.id);
                                      },
                                      tooltip: 'Remove from quick menu',
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text('Reusable presets'),
                        initiallyExpanded: items.isEmpty,
                        children: [
                          for (final preset in ctrl.suggestedPresets)
                            ListTile(
                              leading: const Icon(Icons.auto_awesome_outlined),
                              title: Text(preset.name),
                              subtitle: Text(
                                '${preset.items.length} events ? Suggested',
                              ),
                              onTap: () {
                                _undo = items;
                                ctrl.applyPreset(preset);
                              },
                            ),
                          for (final preset in ctrl.presets)
                            ListTile(
                              title: Text(preset.name),
                              subtitle: Text('${preset.items.length} events'),
                              onTap: () {
                                _undo = items;
                                ctrl.applyPreset(preset);
                              },
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Preset actions',
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'apply',
                                    child: Text('Apply to this game'),
                                  ),
                                  PopupMenuItem(
                                    value: 'update',
                                    child: Text('Update from this menu'),
                                  ),
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Text('Rename'),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Text('Duplicate'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete preset'),
                                  ),
                                ],
                                onSelected: (action) async {
                                  if (action == 'apply') {
                                    _undo = items;
                                    ctrl.applyPreset(preset);
                                  }
                                  if (action == 'update') {
                                    ctrl.savePreset(
                                      preset.name,
                                      replaceId: preset.id,
                                    );
                                  }
                                  if (action == 'delete') {
                                    ctrl.deletePreset(preset.id);
                                  }
                                  if (action == 'rename') {
                                    final name = await _name(
                                      'Rename preset',
                                      preset.name,
                                    );
                                    if (name != null) {
                                      ctrl.renamePreset(preset, name);
                                    }
                                  }
                                  if (action == 'duplicate') {
                                    final name = await _name(
                                      'Duplicate preset',
                                      '${preset.name} copy',
                                    );
                                    if (name != null) {
                                      ctrl.duplicatePreset(preset, name);
                                    }
                                  }
                                },
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              final name = await _name(
                                'Save menu as preset',
                                '',
                              );
                              if (name != null) ctrl.savePreset(name);
                            },
                            icon: const Icon(Icons.bookmark_add_outlined),
                            label: const Text('Save current menu as preset'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
