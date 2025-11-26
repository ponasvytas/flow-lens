import 'package:flutter/material.dart';

/// Event logging buttons for shot and turnover tracking
class EventButtons extends StatelessWidget {
  final VoidCallback onShot;
  final VoidCallback onTurnover;

  const EventButtons({
    required this.onShot,
    required this.onTurnover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // SHOT ON GOAL button (bottom right)
        Positioned(
          bottom: 40,
          right: 20,
          child: FloatingActionButton.extended(
            onPressed: onShot,
            backgroundColor: Colors.redAccent,
            icon: const Icon(Icons.sports_hockey),
            label: const Text("SHOT ON GOAL"),
          ),
        ),
        
        // TURNOVER button (bottom left)
        Positioned(
          bottom: 40,
          left: 20,
          child: FloatingActionButton.extended(
            onPressed: onTurnover,
            backgroundColor: Colors.blueGrey,
            icon: const Icon(Icons.error_outline),
            label: const Text("TURNOVER"),
          ),
        ),
      ],
    );
  }
}
