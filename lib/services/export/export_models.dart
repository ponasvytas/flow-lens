import 'dart:ui';
import '../../models/game_event.dart';

class ExportConfig {
  /// Seconds of video to include before the event timestamp.
  final double easeInSeconds;

  /// Seconds of video to include after the event timestamp.
  final double easeOutSeconds;

  /// Whether to append a slow-motion replay after the normal-speed clip.
  final bool includeSlowReplay;

  /// Playback speed for the slow-motion replay (e.g. 0.25 = quarter speed).
  final double slowReplaySpeed;

  /// Duration of fade-in / fade-out between clips (seconds).
  final double fadeDurationSeconds;

  /// Output video format extension (e.g. 'mp4', 'mov').
  final String outputFormat;

  const ExportConfig({
    this.easeInSeconds = 3.0,
    this.easeOutSeconds = 2.0,
    this.includeSlowReplay = false,
    this.slowReplaySpeed = 0.5,
    this.fadeDurationSeconds = 0.5,
    this.outputFormat = 'mp4',
  });

  ExportConfig copyWith({
    double? easeInSeconds,
    double? easeOutSeconds,
    bool? includeSlowReplay,
    double? slowReplaySpeed,
    double? fadeDurationSeconds,
    String? outputFormat,
  }) {
    return ExportConfig(
      easeInSeconds: easeInSeconds ?? this.easeInSeconds,
      easeOutSeconds: easeOutSeconds ?? this.easeOutSeconds,
      includeSlowReplay: includeSlowReplay ?? this.includeSlowReplay,
      slowReplaySpeed: slowReplaySpeed ?? this.slowReplaySpeed,
      fadeDurationSeconds: fadeDurationSeconds ?? this.fadeDurationSeconds,
      outputFormat: outputFormat ?? this.outputFormat,
    );
  }
}

class ExportClip {
  final GameEvent event;

  /// Absolute start time in the source video.
  final Duration startTime;

  /// Absolute end time in the source video.
  final Duration endTime;

  /// Crop region in source-video pixel coordinates (null = full frame).
  final Rect? cropRegion;

  /// Whether this specific clip should get a slow-motion replay appended.
  final bool appendSlowReplay;

  const ExportClip({
    required this.event,
    required this.startTime,
    required this.endTime,
    this.cropRegion,
    this.appendSlowReplay = false,
  });

  /// Duration of the normal-speed clip.
  Duration get duration => endTime - startTime;
}

class ExportJob {
  /// Path or URL to the source video file.
  final String sourceVideoPath;

  /// Ordered list of clips to include in the export.
  final List<ExportClip> clips;

  /// Export settings.
  final ExportConfig config;

  /// Destination file path for the exported video.
  final String outputPath;

  const ExportJob({
    required this.sourceVideoPath,
    required this.clips,
    required this.config,
    required this.outputPath,
  });
}

enum ExportStatus {
  idle,
  preparing,
  extractingClips,
  concatenating,
  done,
  failed,
  cancelled,
}

class ExportProgress {
  final ExportStatus status;
  final int currentClipIndex;
  final int totalClips;
  final double overallProgress; // 0.0 – 1.0
  final String message;
  final String? errorMessage;
  final List<String> logLines;

  const ExportProgress({
    required this.status,
    this.currentClipIndex = 0,
    this.totalClips = 0,
    this.overallProgress = 0.0,
    this.message = '',
    this.errorMessage,
    this.logLines = const [],
  });

  ExportProgress copyWith({
    ExportStatus? status,
    int? currentClipIndex,
    int? totalClips,
    double? overallProgress,
    String? message,
    String? errorMessage,
    List<String>? logLines,
  }) {
    return ExportProgress(
      status: status ?? this.status,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      totalClips: totalClips ?? this.totalClips,
      overallProgress: overallProgress ?? this.overallProgress,
      message: message ?? this.message,
      errorMessage: errorMessage ?? this.errorMessage,
      logLines: logLines ?? this.logLines,
    );
  }
}
