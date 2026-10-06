import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/tracking_template.dart';
import '../utils/file_saver.dart';

class TrackingTemplateImportExportService {
  Future<TrackingTemplate?> importTemplate() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > 1024 * 1024) {
      throw const FormatException('Template files must be smaller than 1 MB.');
    }
    return TrackingTemplate.fromJson(
      Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map),
    );
  }

  Future<void> exportTemplate(TrackingTemplate template) async {
    final json = const JsonEncoder.withIndent('  ').convert(template.toJson());
    final name =
        'tracking_template_${DateTime.now().millisecondsSinceEpoch}.json';
    if (kIsWeb) {
      await saveTextFile(json, name);
    } else {
      await FilePicker.saveFile(
        dialogTitle: 'Export tracking template',
        fileName: name,
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
    }
  }
}
