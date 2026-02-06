import 'dart:async';
import 'dart:html' as html;

Future<String?> getUrlFromBytes(List<int> bytes) async {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Creates a blob URL directly from the browser's native File object.
/// This avoids loading the entire file into Dart memory, allowing large files (>2GB).
Future<String?> createUrlFromPlatformFile(dynamic platformFile) async {
  // Not used in the new approach
  return null;
}

/// Creates a blob URL from an HTML File input element's file.
String? createUrlFromHtmlFile(dynamic file) {
  if (file is html.File) {
    return html.Url.createObjectUrlFromBlob(file);
  }
  return null;
}

/// Pick a video file using native HTML file input and return a blob URL.
/// This avoids loading the file into memory, allowing files >2GB.
Future<String?> pickVideoFileWeb() async {
  final completer = Completer<String?>();

  final input = html.FileUploadInputElement()..accept = 'video/*';

  input.onChange.listen((event) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final url = html.Url.createObjectUrlFromBlob(file);
      completer.complete(url);
    } else {
      completer.complete(null);
    }
  });

  // Handle cancel (user closes dialog without selecting)
  input.onAbort.listen((_) => completer.complete(null));

  // Also handle if user doesn't select anything
  html.window.addEventListener('focus', (event) {
    // Give a small delay for the file dialog result
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
  });

  input.click();

  return completer.future;
}
