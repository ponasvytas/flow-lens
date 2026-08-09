import 'dart:ui';
import 'export_models.dart';

/// Builds FFmpeg CLI argument lists for clip extraction and concatenation.
class FfmpegCommandBuilder {
  /// Escape arbitrary text for use inside a single-quoted `drawtext` value.
  ///
  /// The colon is escaped because `drawtext`'s own option parser (the second
  /// escaping level, applied after the filtergraph strips the quotes) splits
  /// key=value pairs on ':'.
  static String _escapeDrawText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll("'", "\\'")
        .replaceAll('%', '\\%')
        .replaceAll(':', '\\:');
  }

  /// Escape a font file path for embedding in a single-quoted `drawtext`
  /// `fontfile` value.
  ///
  /// Uses forward slashes (FFmpeg accepts them on Windows) and escapes the
  /// Windows drive colon with a backslash. Because the caller wraps the result
  /// in single quotes, the filtergraph parser passes the backslash through
  /// literally and `drawtext`'s option parser then unescapes `\:` back to a
  /// literal colon.
  static String _escapeFontPath(String path) {
    return path.replaceAll('\\', '/').replaceAll(':', '\\:');
  }

  /// FFmpeg `fontsize` expression for the given [LabelSize] (fraction of
  /// frame height).
  static String _fontSizeExpr(LabelSize size) {
    switch (size) {
      case LabelSize.small:
        return 'h/30';
      case LabelSize.medium:
        return 'h/22';
      case LabelSize.large:
        return 'h/15';
    }
  }

  /// FFmpeg `x` / `y` expressions for the given [LabelPosition].
  static (String x, String y) _positionExpr(LabelPosition position) {
    const margin = '(h*0.04)';
    switch (position) {
      case LabelPosition.topLeft:
        return (margin, margin);
      case LabelPosition.topCenter:
        return ('(w-text_w)/2', margin);
      case LabelPosition.topRight:
        return ('w-text_w-$margin', margin);
      case LabelPosition.bottomLeft:
        return (margin, 'h-text_h-$margin');
      case LabelPosition.bottomCenter:
        return ('(w-text_w)/2', 'h-text_h-$margin');
      case LabelPosition.bottomRight:
        return ('w-text_w-$margin', 'h-text_h-$margin');
    }
  }

  /// Build a `drawtext` filter string, or null if a label cannot be drawn
  /// (no text or no available font file).
  static String? buildLabelFilter({
    required String? text,
    required String color,
    required String? fontFile,
    required LabelSize size,
    required LabelPosition position,
  }) {
    if (text == null || text.trim().isEmpty || fontFile == null) return null;
    final (x, y) = _positionExpr(position);
    return "drawtext=fontfile='${_escapeFontPath(fontFile)}'"
        ":text='${_escapeDrawText(text)}'"
        ':fontcolor=$color'
        ':fontsize=${_fontSizeExpr(size)}'
        ':box=1:boxcolor=black@0.5:boxborderw=12'
        ':x=$x:y=$y';
  }
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
    String? labelText,
    String labelColor = 'white',
    String? labelFontFile,
    LabelSize labelSize = LabelSize.medium,
    LabelPosition labelPosition = LabelPosition.bottomCenter,
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

    // Burn-in event label
    final labelFilter = buildLabelFilter(
      text: labelText,
      color: labelColor,
      fontFile: labelFontFile,
      size: labelSize,
      position: labelPosition,
    );
    if (labelFilter != null) filters.add(labelFilter);

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
    bool mute = true,
    String encoder = 'libx264',
    int? outputWidth,
    int? outputHeight,
    String? labelText,
    String labelColor = 'white',
    String? labelFontFile,
    LabelSize labelSize = LabelSize.medium,
    LabelPosition labelPosition = LabelPosition.bottomCenter,
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

    // Burn-in event label (drawn before setpts so it stays on every frame)
    final labelFilter = buildLabelFilter(
      text: labelText,
      color: labelColor,
      fontFile: labelFontFile,
      size: labelSize,
      position: labelPosition,
    );
    if (labelFilter != null) vFilters.add(labelFilter);

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
    if (!mute) {
      var remaining = speed;
      while (remaining < 0.5) {
        aFilters.add('atempo=0.5');
        remaining *= 2;
      }
      if (remaining < 2.0) {
        aFilters.add('atempo=$remaining');
      }
    }

    // Drop audio entirely when muted or when the speed can't be expressed.
    final dropAudio = mute || aFilters.isEmpty;

    return [
      '-y',
      '-ss', _formatTimestamp(startTime),
      '-to', _formatTimestamp(endTime),
      '-i', inputPath,
      '-vf', vFilters.join(','),
      if (!dropAudio) ...['-af', aFilters.join(',')],
      if (dropAudio) ...['-an'],
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
