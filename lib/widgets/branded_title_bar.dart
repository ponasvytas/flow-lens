import 'package:flutter/material.dart';
import '../models/app_mode.dart';

/// Branded title bar for Flow Lens
class BrandedTitleBar extends StatelessWidget {
  final VoidCallback onShowShortcuts;
  final bool showShortcuts;
  final VoidCallback? onSaveEvents;
  final VoidCallback? onLoadEvents;
  final VoidCallback? onShowEventsTable;
  final VoidCallback? onShowSettings;
  final VoidCallback? onShowAccount;
  final VoidCallback? onShowCloudSessions;
  final VoidCallback? onResetLayout;
  final bool isSignedIn;
  final bool hasPremium;
  final VoidCallback? onToggleDockedEvents;
  final bool showDockedEvents;

  // Mode switching
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;

  const BrandedTitleBar({
    required this.onShowShortcuts,
    required this.showShortcuts,
    required this.currentMode,
    required this.onModeChanged,
    this.onSaveEvents,
    this.onLoadEvents,
    this.onShowEventsTable,
    this.onShowSettings,
    this.onShowAccount,
    this.onShowCloudSessions,
    this.onResetLayout,
    this.isSignedIn = false,
    this.hasPremium = false,
    this.onToggleDockedEvents,
    this.showDockedEvents = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final actions = <(String, IconData, VoidCallback?)>[
        (
          'Reset workspace layout',
          Icons.dashboard_customize_outlined,
          onResetLayout,
        ),
        ('Save events', Icons.save_alt, onSaveEvents),
        ('Load events', Icons.upload_file, onLoadEvents),
        ('Events table', Icons.table_chart_outlined, onShowEventsTable),
        (
          showDockedEvents ? 'Hide events list' : 'Events list',
          Icons.view_sidebar_outlined,
          onToggleDockedEvents,
        ),
        ('Settings', Icons.settings_outlined, onShowSettings),
        (
          isSignedIn ? 'Account' : 'Sign in',
          Icons.person_outline,
          onShowAccount,
        ),
        ('Cloud sessions', Icons.cloud_outlined, onShowCloudSessions),
        ('Keyboard shortcuts', Icons.keyboard_outlined, onShowShortcuts),
      ];
      return Container(
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFF251B35),
          border: Border(bottom: BorderSide(color: Color(0xFF58416D))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(
              Icons.blur_on_rounded,
              color: Color(0xFFC4A5FA),
              size: 28,
            ),
            if (!compact) ...[
              const SizedBox(width: 10),
              const Text(
                'FLOW LENS',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ],
            const Spacer(),
            if (compact)
              PopupMenuButton<AppMode>(
                tooltip: 'Change workflow',
                initialValue: currentMode,
                onSelected: onModeChanged,
                itemBuilder: (_) => [
                  for (final mode in AppMode.values)
                    PopupMenuItem(value: mode, child: Text(_label(mode))),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Text(_label(currentMode)),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                ),
              )
            else ...[
              for (final mode in AppMode.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: TextButton(
                    onPressed: () => onModeChanged(mode),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(76, 48),
                      foregroundColor: mode == currentMode
                          ? Colors.white
                          : const Color(0xFFC0B6CD),
                      backgroundColor: mode == currentMode
                          ? const Color(0xFF63418A)
                          : Colors.transparent,
                    ),
                    child: Text(_label(mode)),
                  ),
                ),
            ],
            const Spacer(),
            PopupMenuButton<int>(
              tooltip: 'App menu',
              icon: const Icon(Icons.more_horiz),
              itemBuilder: (_) => [
                for (var i = 0; i < actions.length; i++)
                  PopupMenuItem(
                    value: i,
                    enabled: actions[i].$3 != null,
                    child: Row(
                      children: [
                        Icon(actions[i].$2, size: 20),
                        const SizedBox(width: 12),
                        Text(actions[i].$1),
                      ],
                    ),
                  ),
              ],
              onSelected: (index) => actions[index].$3?.call(),
            ),
          ],
        ),
      );
    },
  );

  static String _label(AppMode mode) => switch (mode) {
    AppMode.record => 'Record',
    AppMode.review => 'Review',
    AppMode.tracking => 'Track',
  };
}
