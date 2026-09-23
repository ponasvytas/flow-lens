import 'video_loader_stub.dart'
    if (dart.library.js_interop) 'video_loader_web.dart'
    as impl;

/// Pick a video file using native HTML file input (web only).
/// Returns a blob URL that can be used directly without loading file into memory.
Future<String?> pickVideoFileWeb() => impl.pickVideoFileWeb();

/// Releases [url] only when it is an object URL created by this loader.
void releaseVideoUrl(String? url) => impl.releaseVideoUrl(url);

bool isOwnedVideoUrl(String url) => impl.isOwnedVideoUrl(url);

String? videoFileIdentity(String url) => impl.videoFileIdentity(url);
