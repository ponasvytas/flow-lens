import 'video_loader_stub.dart'
    if (dart.library.html) 'video_loader_web.dart'
    as impl;

Future<String?> createUrlFromBytes(List<int> bytes) =>
    impl.getUrlFromBytes(bytes);

Future<String?> createUrlFromPlatformFile(dynamic platformFile) =>
    impl.createUrlFromPlatformFile(platformFile);

String? createUrlFromHtmlFile(dynamic file) => impl.createUrlFromHtmlFile(file);

/// Pick a video file using native HTML file input (web only).
/// Returns a blob URL that can be used directly without loading file into memory.
Future<String?> pickVideoFileWeb() => impl.pickVideoFileWeb();
