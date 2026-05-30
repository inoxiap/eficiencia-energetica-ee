import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryUpload {
  const CloudinaryUpload({required this.secureUrl, required this.publicId});

  final String secureUrl;
  final String publicId;
}

class CloudinaryService {
  static const cloudName = 'dovufh5wv';
  static const uploadPreset = 'ee_evidencias_unsigned';
  static const endpoint =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static const uploadTimeout = Duration(seconds: 45);

  Future<CloudinaryUpload> uploadEvidence({
    required Uint8List bytes,
    required String reportId,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(endpoint));
    request.fields['upload_preset'] = uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'ee_evidencia_$reportId.jpg',
      ),
    );

    final response = await request.send().timeout(uploadTimeout);
    final body = await response.stream.bytesToString();
    final payload = _decodeJson(body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = payload['error'];
      final message = error is Map<String, dynamic>
          ? error['message'] as String?
          : null;
      throw Exception(message ?? 'Cloudinary no acepto la evidencia.');
    }

    final secureUrl = payload['secure_url'] as String?;
    final publicId = payload['public_id'] as String?;
    if (secureUrl == null || publicId == null) {
      throw Exception('Cloudinary respondio sin URL segura o public ID.');
    }

    return CloudinaryUpload(secureUrl: secureUrl, publicId: publicId);
  }

  Map<String, dynamic> _decodeJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return {};
    }
    return {};
  }
}
