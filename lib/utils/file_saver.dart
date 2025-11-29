import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    as impl;

Future<void> saveTextFile(String content, String fileName) =>
    impl.saveTextFile(content, fileName);
