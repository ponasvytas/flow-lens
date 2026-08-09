import 'dart:ui';
import '../../models/game_event.dart';

/// How an event's impact (grade) is encoded in the on-clip label text.
enum LabelImpactStyle {
  /// No impact indicator; show only "Category - Event".
  none,

  /// Append an ASCII marker: [+] positive, [-] negative, [=] neutral.
  ascii,

  /// Append a word: (Positive) / (Negative) / (Neutral).
  word,

  /// No marker; color the whole text by grade (green/red/white).
  color,
}

/// Where the label is drawn on the frame.
enum LabelPosition {
  topLeft,
  topCenter,
  topRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// Relative font size of the label (fraction of frame height).
enum LabelSize { small, medium, large }

class ExportConfig {
  /// Seconds of video to include before the event timestamp.
  final double easeInSeconds;

  /// Seconds of video to include after the event timestamp.
  final double easeOutSeconds;

  /// Whether to append a slow-motion replay after the normal-speed clip.
  final bool includeSlowReplay;

  /// Playback speed for the slow-motion replay (e.g. 0.25 = quarter speed).
  final double slowReplaySpeed;

  /// Seconds of video before the event to include in the slow-motion replay.
  /// Lets the replay use a tighter window than the normal clip.
  final double slowMoEaseInSeconds;

  /// Seconds of video after the event to include in the slow-motion replay.
  final double slowMoEaseOutSeconds;

  /// Whether slow-motion replays are muted. Defaults to true so the audio
  /// pitch-shift of slowed footage doesn't sound jarring.
  final bool muteSlowReplay;

  /// Duration of fade-in / fade-out between clips (seconds).
  final double fadeDurationSeconds;

  /// Output video format extension (e.g. 'mp4', 'mov').
  final String outputFormat;

  /// Whether to burn an "Category - Event" label onto every clip.
  final bool includeLabels;

  /// How the event impact (grade) is encoded in the label.
  final LabelImpactStyle labelImpactStyle;

  /// Where the label is drawn on the frame.
  final LabelPosition labelPosition;

  /// Relative font size of the label.
  final LabelSize labelSize;

  const ExportConfig({
    this.easeInSeconds = 3.0,
    this.easeOutSeconds = 2.0,
    this.includeSlowReplay = false,
    this.slowReplaySpeed = 0.5,
    this.slowMoEaseInSeconds = 2.0,
    this.slowMoEaseOutSeconds = 1.0,
    this.muteSlowReplay = true,
    this.fadeDurationSeconds = 0.5,
    this.outputFormat = 'mp4',
    this.includeLabels = false,
    this.labelImpactStyle = LabelImpactStyle.ascii,
    this.labelPosition = LabelPosition.bottomCenter,
    this.labelSize = LabelSize.medium,
  });

  ExportConfig copyWith({
    double? easeInSeconds,
    double? easeOutSeconds,
    bool? includeSlowReplay,
    double? slowReplaySpeed,
    double? slowMoEaseInSeconds,
    double? slowMoEaseOutSeconds,
    bool? muteSlowReplay,
    double? fadeDurationSeconds,
    String? outputFormat,
    bool? includeLabels,
    LabelImpactStyle? labelImpactStyle,
    LabelPosition? labelPosition,
    LabelSize? labelSize,
  }) {
    return ExportConfig(
      easeInSeconds: easeInSeconds ?? this.easeInSeconds,
      easeOutSeconds: easeOutSeconds ?? this.easeOutSeconds,
      includeSlowReplay: includeSlowReplay ?? this.includeSlowReplay,
      slowReplaySpeed: slowReplaySpeed ?? this.slowReplaySpeed,
      slowMoEaseInSeconds: slowMoEaseInSeconds ?? this.slowMoEaseInSeconds,
      slowMoEaseOutSeconds: slowMoEaseOutSeconds ?? this.slowMoEaseOutSeconds,
      muteSlowReplay: muteSlowReplay ?? this.muteSlowReplay,
      fadeDurationSeconds: fadeDurationSeconds ?? this.fadeDurationSeconds,
      outputFormat: outputFormat ?? this.outputFormat,
      includeLabels: includeLabels ?? this.includeLabels,
      labelImpactStyle: labelImpactStyle ?? this.labelImpactStyle,
      labelPosition: labelPosition ?? this.labelPosition,
      labelSize: labelSize ?? this.labelSize,
    );
  }

