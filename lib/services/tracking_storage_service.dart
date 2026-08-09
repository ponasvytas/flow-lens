import 'dart:convert';
import '../utils/app_log.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../utils/file_saver.dart';

class TrackingStorageService {
  /// Prompts user to save a tracking session to a JSON file.
  Future<void> saveSession(TrackingSession session) async {
    if (session.events.isEmpty && session.subjects.isEmpty) return;

    try {
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(session.toJson());

      if (!kIsWeb) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Tracking Session',
          fileName: 'tracking_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          if (!outputFile.endsWith('.json')) {
            outputFile += '.json';
          }
          final file = File(outputFile);
          await file.writeAsString(jsonString);
          AppLog.debug('Tracking session saved to $outputFile');
        }
      } else {
        final fileName =
            'tracking_${DateTime.now().millisecondsSinceEpoch}.json';
        await saveTextFile(jsonString, fileName);
        AppLog.debug('Tracking session download triggered for $fileName');
      }
    } catch (e) {
      AppLog.debug('Error saving tracking session: $e');
      rethrow;
    }
  }

  /// Prompts user to load a tracking session from a JSON file.
  Future<TrackingSession?> loadSession() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        String content;

        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) return null;
          content = utf8.decode(bytes);
        } else {
          final path = result.files.single.path;
          if (path == null) return null;
          final file = File(path);
          content = await file.readAsString();
        }

        final json = jsonDecode(content) as Map<String, dynamic>;
        return TrackingSession.fromJson(json);
      }
    } catch (e) {
      AppLog.debug('Error loading tracking session: $e');
      rethrow;
    }
    return null;
  }

  /// Export tracking data as a flat CSV for external analysis.
  /// Each row is one [TrackingEvent] with subject/tracker labels resolved.
  Future<void> exportCsv(TrackingSession session) async {
    if (session.events.isEmpty) return;

    try {
      final subjectMap = {for (final s in session.subjects) s.id: s.label};
      final trackerMap = {for (final t in session.trackers) t.id: t.label};

      // Build a lookup of the most recent timerStart timestamp per
      // subject+tracker so we can compute interval durations on timerStop.
      final timerStarts = <String, Duration>{};

      final buffer = StringBuffer();
      buffer.writeln(
        'event_id,timestamp_ms,subject_id,subject_label,tracker_id,tracker_label,action,value',
      );

      for (final event in session.events) {
        final subjectLabel = subjectMap[event.subjectId] ?? event.subjectId;
        final trackerLabel = trackerMap[event.trackerId] ?? event.trackerId;
        final pairKey = '${event.subjectId}:${event.trackerId}';

        // Compute the value column
        String value;
        switch (event.action) {
          case TrackingAction.increment:
          case TrackingAction.decrement:
            value = '${event.delta}';
            break;
          case TrackingAction.timerStart:
            timerStarts[pairKey] = event.timestamp;
            value = '';
            break;
          case TrackingAction.timerStop:
            final start = timerStarts.remove(pairKey);
            if (start != null) {
              value = '${(event.timestamp - start).inMilliseconds}';
            } else {
              value = '';
            }
            break;
          case TrackingAction.timerCancel:
            timerStarts.remove(pairKey);
            value = '';
            break;
        }

        buffer.writeln(
          '${event.id},'
          '${event.timestamp.inMilliseconds},'
          '${event.subjectId},'
          '"$subjectLabel",'
          '${event.trackerId},'
          '"$trackerLabel",'
          '${event.action.name},'
          '$value',
        );
      }

      final csvString = buffer.toString();

      if (!kIsWeb) {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Export Tracking CSV',
          fileName: 'tracking_${DateTime.now().millisecondsSinceEpoch}.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          if (!outputFile.endsWith('.csv')) {
            outputFile += '.csv';
          }
          final file = File(outputFile);
          await file.writeAsString(csvString);
          AppLog.debug('Tracking CSV exported to $outputFile');
        }
      } else {
        final fileName =
            'tracking_${DateTime.now().millisecondsSinceEpoch}.csv';
        await saveTextFile(csvString, fileName);
        AppLog.debug('Tracking CSV download triggered for $fileName');
      }
    } catch (e) {
      AppLog.debug('Error exporting tracking CSV: $e');
      rethrow;
    }
  }
}
