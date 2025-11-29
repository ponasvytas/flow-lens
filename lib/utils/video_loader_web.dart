import 'dart:html' as html;

Future<String?> getUrlFromBytes(List<int> bytes) async {
  final blob = html.Blob([bytes]);
  return html.Url.createObjectUrlFromBlob(blob);
}
