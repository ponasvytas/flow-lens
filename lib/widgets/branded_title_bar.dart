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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF753b8f), // Your purple
            const Color(0xFF9b5fb8), // Lighter purple
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Logo
          Image.asset(
            'assets/logo.png',
            height: 40,
            width: 40,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if image doesn't load
              print('Error loading logo: $error');
              return Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'CF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Brand Text
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FLOW LENS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'by Coach Flow',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Mode tabs
          _ModeTabs(currentMode: currentMode, onModeChanged: onModeChanged),

          const Spacer(),

          // Save/Load Actions
          if (onSaveEvents != null)
            IconButton(
              onPressed: onSaveEvents,
              tooltip: 'Save Events',
              icon: const Icon(Icons.save_alt, color: Colors.white70),
            ),
          if (onLoadEvents != null)
            IconButton(
              onPressed: onLoadEvents,
              tooltip: 'Load Events',
              icon: const Icon(Icons.upload_file, color: Colors.white70),
            ),
          if (onShowEventsTable != null)
            IconButton(
              onPressed: onShowEventsTable,
              tooltip: 'Events Table',
              icon: const Icon(Icons.table_chart, color: Colors.white70),
            ),
          if (onShowSettings != null)
            IconButton(
              onPressed: onShowSettings,
              tooltip: 'Settings',
              icon: const Icon(Icons.settings, color: Colors.white70),
            ),

          const SizedBox(width: 8),

          // Shortcuts Toggle Button
          IconButton(
            onPressed: onShowShortcuts,
            icon: Icon(
              showShortcuts ? Icons.keyboard_hide : Icons.keyboard,
              color: Colors.white,
            ),
            tooltip: showShortcuts ? 'Hide Shortcuts' : 'Show Shortcuts',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mode tab strip
// ---------------------------------------------------------------------------

class _ModeTabs extends StatelessWidget {
  final AppMode currentMode;
  final ValueChanged<AppMode> onModeChanged;

  const _ModeTabs({required this.currentMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AppMode.values
            .map((mode) => _ModeTab(
                  mode: mode,
                  isActive: mode == currentMode,
                  onTap: () => onModeChanged(mode),
                ))
            .toList(),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final AppMode mode;
  final bool isActive;
  final VoidCallback onTap;

  const _ModeTab({
    required this.mode,
    required this.isActive,
    required this.onTap,
  });

  static String _label(AppMode mode) {
    switch (mode) {
      case AppMode.record:
        return 'Record';
      case AppMode.review:
        return 'Review';
      case AppMode.tracking:
        return 'Track';
    }
  }

  static IconData _icon(AppMode mode) {
    switch (mode) {
      case AppMode.record:
        return Icons.fiber_manual_record;
      case AppMode.review:
        return Icons.search;
      case AppMode.tracking:
        return Icons.people;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon(mode),
              size: 13,
              color: isActive ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              _label(mode),
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white54,
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.bold : FontWeight.normal,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
