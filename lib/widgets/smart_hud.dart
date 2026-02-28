import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_event.dart';
import '../models/sport_taxonomy.dart';

class SmartHUD extends StatefulWidget {
  final GameEvent event;
  final Function(GameEvent) onUpdateEvent;
  final Function(GameEvent) onDeleteEvent;
  final VoidCallback onDismiss;
  final Function(int)? onNumberPressed; // Callback for number key presses
  final VoidCallback? onEnterPressed; // Callback for Enter key
  final VoidCallback? onEscPressed; // Callback for Esc key
  final bool isAltPressed; // Whether Alt key is currently held
  final bool showTagNumbers;
  final bool showGradeNumbers;
  final SportTaxonomy? taxonomy;

  const SmartHUD({
    required this.event,
    required this.onUpdateEvent,
    required this.onDeleteEvent,
    required this.onDismiss,
    this.onNumberPressed,
    this.onEnterPressed,
    this.onEscPressed,
    this.isAltPressed = false,
    this.showTagNumbers = false,
    this.showGradeNumbers = false,
    this.taxonomy,
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
    if (!widget.isAltPressed && mounted) {
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

    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Event Type + Grade Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Label
                Text(
                  widget.event.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                // Right: Controls (Grade + Delete)
                Row(
                  children: [
                    _buildGradeButton(
                      EventGrade.positive,
                      Icons.thumb_up,
                      Colors.green,
                      1,
                    ),
                    const SizedBox(width: 4),
                    _buildGradeButton(
                      EventGrade.neutral,
                      Icons.remove,
                      Colors.grey,
                      2,
                    ),
                    const SizedBox(width: 4),
                    _buildGradeButton(
                      EventGrade.negative,
                      Icons.thumb_down,
                      Colors.red,
                      3,
                    ),
                    const SizedBox(width: 12), // Spacer before delete
                    // Delete Button
                    InkWell(
                      onTap: () {
                        _dismissTimer?.cancel();
                        widget.onDeleteEvent(widget.event);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24),

            // Context Tags
            if (eventTypeOptions.isEmpty)
              const Text(
                'Loading taxonomy…',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: eventTypeOptions
                    .asMap()
                    .entries
                    .map((entry) => _buildTagButton(entry.value, entry.key))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeButton(EventGrade grade, IconData icon, Color color, int number) {
    final isSelected = widget.event.grade == grade;
    return InkWell(
      onTap: () {
        _handleInteraction();
        widget.onUpdateEvent(widget.event.copyWith(grade: grade));
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: isSelected ? color : Colors.white38),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.white70,
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
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: const TextStyle(
                        color: Colors.white,
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
    final isSelected = widget.event.eventTypeId == eventType.eventTypeId ||
        (widget.event.eventTypeId == null && widget.event.detail == eventType.name);
    return InkWell(
      onTap: () {
        _handleInteraction();
        widget.onUpdateEvent(
          widget.event.copyWith(
            detail: eventType.name,
            eventTypeId: eventType.eventTypeId,
            grade: eventType.defaultImpact ?? widget.event.grade,
          ),
        );
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blueAccent : Colors.white10,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.blueAccent : Colors.white24,
              ),
            ),
            child: Text(
              eventType.name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
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
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
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

    return category.eventTypes;
  }
}
