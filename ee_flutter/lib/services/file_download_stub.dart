import 'dart:typed_data';

void downloadFile({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
}) {
  throw UnsupportedError('La descarga directa solo esta disponible en web.');
}
