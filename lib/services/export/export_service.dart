import 'dart:async';
import 'export_models.dart';
import 'export_service_stub.dart'
    if (dart.library.io) 'export_service_native.dart'
    as impl;

/// Abstract interface for video export.
///
/// Platform-specific implementations handle the actual encoding:
/// - Native (desktop/mobile): FFmpeg via Process.run
/// - Web: EDL JSON download (server-side FFmpeg for premium — future)
abstract class ExportService {
  /// Factory constructor that returns the platform-appropriate implementation.
  factory ExportService() = impl.ExportServiceImpl;

  /// Start an export job. Returns a stream of progress updates.
  Stream<ExportProgress> export(ExportJob job);

  /// Cancel a running export.
  void cancel();

  /// Check whether FFmpeg is available on this platform.
  Future<bool> isFfmpegAvailable();
}
