Future<String?> pickVideoFileWeb() async {
  throw UnsupportedError('Web video picker not available on native platforms');
}

void releaseVideoUrl(String? url) {}

bool isOwnedVideoUrl(String url) => false;

String? videoFileIdentity(String url) => null;
