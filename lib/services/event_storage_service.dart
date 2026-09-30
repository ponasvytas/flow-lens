import 'dart:convert';
import '../utils/app_log.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/game_event.dart';
import '../utils/file_saver.dart';

class EventImportExportService {
  /// Prompts user to save events to a JSON file
  Future<void> saveEvents(List<GameEvent> events) async {
    if (events.isEmpty) return;

    try {
      // Convert events to JSON
      final jsonList = events.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      if (!kIsWeb) {
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Save Events Timeline',
          fileName: 'events_${DateTime.now().millisecondsSinceEpoch}.json',
          bytes: Uint8List.fromList(utf8.encode(jsonString)),
          mimeType: 'application/json',
        );

        if (outputFile != null) {
          AppLog.debug('Events saved to $outputFile');
        }
      } else {
        // Web implementation: Trigger download
        final fileName = 'events_${DateTime.now().millisecondsSinceEpoch}.json';
        await saveTextFile(jsonString, fileName);
        AppLog.debug('Events download triggered for $fileName');
      }
    } catch (e) {
      AppLog.debug('Error saving events: $e');
      rethrow;
    }
  }

  /// Prompts user to load events from a JSON file
  Future<List<GameEvent>> loadEvents() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final content = utf8.decode(await result.readAsBytes());

        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((json) => GameEvent.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      AppLog.debug('Error loading events: $e');
      rethrow;
    }
    return [];
  }
}

@Deprecated(
  'Use EventImportExportService; this service is not durable storage.',
)
typedef EventStorageService = EventImportExportService;
