import 'dart:async';
import 'dart:convert';
import 'export_models.dart';
import 'export_service.dart';

/// Web implementation — exports an EDL (Edit Decision List) as JSON.
///
/// Server-side FFmpeg for premium users is planned for a future release.
class ExportServiceImpl implements ExportService {
  @override
  Future<bool> isFfmpegAvailable() async => false;

  @override
  void cancel() {
    // No-op on web.
  }

  @override
  Stream<ExportProgress> export(ExportJob job) async* {
    yield const ExportProgress(
      status: ExportStatus.failed,
      errorMessage:
          'Client-side video export is not available on web.\n'
          'Use "Download EDL" to export an edit decision list,\n'
          'or upgrade to Premium for server-side export.',
    );
  }

  /// Generate an EDL JSON string that can be imported into video editors
  /// or sent to a server-side FFmpeg endpoint.
  static String generateEdl(ExportJob job) {
    final clips = job.clips.map((clip) {
      return {
        'label': clip.event.label,
        'detail': clip.event.detail,
        'grade': clip.event.grade?.name,
        'startMs': clip.startTime.inMilliseconds,
        'endMs': clip.endTime.inMilliseconds,
        'cropRegion': clip.cropRegion != null
            ? {
                'x': clip.cropRegion!.left,
                'y': clip.cropRegion!.top,
                'width': clip.cropRegion!.width,
                'height': clip.cropRegion!.height,
              }
            : null,
        'viewTransform': clip.event.viewTransform?.storage.toList(),
        'appendSlowReplay': clip.appendSlowReplay,
        'slowStartMs': clip.slowStart.inMilliseconds,
        'slowEndMs': clip.slowEnd.inMilliseconds,
      };
    }).toList();

    final edl = {
      'version': 1,
      'sourceVideo': job.sourceVideoPath,
      'config': {
        'easeInSeconds': job.config.easeInSeconds,
        'easeOutSeconds': job.config.easeOutSeconds,
        'slowReplaySpeed': job.config.slowReplaySpeed,
        'slowMoEaseInSeconds': job.config.slowMoEaseInSeconds,
        'slowMoEaseOutSeconds': job.config.slowMoEaseOutSeconds,
        'muteSlowReplay': job.config.muteSlowReplay,
        'fadeDurationSeconds': job.config.fadeDurationSeconds,
        'outputFormat': job.config.outputFormat,
      },
      'clips': clips,
    };

    return const JsonEncoder.withIndent('  ').convert(edl);
  }
}
