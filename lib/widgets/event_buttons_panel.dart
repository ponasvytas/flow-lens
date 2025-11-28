import 'package:flutter/material.dart';
import '../models/game_event.dart';

class EventButtonsPanel extends StatelessWidget {
  final Function(EventCategory) onEventTriggered;

  const EventButtonsPanel({required this.onEventTriggered, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildButton(
            context,
            EventCategory.shot,
            Icons.sports_hockey,
            "Shot",
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildButton(
            context,
            EventCategory.pass,
            Icons.sync_alt,
            "Pass",
            Colors.cyan,
          ),
          const SizedBox(width: 8),
          _buildButton(
            context,
            EventCategory.battle,
            Icons.close,
            "Battle",
            Colors.redAccent,
          ),
          const SizedBox(width: 8),
          _buildButton(
            context,
            EventCategory.defense,
            Icons.shield,
            "Defense",
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildButton(
            context,
            EventCategory.teamPlay,
            Icons.groups,
            "Team Play",
            Colors.purple,
          ),
          const SizedBox(width: 8),
          _buildButton(
            context,
            EventCategory.penalty,
            Icons.gavel,
            "Penalty",
            Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    EventCategory category,
    IconData icon,
    String label,
    Color color,
  ) {
    return SizedBox(
      width: 80, // Slightly narrower to fit in one row
      height: 60,
      child: ElevatedButton(
        onPressed: () => onEventTriggered(category),
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.8),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
