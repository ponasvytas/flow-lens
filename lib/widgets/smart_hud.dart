import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';
import '../controllers/event_entry_controller.dart';
import '../theme/flow_theme.dart';
import 'event_entry_pager.dart';
import 'event_context_editor.dart';

class SmartHUD extends StatefulWidget {
  final GameEvent event;
  final Function(GameEvent) onUpdateEvent;
  final Function(GameEvent) onDeleteEvent;
  final VoidCallback onDismiss;
  final VoidCallback onSave;
  final bool autoDismiss;
  final bool isAltPressed; // Whether Alt key is currently held
  final bool showTagNumbers;
  final bool showGradeNumbers;
  final SportTaxonomy? taxonomy;
  final int entryPage;
  final ValueChanged<int>? onEntryPageChanged;

  const SmartHUD({
    required this.event,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
    required this.onDismiss,
    required this.onSave,
    this.isAltPressed = false,
    this.autoDismiss = false,
    this.showTagNumbers = false,
    this.showGradeNumbers = false,
    this.taxonomy,
    this.entryPage = 0,
    this.onEntryPageChanged,
    super.key,
  });

  @override
  State<SmartHUD> createState() => _SmartHUDState();
}

class _SmartHUDState extends State<SmartHUD>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  late AnimationController _fadeController;
  bool _wasAltPressed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();

    _resetTimer();
  }

  @override
  void didUpdateWidget(SmartHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.categoryId != widget.event.categoryId) {
      _query = '';
    }

    // If Alt key state changed, handle timer accordingly
    if (widget.isAltPressed != _wasAltPressed) {
      _wasAltPressed = widget.isAltPressed;

      if (widget.isAltPressed) {
        // Alt pressed: cancel timer to keep HUD visible
        _dismissTimer?.cancel();
      } else {
        // Alt released: restart timer
        _resetTimer();
      }
    }
  }

  void _resetTimer() {
    _dismissTimer?.cancel();

    // Don't start timer if Alt is held
    if (widget.autoDismiss && !widget.isAltPressed && mounted) {
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _fadeController.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  void _handleInteraction() {
    _dismissTimer?.cancel();
    _resetTimer();
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventTypeOptions = _getEventTypeOptions();
    final canSave = widget.event.isComplete;
    final visibleTypes = widget.showTagNumbers
        ? eventTypeOptions
              .skip(widget.entryPage * EventEntryController.pageSize)
              .take(EventEntryController.pageSize)
              .toList()
        : eventTypeOptions.where((e) => e.matches(_query)).toList();

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlowTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlowTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.event.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel event entry',
                    onPressed: () {
                      _dismissTimer?.cancel();
                      widget.onDismiss();
                    },
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Grade selector and delete
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildGradeButton(
                                EventGrade.positive,
                                Icons.thumb_up,
                                FlowTheme.positive,
                                1,
                              ),
                              const SizedBox(width: 4),
                              _buildGradeButton(
                                EventGrade.neutral,
                                Icons.remove,
                                FlowTheme.neutral,
                                2,
                              ),
                              const SizedBox(width: 4),
                              _buildGradeButton(
                                EventGrade.negative,
                                Icons.thumb_down,
                                FlowTheme.negative,
                                3,
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: widget.showGradeNumbers
                                    ? 'Ungraded (0)'
                                    : 'Ungraded',
                                child: OutlinedButton(
                                  onPressed: () => widget.onUpdateEvent(
                                    widget.event.copyWith(clearGrade: true),
                                  ),
                                  child: Text(
                                    widget.showGradeNumbers
                                        ? '0. Ungraded'
                                        : 'Ungraded',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12), // Spacer before delete
                              // Delete Button
                              InkWell(
                                onTap: () {
                                  _dismissTimer?.cancel();
                                  widget.onDeleteEvent(widget.event);
                                },
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: FlowTheme.negative.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: FlowTheme.negative.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    size: 22,
                                    color: FlowTheme.negative,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white24),

                      if (!canSave)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Choose a sub-event. Grading is optional.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (!widget.showTagNumbers &&
                          eventTypeOptions.length >
                              EventEntryController.pageSize)
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Find sub-event',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) =>
                              setState(() => _query = value.trim()),
                        ),
                      // Context Tags
                      if (canSave &&
                          !eventTypeOptions.any(
                            (type) =>
                                type.eventTypeId == widget.event.eventTypeId,
                          ))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Saved selection: ${widget.event.detail ?? widget.event.eventTypeId ?? "Unknown"} (legacy)',
                          ),
                        ),
                      if (eventTypeOptions.isEmpty)
                        const Text(
                          'Loading taxonomy…',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: visibleTypes
                              .asMap()
                              .entries
                              .map(
                                (entry) =>
                                    _buildTagButton(entry.value, entry.key),
                              )
                              .toList(),
                        ),
                      if (widget.showTagNumbers)
                        EventEntryPager(
                          page: widget.entryPage,
                          count: eventTypeOptions.length,
                          onChanged: widget.onEntryPageChanged,
                        ),
                      if (widget.event.definition?.isNotEmpty == true)
                        ExpansionTile(
                          title: const Text('Coding definition'),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(widget.event.definition!),
                            ),
                          ],
                        ),
                      if (widget.taxonomy != null && canSave)
                        EventContextEditor(
                          key: ValueKey(widget.event.id),
                          taxonomy: widget.taxonomy!,
                          categoryId: widget.event.categoryId,
                          values: widget.event.context,
                          onChanged: (values) => widget.onUpdateEvent(
                            widget.event.copyWith(context: values),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canSave
                      ? () {
                          _dismissTimer?.cancel();
                          widget.onSave();
                        }
                      : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Save event'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeButton(
    EventGrade grade,
    IconData icon,
    Color color,
    int number,
  ) {
    final isSelected = widget.event.grade == grade;
    return InkWell(
      onTap: () {
        _handleInteraction();
        widget.onUpdateEvent(widget.event.copyWith(grade: grade));
      },
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : FlowTheme.controlBorder,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? FlowTheme.background : FlowTheme.muted,
            ),
            // Number badge in top-right corner
            if (widget.showGradeNumbers)
              Positioned(
                top: -16,
                right: -16,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: FlowTheme.selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: const TextStyle(
                        color: FlowTheme.text,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagButton(EventTypeTaxonomy eventType, int index) {
    final isSelected =
        widget.event.eventTypeId == eventType.eventTypeId ||
        (widget.event.eventTypeId == null &&
            widget.event.detail == eventType.name);
    return Tooltip(
      message: eventType.definition,
      child: InkWell(
        onTap: () {
          _handleInteraction();
          widget.onUpdateEvent(
            widget.event.copyWith(
              detail: eventType.name,
              eventTypeId: eventType.eventTypeId,
              grade: eventType.defaultImpact,
              clearGrade: eventType.defaultImpact == null,
              taxonomyRevision: widget.taxonomy?.revision,
              definition: eventType.definition,
              context: {...widget.event.context, ...eventType.contextDefaults},
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? FlowTheme.selected : FlowTheme.raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? FlowTheme.accent : FlowTheme.border,
                ),
              ),
              child: Text(
                eventType.name,
                style: TextStyle(
                  color: isSelected ? FlowTheme.text : FlowTheme.muted,
                  fontSize: 12,
                ),
              ),
            ),
            // Number badge in top-right corner
            if (widget.showTagNumbers)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: FlowTheme.selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: FlowTheme.text,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<EventTypeTaxonomy> _getEventTypeOptions() {
    final taxonomy = widget.taxonomy;
    if (taxonomy == null) {
      return const [];
    }

    final category = taxonomy.getCategoryById(widget.event.categoryId);
    if (category == null) {
      return const [];
    }

    return category.captureEventTypes;
  }
}
