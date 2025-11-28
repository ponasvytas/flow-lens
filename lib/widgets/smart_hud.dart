import 'package:flutter/material.dart';
import 'dart:async';
import '../models/game_event.dart';

class SmartHUD extends StatefulWidget {
  final GameEvent event;
  final Function(GameEvent) onUpdateEvent;
  final VoidCallback onDismiss;

  const SmartHUD({
    required this.event,
    required this.onUpdateEvent,
    required this.onDismiss,
    super.key,
  });

  @override
  State<SmartHUD> createState() => _SmartHUDState();
}

class _SmartHUDState extends State<SmartHUD>
    with SingleTickerProviderStateMixin {
  late Timer _dismissTimer;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();

    _resetTimer();
  }

  void _resetTimer() {
    if (mounted) {
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _fadeController.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  void _handleInteraction() {
    _dismissTimer.cancel();
    _resetTimer();
  }

  @override
  void dispose() {
    _dismissTimer.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  widget.event.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    _buildGradeButton(
                      EventGrade.positive,
                      Icons.thumb_up,
                      Colors.green,
                    ),
                    const SizedBox(width: 4),
                    _buildGradeButton(
                      EventGrade.neutral,
                      Icons.remove,
                      Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    _buildGradeButton(
                      EventGrade.negative,
                      Icons.thumb_down,
                      Colors.red,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(color: Colors.white24),

            // Context Tags
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _getContextTags()
                  .map((tag) => _buildTagButton(tag))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeButton(EventGrade grade, IconData icon, Color color) {
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
        child: Icon(
          icon,
          size: 16,
          color: isSelected ? Colors.white : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildTagButton(String tag) {
    final isSelected = widget.event.detail == tag;
    return InkWell(
      onTap: () {
        _handleInteraction();
        // Auto-grade logic based on tag
        EventGrade newGrade = widget.event.grade;
        if (_isPositiveTag(tag)) newGrade = EventGrade.positive;
        if (_isNegativeTag(tag)) newGrade = EventGrade.negative;

        widget.onUpdateEvent(
          widget.event.copyWith(detail: tag, grade: newGrade),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white24,
          ),
        ),
        child: Text(
          tag,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  List<String> _getContextTags() {
    switch (widget.event.category) {
      case EventCategory.shot:
        return ["Goal", "On Net", "Wide", "Blocked"];
      case EventCategory.pass:
        return ["Tape-to-Tape", "Stretch", "Turnover", "Icing"];
      case EventCategory.battle:
        return ["Won", "Lost", "Hit Given", "Hit Taken"];
      case EventCategory.defense:
        return ["Goal Against", "Save", "Block", "Clear", "Breakdown"];
      case EventCategory.teamPlay:
        return ["Breakout", "Zone Entry", "Regroup", "Forecheck"];
      case EventCategory.penalty:
        return ["Us", "Them"];
    }
  }

  bool _isPositiveTag(String tag) {
    return [
      "Goal",
      "Tape-to-Tape",
      "Won",
      "Hit Given",
      "Save",
      "Block",
      "Clear",
      "Them",
    ].contains(tag);
  }

  bool _isNegativeTag(String tag) {
    return [
      "Goal Against",
      "Turnover",
      "Icing",
      "Lost",
      "Hit Taken",
      "Breakdown",
      "Us",
    ].contains(tag);
  }
}
