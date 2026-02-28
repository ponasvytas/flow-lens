import 'package:flutter/material.dart';

/// Stub panel for the Tracking mode.
///
/// Placeholder UI for:
/// - Puck possession toggle (Team A / Team B)
/// - On-ice player badge grid (6v6 skater slots per team)
///
/// All data wiring is deferred to the future tracking feature.
class PlayerTrackingPanel extends StatefulWidget {
  const PlayerTrackingPanel({super.key});

  @override
  State<PlayerTrackingPanel> createState() => _PlayerTrackingPanelState();
}

class _PlayerTrackingPanelState extends State<PlayerTrackingPanel> {
  int _possessionTeam = -1; // -1 = none, 0 = Team A, 1 = Team B

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Puck possession
          const Text(
            'Possession',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _PossessionButton(
                  label: 'Team A',
                  active: _possessionTeam == 0,
                  color: const Color(0xFF2196F3),
                  onTap: () =>
                      setState(() => _possessionTeam = _possessionTeam == 0 ? -1 : 0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _PossessionButton(
                  label: 'Team B',
                  active: _possessionTeam == 1,
                  color: const Color(0xFFF44336),
                  onTap: () =>
                      setState(() => _possessionTeam = _possessionTeam == 1 ? -1 : 1),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // On-ice players placeholder
          const Text(
            'On Ice (coming soon)',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(
              12,
              (i) => _PlayerBadge(
                number: i < 6 ? '#${i + 1}' : '#${i - 5}',
                teamColor:
                    i < 6 ? const Color(0xFF2196F3) : const Color(0xFFF44336),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PossessionButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _PossessionButton({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.8) : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : color.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerBadge extends StatelessWidget {
  final String number;
  final Color teamColor;

  const _PlayerBadge({required this.number, required this.teamColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 28,
      decoration: BoxDecoration(
        color: teamColor.withOpacity(0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: teamColor.withOpacity(0.4), width: 1),
      ),
      child: Center(
        child: Text(
          number,
          style: TextStyle(
            color: teamColor.withOpacity(0.7),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
