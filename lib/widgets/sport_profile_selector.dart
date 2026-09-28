import 'package:flutter/material.dart';
import '../models/sport_profile.dart';
import '../theme/flow_theme.dart';

class SportProfileSelector extends StatelessWidget {
  final Function(SportProfile) onProfileSelected;

  const SportProfileSelector({required this.onProfileSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sports, size: 80, color: FlowTheme.accent),
            const SizedBox(height: 24),
            const Text(
              'Select Sport',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Choose which sport you want to analyze',
              style: TextStyle(fontSize: 16, color: FlowTheme.muted),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 24,
              runSpacing: 24,
              alignment: WrapAlignment.center,
              children: SportProfile.availableProfiles
                  .map((profile) => _buildSportCard(context, profile))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, SportProfile profile) {
    final isEnabled = profile.enabled;

    return InkWell(
      onTap: isEnabled ? () => onProfileSelected(profile) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        constraints: const BoxConstraints(minHeight: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isEnabled ? FlowTheme.raised : FlowTheme.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled ? FlowTheme.accent : FlowTheme.border,
            width: 2,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              profile.iconData,
              size: 64,
              color: isEnabled ? FlowTheme.accent : FlowTheme.muted,
            ),
            const SizedBox(height: 16),
            Text(
              profile.displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isEnabled ? FlowTheme.text : FlowTheme.muted,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isEnabled) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: FlowTheme.raised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 12,
                    color: FlowTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
