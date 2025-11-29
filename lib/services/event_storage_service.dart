import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/game_event.dart';
import '../utils/file_saver.dart';

class EventStorageService {
  /// Prompts user to save events to a JSON file
  Future<void> saveEvents(List<GameEvent> events) async {
    if (events.isEmpty) return;

    try {
      // Convert events to JSON
      final jsonList = events.map((e) => e.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      if (!kIsWeb) {
        // Desktop/Mobile: Pick a location to save
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Events Timeline',
          fileName: 'events_${DateTime.now().millisecondsSinceEpoch}.json',
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          // Ensure extension
          if (!outputFile.endsWith('.json')) {
            outputFile += '.json';
          }

          final file = File(outputFile);
          await file.writeAsString(jsonString);
          print('Events saved to $outputFile');
        }
      } else {
        // Web implementation: Trigger download
        final fileName = 'events_${DateTime.now().millisecondsSinceEpoch}.json';
        await saveTextFile(jsonString, fileName);
        print('Events download triggered for $fileName');
      }
    } catch (e) {
      print('Error saving events: $e');
      rethrow;
    }
  }

  /// Prompts user to load events from a JSON file
  Future<List<GameEvent>> loadEvents() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        String content;

        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes == null) return [];
          content = utf8.decode(bytes);
        } else {
          final path = result.files.single.path;
          if (path == null) return [];
          final file = File(path);
          content = await file.readAsString();
        }

        final List<dynamic> jsonList = jsonDecode(content);
        return jsonList
            .map((json) => GameEvent.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading events: $e');
      rethrow;
    }
    return [];
  }
}
