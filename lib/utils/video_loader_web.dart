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

  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? abortSub;
  html.EventListener? focusListener;

  // Complete the future at most once and tear down every listener so a stale
  // handler can never fire against an already-completed completer (which throws
  // "Bad state: Future already completed") or leak across invocations.
  void resolve(String? url) {
    if (completer.isCompleted) return;
    changeSub?.cancel();
    abortSub?.cancel();
    if (focusListener != null) {
      html.window.removeEventListener('focus', focusListener);
    }
    completer.complete(url);
  }

  changeSub = input.onChange.listen((event) {
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      resolve(html.Url.createObjectUrlFromBlob(file));
    } else {
      resolve(null);
    }
  });

  // Handle cancel (user closes dialog without selecting)
  abortSub = input.onAbort.listen((_) => resolve(null));

  // Fallback: if the dialog is dismissed, the window regains focus. Give the
  // change event a moment to arrive first, then resolve as cancelled.
  focusListener = (event) {
    Future.delayed(const Duration(milliseconds: 300), () => resolve(null));
  };
  html.window.addEventListener('focus', focusListener);

  input.click();

  return completer.future;
}
