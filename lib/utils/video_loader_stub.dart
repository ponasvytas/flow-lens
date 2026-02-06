Future<String?> getUrlFromBytes(List<int> bytes) async {
  throw UnsupportedError('Cannot create URL from bytes on native platforms');
}

Future<String?> createUrlFromPlatformFile(dynamic platformFile) async {
  throw UnsupportedError(
    'Cannot create URL from platform file on native platforms',
  );
}

String? createUrlFromHtmlFile(dynamic file) {
  throw UnsupportedError(
    'Cannot create URL from HTML file on native platforms',
  );
}

Future<String?> pickVideoFileWeb() async {
  throw UnsupportedError('Web video picker not available on native platforms');
}