  /// Serialize to a JSON-compatible map for persistence.
  Map<String, dynamic> toJson() => {
        'easeInSeconds': easeInSeconds,
        'easeOutSeconds': easeOutSeconds,
        'includeSlowReplay': includeSlowReplay,
        'slowReplaySpeed': slowReplaySpeed,
        'slowMoEaseInSeconds': slowMoEaseInSeconds,
        'slowMoEaseOutSeconds': slowMoEaseOutSeconds,
        'muteSlowReplay': muteSlowReplay,
        'fadeDurationSeconds': fadeDurationSeconds,
        'outputFormat': outputFormat,
        'includeLabels': includeLabels,
        'labelImpactStyle': labelImpactStyle.name,
        'labelPosition': labelPosition.name,
        'labelSize': labelSize.name,
      };

  /// Restore from a previously serialized map, falling back to defaults for
  /// any missing or invalid fields.
  factory ExportConfig.fromJson(Map<String, dynamic> json) {
    const defaults = ExportConfig();
    T enumFromName<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    return ExportConfig(
      easeInSeconds:
          (json['easeInSeconds'] as num?)?.toDouble() ?? defaults.easeInSeconds,
      easeOutSeconds: (json['easeOutSeconds'] as num?)?.toDouble() ??
          defaults.easeOutSeconds,
      includeSlowReplay:
          json['includeSlowReplay'] as bool? ?? defaults.includeSlowReplay,
      slowReplaySpeed: (json['slowReplaySpeed'] as num?)?.toDouble() ??
          defaults.slowReplaySpeed,
      slowMoEaseInSeconds: (json['slowMoEaseInSeconds'] as num?)?.toDouble() ??
          defaults.slowMoEaseInSeconds,
      slowMoEaseOutSeconds: (json['slowMoEaseOutSeconds'] as num?)?.toDouble() ??
          defaults.slowMoEaseOutSeconds,
      muteSlowReplay:
          json['muteSlowReplay'] as bool? ?? defaults.muteSlowReplay,
      fadeDurationSeconds: (json['fadeDurationSeconds'] as num?)?.toDouble() ??
          defaults.fadeDurationSeconds,
      outputFormat: json['outputFormat'] as String? ?? defaults.outputFormat,
      includeLabels: json['includeLabels'] as bool? ?? defaults.includeLabels,
      labelImpactStyle: enumFromName(LabelImpactStyle.values,
          json['labelImpactStyle'], defaults.labelImpactStyle),
      labelPosition: enumFromName(
          LabelPosition.values, json['labelPosition'], defaults.labelPosition),
      labelSize: enumFromName(
          LabelSize.values, json['labelSize'], defaults.labelSize),
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

  /// Start time of the slow-motion replay window in the source video.
  /// Falls back to [startTime] when not provided.
  final Duration? slowStartTime;

  /// End time of the slow-motion replay window in the source video.
  /// Falls back to [endTime] when not provided.
  final Duration? slowEndTime;

  /// Pre-rendered label text to burn onto the clip (null = no label).
  final String? labelText;

  /// FFmpeg color name for the label text (e.g. 'white', 'green').
  final String labelColor;

  const ExportClip({
    required this.event,
    required this.startTime,
    required this.endTime,
    this.cropRegion,
    this.appendSlowReplay = false,
    this.slowStartTime,
    this.slowEndTime,
    this.labelText,
    this.labelColor = 'white',
  });

  /// Duration of the normal-speed clip.
  Duration get duration => endTime - startTime;

  /// Effective slow-motion replay window start (defaults to [startTime]).
  Duration get slowStart => slowStartTime ?? startTime;

  /// Effective slow-motion replay window end (defaults to [endTime]).
  Duration get slowEnd => slowEndTime ?? endTime;
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
