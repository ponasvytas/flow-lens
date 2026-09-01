import 'dart:convert';

class SessionAccessException implements Exception {
  const SessionAccessException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionSizeException implements Exception {
  const SessionSizeException(this.sizeBytes, this.maximumBytes);

  final int sizeBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'Session is too large to save ($sizeBytes bytes; maximum $maximumBytes).';
}

class SessionDocumentSize {
  const SessionDocumentSize._();

  static const maximumBytes = 750 * 1024;

  static void validate(Map<String, dynamic> content) {
    final size = utf8.encode(jsonEncode(content)).length;
    if (size > maximumBytes) {
      throw SessionSizeException(size, maximumBytes);
    }
  }
}
