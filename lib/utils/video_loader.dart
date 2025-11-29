import 'video_loader_stub.dart'
    if (dart.library.html) 'video_loader_web.dart'
    as impl;

Future<String?> createUrlFromBytes(List<int> bytes) =>
    impl.getUrlFromBytes(bytes);
