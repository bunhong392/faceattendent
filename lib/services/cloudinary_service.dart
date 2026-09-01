import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Uploads face reference photos to Cloudinary instead of Firebase Storage.
///
/// Uses an **unsigned upload preset**, which is the only safe way to upload
/// directly from a mobile client: your Cloudinary API secret never ships in
/// the app. Configure the preset in the Cloudinary dashboard (see README,
/// "Cloudinary setup") before this will work — [cloudName] and
/// [uploadPreset] below are placeholders.
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // TODO: replace with your own values from the Cloudinary dashboard.
  static const String cloudName = 'YOUR_CLOUD_NAME';
  static const String uploadPreset = 'YOUR_UNSIGNED_UPLOAD_PRESET';

  Uri get _uploadUri => Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

  /// Uploads [file] and returns its `secure_url`.
  ///
  /// [publicId] pins the asset to a stable name (e.g. `face_profiles/{uid}`)
  /// so re-registering a face overwrites the previous photo instead of
  /// piling up new ones every time. For that to actually overwrite, the
  /// preset must have **Unique filename: off** and **Overwrite: on** set in
  /// the Cloudinary dashboard — see README.
  Future<String> uploadImage(File file, {required String publicId}) async {
    final request = http.MultipartRequest('POST', _uploadUri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = publicId
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['secure_url'] as String;
  }
}
