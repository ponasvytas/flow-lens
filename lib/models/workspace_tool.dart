import 'package:flutter/material.dart';

import 'app_mode.dart';

class WorkspaceTool {
  final PanelId id;
  final String title;
  final IconData icon;
  final Set<AppMode> modes;

  const WorkspaceTool(this.id, this.title, this.icon, this.modes);

  static const all = [
    WorkspaceTool(
      PanelId.playbackControls,
      'Playback',
      Icons.play_circle_outline,
      {AppMode.record, AppMode.review, AppMode.tracking},
    ),
    WorkspaceTool(PanelId.quickEvents, 'Quick events', Icons.bolt_rounded, {
      AppMode.record,
    }),
    WorkspaceTool(PanelId.categories, 'Categories', Icons.category_outlined, {
      AppMode.record,
    }),
    WorkspaceTool(PanelId.drawingTools, 'Drawing', Icons.draw_outlined, {
      AppMode.review,
    }),
    WorkspaceTool(
      PanelId.eventNavigation,
      'Event navigation',
      Icons.skip_next_outlined,
      {AppMode.review},
    ),
    WorkspaceTool(PanelId.eventsList, 'Events list', Icons.view_list_outlined, {
      AppMode.record,
      AppMode.review,
      AppMode.tracking,
    }),
    WorkspaceTool(
      PanelId.playerTracking,
      'Player tracking',
      Icons.people_outline,
      {AppMode.tracking},
    ),
  ];

  static Iterable<WorkspaceTool> forMode(AppMode mode) =>
      all.where((tool) => tool.modes.contains(mode));

  static bool available(PanelId id, AppMode mode) =>
      id == PanelId.shortcuts || forMode(mode).any((tool) => tool.id == id);
}
