/// Top-level application modes, each with a distinct set of active panels
enum AppMode {
  /// Record events while watching video
  record,

  /// Review/filter recorded events, annotate with drawings
  review,

  /// Player tracking, possession, and future analytics tools
  tracking,
}

/// All addressable panels in the UI
enum PanelId {
  playbackControls,
  drawingTools,
  eventButtons,
  eventNavigation,
  playerTracking,
  shortcuts,
}
