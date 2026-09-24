// `dart:html` remains the stable browser download API for this Flutter target.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

void downloadFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mimeType));
  html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none'
    ..click();
  html.Url.revokeObjectUrl(url);
}
