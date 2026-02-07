import 'package:flutter/material.dart';

/// Branded title bar for Coach Flow Video Analyzer
class BrandedTitleBar extends StatelessWidget {
  final VoidCallback onShowShortcuts;
  final bool showShortcuts;
  final VoidCallback? onSaveEvents;
  final VoidCallback? onLoadEvents;
  final VoidCallback? onShowEventsTable;
  final VoidCallback? onShowSettings;

  const BrandedTitleBar({
    required this.onShowShortcuts,
    required this.showShortcuts,
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
                'COACH FLOW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Video Analyzer',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),

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
