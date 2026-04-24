import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String?> getUrlFromBytes(List<int> bytes) async {
  final uint8List = Uint8List.fromList(bytes);
  final blob = web.Blob(<JSAny>[uint8List.toJS].toJS);
  return web.URL.createObjectURL(blob);
}

/// Creates a blob URL directly from the browser's native File object.
/// This avoids loading the entire file into Dart memory, allowing large files (>2GB).
Future<String?> createUrlFromPlatformFile(dynamic platformFile) async {
  // Not used in the new approach
  return null;
}

/// Creates a blob URL from an HTML File input element's file.
String? createUrlFromHtmlFile(dynamic file) {
  if (file == null) return null;
  try {
    return web.URL.createObjectURL(file as web.Blob);
  } catch (_) {
    return null;
  }
}

/// Pick a video file using native HTML file input and return a blob URL.
/// This avoids loading the file into memory, allowing files >2GB.
Future<String?> pickVideoFileWeb() async {
  final completer = Completer<String?>();

  final input = web.document.createElement('input') as web.HTMLInputElement;
  input.type = 'file';
  input.accept = 'video/*';

  input.addEventListener(
    'change',
    (web.Event event) {
      final files = input.files;
      if (files != null && files.length > 0) {
        final file = files.item(0);
        if (file != null) {
          final url = web.URL.createObjectURL(file);
          completer.complete(url);
        } else {
          completer.complete(null);
        }
      } else {
        completer.complete(null);
      }
    }.toJS,
  );

  // Also handle if user doesn't select anything (cancel)
  web.window.addEventListener(
    'focus',
    (web.Event event) {
      // Give a small delay for the file dialog result
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });
    }.toJS,
  );

  input.click();

  return completer.future;
}
