import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Subida de archivos a Cloudinary con un "unsigned upload preset": no hay
/// ningún secreto dentro de la app. Completá estos dos valores desde el
/// panel de Cloudinary (Dashboard → Cloud name; Settings → Upload → Upload
/// presets → crear uno con "Signing mode: Unsigned").
const cloudinaryCloudName = 'df0wlzkne';
const cloudinaryUploadPreset = 'JH2214';

class Cloudinary {
  /// Sube [bytes] y devuelve la URL https del archivo.
  static Future<String> subir(Uint8List bytes, String nombre,
      {bool video = false, String? carpeta}) async {
    final tipo = video ? 'video' : 'image';
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudinaryCloudName/$tipo/upload'),
    )
      ..fields['upload_preset'] = cloudinaryUploadPreset
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: nombre));
    if (carpeta != null) req.fields['folder'] = carpeta;

    final res = await http.Response.fromStream(await req.send());
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(json['error']?['message'] ?? 'Error al subir el archivo');
    }
    return json['secure_url'] as String;
  }
}
