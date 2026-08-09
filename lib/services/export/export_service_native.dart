import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'export_models.dart';
import 'export_service.dart';
import 'ffmpeg_command_builder.dart';
import 'crop_calculator.dart';

class ExportServiceImpl implements ExportService {
  Process? _activeProcess;
  bool _cancelled = false;
  String? _detectedEncoder;

  /// Locate a TrueType font file for `drawtext` label burn-in.
  ///
  /// `drawtext` requires an explicit fontfile on most builds (fontconfig is
  /// usually unavailable on Windows). Returns the first existing candidate for
  /// the current platform, or null if none are found.
  String? _resolveFontFile() {
    final candidates = <String>[
      if (Platform.isWindows) ...[
        r'C:\Windows\Fonts\arialbd.ttf',
        r'C:\Windows\Fonts\arial.ttf',
        r'C:\Windows\Fonts\segoeui.ttf',
      ] else if (Platform.isMacOS) ...[
        '/System/Library/Fonts/Helvetica.ttc',
        '/Library/Fonts/Arial.ttf',
        '/System/Library/Fonts/SFNS.ttf',
      ] else ...[
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/TTF/DejaVuSans.ttf',
      ],
    ];
    for (final path in candidates) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  @override
  Future<bool> isFfmpegAvailable() async {
    try {
      final result = await Process.run('ffmpeg', ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  @override
  void cancel() {
    _cancelled = true;
    _activeProcess?.kill();
  }

  @override
  Stream<ExportProgress> export(ExportJob job) {
    final controller = StreamController<ExportProgress>();
    _runExport(job, controller);
    return controller.stream;
  }

  Future<void> _runExport(
    ExportJob job,
    StreamController<ExportProgress> ctrl,
  ) async {
    _cancelled = false;
    final tempDir = await Directory.systemTemp.createTemp('flowlens_export_');
    final tempClipPaths = <String>[];
    final logBuffer = <String>[];

    void log(String line) {
      logBuffer.add(line);
      // Keep last 200 lines to avoid unbounded growth
      if (logBuffer.length > 200) logBuffer.removeAt(0);
    }

    void emit(ExportProgress p) {
      if (!ctrl.isClosed) ctrl.add(p.copyWith(logLines: List.of(logBuffer)));
    }

    try {
      // --- Step 0: Detect best encoder ---
      emit(const ExportProgress(
        status: ExportStatus.preparing,
        message: 'Detecting hardware encoder…',
      ));

      _detectedEncoder = await _detectEncoder();
      log('Encoder: $_detectedEncoder');

      emit(ExportProgress(
        status: ExportStatus.preparing,
        message: _detectedEncoder == 'h264_nvenc'
            ? 'Using NVIDIA NVENC hardware encoder'
            : 'Using software encoder (libx264)',
      ));

      // --- Step 1: Probe video dimensions ---
      emit(const ExportProgress(
        status: ExportStatus.preparing,
        message: 'Probing video dimensions…',
      ));

      final videoDimensions = await _probeVideoDimensions(job.sourceVideoPath);
      if (videoDimensions == null) {
        emit(const ExportProgress(
          status: ExportStatus.failed,
          errorMessage: 'Could not determine video dimensions. '
              'Is ffprobe available on your PATH?',
        ));
        ctrl.close();
        return;
      }
      final (videoWidth, videoHeight) = videoDimensions;

      // Resolve a font for label burn-in (null disables drawtext).
      final fontFile = _resolveFontFile();
      if (job.clips.any((c) => c.labelText != null) && fontFile == null) {
        log('WARNING: No usable font found for labels; labels disabled.');
      } else if (fontFile != null) {
        log('Label font: $fontFile');
      }

      // --- Step 2: Extract each clip ---
      final totalSegments = job.clips.fold<int>(
        0,
        (sum, clip) => sum + 1 + (clip.appendSlowReplay ? 1 : 0),
      );
      var segmentIndex = 0;

      for (var i = 0; i < job.clips.length; i++) {
        if (_cancelled) {
          emit(const ExportProgress(
            status: ExportStatus.cancelled,
            message: 'Export cancelled.',
          ));
          ctrl.close();
          return;
        }

        final clip = job.clips[i];
        final clipDurationMs = clip.duration.inMilliseconds;

        // Calculate crop rect from the event's viewTransform
        final cropRect = clip.cropRegion ??
            (clip.event.viewTransform != null
                ? CropCalculator.transformToCropRect(
                    clip.event.viewTransform!, videoWidth, videoHeight)
                : null);

        // --- Normal-speed clip ---
        final normalPath =
            '${tempDir.path}${Platform.pathSeparator}clip_${i}_normal.mp4';
        tempClipPaths.add(normalPath);

        final baseProgress = segmentIndex / totalSegments;
        final segmentWeight = 1.0 / totalSegments;

        emit(ExportProgress(
          status: ExportStatus.extractingClips,
          currentClipIndex: i,
          totalClips: job.clips.length,
          overallProgress: baseProgress,
          message:
              'Extracting clip ${i + 1}/${job.clips.length}: ${clip.event.label}',
        ));

        final normalArgs = FfmpegCommandBuilder.buildClipArgs(
          inputPath: job.sourceVideoPath,
          outputPath: normalPath,
          startTime: clip.startTime,
          endTime: clip.endTime,
          cropRegion: cropRect,
          fadeDurationSeconds: job.config.fadeDurationSeconds,
          encoder: _detectedEncoder ?? 'libx264',
          outputWidth: videoWidth,
          outputHeight: videoHeight,
          labelText: clip.labelText,
          labelColor: clip.labelColor,
          labelFontFile: fontFile,
          labelSize: job.config.labelSize,
          labelPosition: job.config.labelPosition,
        );

        final normalOk = await _runFfmpeg(
          normalArgs,
          clipDurationMs: clipDurationMs,
          onLog: log,
          onProgress: (fraction, detail) {
            emit(ExportProgress(
              status: ExportStatus.extractingClips,
              currentClipIndex: i,
              totalClips: job.clips.length,
              overallProgress: baseProgress + fraction * segmentWeight,
              message:
                  'Clip ${i + 1}/${job.clips.length}: ${clip.event.label} — '
                  '${(fraction * 100).toInt()}% ($detail)',
            ));
          },
        );
        if (!normalOk) {
          emit(ExportProgress(
            status: ExportStatus.failed,
            errorMessage: 'Failed to extract clip ${i + 1} (${clip.event.label}).',
          ));
          ctrl.close();
          return;
        }
        segmentIndex++;

        // --- Slow-motion replay ---
        if (clip.appendSlowReplay) {
          if (_cancelled) {
            emit(const ExportProgress(
              status: ExportStatus.cancelled,
              message: 'Export cancelled.',
            ));
            ctrl.close();
            return;
          }

          final slowPath =
              '${tempDir.path}${Platform.pathSeparator}clip_${i}_slow.mp4';
          tempClipPaths.add(slowPath);

          final slowBaseProgress = segmentIndex / totalSegments;
          final slowSourceDurationMs =
              (clip.slowEnd - clip.slowStart).inMilliseconds;
          final slowDurationMs =
              (slowSourceDurationMs / job.config.slowReplaySpeed).round();

          emit(ExportProgress(
            status: ExportStatus.extractingClips,
            currentClipIndex: i,
            totalClips: job.clips.length,
            overallProgress: slowBaseProgress,
            message:
                'Creating slow-mo replay for clip ${i + 1}: ${clip.event.label}',
          ));

          final slowArgs = FfmpegCommandBuilder.buildSlowMotionClipArgs(
            inputPath: job.sourceVideoPath,
            outputPath: slowPath,
            startTime: clip.slowStart,
            endTime: clip.slowEnd,
            cropRegion: cropRect,
            speed: job.config.slowReplaySpeed,
            fadeDurationSeconds: job.config.fadeDurationSeconds,
            mute: job.config.muteSlowReplay,
            encoder: _detectedEncoder ?? 'libx264',
            outputWidth: videoWidth,
            outputHeight: videoHeight,
            labelText: clip.labelText,
            labelColor: clip.labelColor,
            labelFontFile: fontFile,
            labelSize: job.config.labelSize,
            labelPosition: job.config.labelPosition,
          );

          final slowOk = await _runFfmpeg(
            slowArgs,
            clipDurationMs: slowDurationMs,
            onLog: log,
            onProgress: (fraction, detail) {
              emit(ExportProgress(
                status: ExportStatus.extractingClips,
                currentClipIndex: i,
                totalClips: job.clips.length,
                overallProgress: slowBaseProgress + fraction * segmentWeight,
                message:
                    'Slow-mo ${i + 1}/${job.clips.length}: ${clip.event.label} — '
                    '${(fraction * 100).toInt()}% ($detail)',
              ));
            },
          );
          if (!slowOk) {
            emit(ExportProgress(
              status: ExportStatus.failed,
              errorMessage:
                  'Failed to create slow-mo for clip ${i + 1} (${clip.event.label}).',
            ));
            ctrl.close();
            return;
          }
          segmentIndex++;
        }
      }

      if (_cancelled) {
        emit(const ExportProgress(
          status: ExportStatus.cancelled,
          message: 'Export cancelled.',
        ));
        ctrl.close();
        return;
      }

      // --- Step 3: Concatenate all segments ---
      if (tempClipPaths.length == 1) {
        emit(const ExportProgress(
          status: ExportStatus.concatenating,
          overallProgress: 0.95,
          message: 'Finalizing…',
        ));
        await File(tempClipPaths.first).copy(job.outputPath);
      } else {
        emit(ExportProgress(
          status: ExportStatus.concatenating,
          overallProgress: 0.9,
          message: 'Concatenating ${tempClipPaths.length} segments…',
        ));

        // All clips are encoded to the same resolution, so concat demuxer
        // with -c copy is safe and near-instant.
        final concatListPath =
            '${tempDir.path}${Platform.pathSeparator}concat.txt';
        await File(concatListPath).writeAsString(
          FfmpegCommandBuilder.buildConcatFileContent(tempClipPaths),
        );

        final concatArgs = FfmpegCommandBuilder.buildConcatArgs(
          concatFilePath: concatListPath,
          outputPath: job.outputPath,
        );

        final concatOk = await _runFfmpeg(concatArgs, onLog: log);
        if (!concatOk) {
          emit(const ExportProgress(
            status: ExportStatus.failed,
            errorMessage: 'Failed to concatenate clips.',
          ));
          ctrl.close();
          return;
        }
      }

      emit(ExportProgress(
        status: ExportStatus.done,
        overallProgress: 1.0,
        message: 'Export complete: ${job.outputPath}',
      ));
    } finally {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      ctrl.close();
    }
  }

  /// Detect the best available H.264 encoder.
  /// Prefers NVENC (NVIDIA GPU) for ~5-10x faster encoding, falls back to libx264.
  Future<String> _detectEncoder() async {
    try {
      final result = await Process.run('ffmpeg', [
        '-f', 'lavfi', '-i', 'nullsrc=s=256x256:d=0.1',
        '-c:v', 'h264_nvenc', '-f', 'null', '-',
      ]);
      if (result.exitCode == 0) return 'h264_nvenc';
    } catch (_) {}
    return 'libx264';
  }

  /// Probe video width and height using ffprobe.
  Future<(int, int)?> _probeVideoDimensions(String inputPath) async {
    try {
      final args = FfmpegCommandBuilder.buildProbeArgs(inputPath);
      final result = await Process.run('ffprobe', args);
      if (result.exitCode != 0) return null;

      final output = (result.stdout as String).trim();
      final parts = output.split(',');
      if (parts.length < 2) return null;

      final width = int.tryParse(parts[0].trim());
      final height = int.tryParse(parts[1].trim());
      if (width == null || height == null) return null;

      return (width, height);
    } catch (e) {
      print('ffprobe error: $e');
      return null;
    }
  }

  /// Run an FFmpeg command and return true if it succeeded.
  ///
  /// [clipDurationMs] — expected output duration in milliseconds. When
  /// provided together with [onProgress], FFmpeg's stderr is parsed in
  /// real-time and the callback is invoked with a 0.0–1.0 fraction.
  ///
  /// IMPORTANT: Both stdout and stderr are always drained to prevent
  /// OS pipe buffer deadlocks.
  Future<bool> _runFfmpeg(
    List<String> args, {
    int? clipDurationMs,
    void Function(double fraction, String detail)? onProgress,
    void Function(String line)? onLog,
  }) async {
    try {
      final logLine = onLog ?? ((_) {});
      logLine('> ffmpeg ${args.join(' ')}');
      _activeProcess = await Process.start('ffmpeg', args);

      // Always drain stdout (FFmpeg rarely writes here, but must be consumed)
      _activeProcess!.stdout.transform(utf8.decoder).listen((_) {});

      // Always drain stderr — parse for progress, log for debugging
      final stderrLines = <String>[];
      _activeProcess!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        stderrLines.add(line);
        logLine(line);

        if (onProgress != null) {
          final timeMatch = RegExp(r'time=(\d+):(\d+):(\d+)\.(\d+)').firstMatch(line);
          if (timeMatch != null) {
            final h = int.parse(timeMatch.group(1)!);
            final m = int.parse(timeMatch.group(2)!);
            final s = int.parse(timeMatch.group(3)!);
            final cs = int.parse(timeMatch.group(4)!);
            final currentMs = ((h * 3600 + m * 60 + s) * 1000 + cs * 10);

            final fraction = clipDurationMs != null && clipDurationMs > 0
                ? (currentMs / clipDurationMs).clamp(0.0, 1.0)
                : 0.0;

            final speedMatch = RegExp(r'speed=\s*([\d.]+)x').firstMatch(line);
            final speed = speedMatch?.group(1) ?? '?';

            onProgress(fraction, 'speed: ${speed}x');
          }
        }
      });

      final exitCode = await _activeProcess!.exitCode;
      _activeProcess = null;

      if (exitCode != 0) {
        final tail = stderrLines.length > 10
            ? stderrLines.sublist(stderrLines.length - 10)
            : stderrLines;
        logLine('FAILED (exit $exitCode). Last output:');
        for (final line in tail) {
          logLine('  $line');
        }
        return false;
      }
      logLine('OK (exit 0)');
      return true;
    } catch (e) {
      (onLog ?? print)('Exception: $e');
      _activeProcess = null;
      return false;
    }
  }

}
