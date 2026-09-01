import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

final Set<String> _ownedVideoUrls = <String>{};

String _own(String url) {
  _ownedVideoUrls.add(url);
  return url;
}

Future<String?> pickVideoFileWeb() async {
  final completer = Completer<String?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'video/*';

  late final JSFunction changeListener;
  late final JSFunction abortListener;
  late final JSFunction focusListener;

  void resolve(String? url) {
    if (completer.isCompleted) return;
    input.removeEventListener('change', changeListener);
    input.removeEventListener('abort', abortListener);
    web.window.removeEventListener('focus', focusListener);
    completer.complete(url);
  }

  changeListener = ((web.Event event) {
    final files = input.files;
    if (files != null && files.length > 0) {
      resolve(_own(web.URL.createObjectURL(files.item(0)!)));
    } else {
      resolve(null);
    }
  }).toJS;
  abortListener = ((web.Event event) => resolve(null)).toJS;
  focusListener = ((web.Event event) {
    Timer(const Duration(milliseconds: 300), () => resolve(null));
  }).toJS;

  input.addEventListener('change', changeListener);
  input.addEventListener('abort', abortListener);
  web.window.addEventListener('focus', focusListener);
  input.click();
  return completer.future;
}

void releaseVideoUrl(String? url) {
  if (url == null || !_ownedVideoUrls.remove(url)) return;
  web.URL.revokeObjectURL(url);
}

bool isOwnedVideoUrl(String url) => _ownedVideoUrls.contains(url);
