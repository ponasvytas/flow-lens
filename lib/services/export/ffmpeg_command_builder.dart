import 'dart:ui';

/// Builds FFmpeg CLI argument lists for clip extraction and concatenation.
class FfmpegCommandBuilder {
  /// Format a [Duration] as HH:MM:SS.mmm for FFmpeg's -ss / -to flags.
  static String _formatTimestamp(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final millis = d.inMilliseconds.remainder(1000);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }

  /// Build arguments to extract a single normal-speed clip.
  ///
  /// Applies crop (if any) and fade-in/fade-out.
  /// Encoder-appropriate quality arguments.
  /// NVENC uses `-preset p4 -cq 20`, libx264 uses `-preset fast -crf 18`.
  static List<String> _encoderArgs(String encoder) {
    if (encoder == 'h264_nvenc') {
      return ['-c:v', 'h264_nvenc', '-preset', 'p4', '-cq', '20', '-b:v', '0'];
    }
    return ['-c:v', 'libx264', '-preset', 'fast', '-crf', '18'];
  }

  static List<String> buildClipArgs({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
    Rect? cropRegion,
    double fadeDurationSeconds = 0.5,
    String encoder = 'libx264',
    int? outputWidth,
    int? outputHeight,
  }) {
    final clipDuration = (endTime - startTime).inMilliseconds / 1000.0;

    // Build video filter chain
    final filters = <String>[];

    if (cropRegion != null) {
      filters.add(
        'crop=${cropRegion.width.toInt()}:${cropRegion.height.toInt()}'
        ':${cropRegion.left.toInt()}:${cropRegion.top.toInt()}',
      );
    }

    // Scale to uniform output size so all clips can be concatenated with -c copy
    if (outputWidth != null && outputHeight != null) {
      filters.add('scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease');
      filters.add('pad=$outputWidth:$outputHeight:(ow-iw)/2:(oh-ih)/2');
      filters.add('setsar=1');
    }

    // Fade-in at the start
    if (fadeDurationSeconds > 0) {
      filters.add('fade=t=in:st=0:d=$fadeDurationSeconds');
    }

    // Fade-out at the end
    if (fadeDurationSeconds > 0) {
      final fadeOutStart = clipDuration - fadeDurationSeconds;
      if (fadeOutStart > 0) {
        filters.add('fade=t=out:st=$fadeOutStart:d=$fadeDurationSeconds');
      }
    }

    return [
      '-y',
      '-ss', _formatTimestamp(startTime),
      '-to', _formatTimestamp(endTime),
      '-i', inputPath,
      if (filters.isNotEmpty) ...['-vf', filters.join(',')],
      ..._encoderArgs(encoder),
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      outputPath,
    ];
  }

  /// Build arguments to extract a slow-motion clip.
  ///
  /// Uses `setpts` for video and chained `atempo` for audio.
  static List<String> buildSlowMotionClipArgs({
    required String inputPath,
    required String outputPath,
    required Duration startTime,
    required Duration endTime,
    Rect? cropRegion,
    double speed = 0.5,
    double fadeDurationSeconds = 0.5,
    String encoder = 'libx264',
    int? outputWidth,
    int? outputHeight,
  }) {
    final ptsMultiplier = 1.0 / speed; // e.g. 0.5 speed → 2.0× PTS
    final slowDuration =
        (endTime - startTime).inMilliseconds / 1000.0 * ptsMultiplier;

    // Video filters
    final vFilters = <String>[];

    if (cropRegion != null) {
      vFilters.add(
        'crop=${cropRegion.width.toInt()}:${cropRegion.height.toInt()}'
        ':${cropRegion.left.toInt()}:${cropRegion.top.toInt()}',
      );
    }

    // Scale to uniform output size
    if (outputWidth != null && outputHeight != null) {
      vFilters.add('scale=$outputWidth:$outputHeight:force_original_aspect_ratio=decrease');
      vFilters.add('pad=$outputWidth:$outputHeight:(ow-iw)/2:(oh-ih)/2');
      vFilters.add('setsar=1');
    }

    vFilters.add('setpts=$ptsMultiplier*PTS');

    if (fadeDurationSeconds > 0) {
      vFilters.add('fade=t=in:st=0:d=$fadeDurationSeconds');
      final fadeOutStart = slowDuration - fadeDurationSeconds;
      if (fadeOutStart > 0) {
        vFilters.add('fade=t=out:st=$fadeOutStart:d=$fadeDurationSeconds');
      }
    }

    // Audio filters: atempo only supports 0.5–2.0, so chain for lower speeds.
    // e.g. 0.25× = atempo=0.5,atempo=0.5
    final aFilters = <String>[];
    var remaining = speed;
    while (remaining < 0.5) {
      aFilters.add('atempo=0.5');
      remaining *= 2;
    }
    if (remaining < 2.0) {
      aFilters.add('atempo=$remaining');
    }

    return [
      '-y',
      '-ss', _formatTimestamp(startTime),
      '-to', _formatTimestamp(endTime),
      '-i', inputPath,
      '-vf', vFilters.join(','),
      if (aFilters.isNotEmpty) ...['-af', aFilters.join(',')],
      if (aFilters.isEmpty) ...['-an'], // drop audio if speed is unsupported
      ..._encoderArgs(encoder),
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      outputPath,
    ];
  }

  /// Build a concat demuxer file content for joining multiple clips.
  ///
  /// Returns the text to write to a concat list file.
  static String buildConcatFileContent(List<String> clipPaths) {
    final buffer = StringBuffer();
    for (final path in clipPaths) {
      // Escape single quotes in paths for FFmpeg concat demuxer
      final escaped = path.replaceAll("'", "'\\''");
      buffer.writeln("file '$escaped'");
    }
    return buffer.toString();
  }

  /// Build arguments for concatenating clips using the concat demuxer.
  static List<String> buildConcatArgs({
    required String concatFilePath,
    required String outputPath,
  }) {
    return [
      '-y',
      '-f', 'concat',
      '-safe', '0',
      '-i', concatFilePath,
      '-c', 'copy',
      '-movflags', '+faststart',
      outputPath,
    ];
  }

  /// Build arguments to probe video dimensions using ffprobe.
  static List<String> buildProbeArgs(String inputPath) {
    return [
      '-v', 'error',
      '-select_streams', 'v:0',
      '-show_entries', 'stream=width,height',
      '-of', 'csv=p=0',
      inputPath,
    ];
  }
}
