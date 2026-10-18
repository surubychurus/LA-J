import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models.dart';
import 'cloudinary.dart';

final _fs = FirebaseFirestore.instance;

/// Próximo sábado a las 14:30 (si ya pasó hoy, el siguiente).
DateTime proximoSabado([DateTime? now]) {
  now ??= DateTime.now();
  var d = DateTime(now.year, now.month, now.day, 14, 30);
  d = d.add(Duration(days: (DateTime.saturday - d.weekday) % 7));
  if (!d.isAfter(now)) d = d.add(const Duration(days: 7));
  return d;
}

class Db {
  // ---- Kuvthzot ----
  static Stream<List<Kuvthza>> kuvthzot() => _fs
      .collection('kuvthzot')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs.map(Kuvthza.fromDoc).toList());

  static Future<void> addKuvthza(String nombre) =>
      _fs.collection('kuvthzot').add({'nombre': nombre.trim()});

  static Future<void> deleteKuvthza(String id) => _fs.collection('kuvthzot').doc(id).delete();

  // ---- Tema del sábado ----
  static Stream<String> temaSabado() => _fs
      .collection('config')
      .doc('sabado')
      .snapshots()
      .map((d) => (d.data()?['tema'] as String?) ?? '');

  static Future<void> setTema(String tema) =>
      _fs.collection('config').doc('sabado').set({'tema': tema.trim()});

  // ---- Anuncios ----
  /// Anuncios visibles para el usuario: generales + los de su kuvthzá
  /// (la Hanagá ve todos).
  static Stream<List<Anuncio>> anuncios(AppUser u) => _fs
      .collection('anuncios')
      .orderBy('fecha', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Anuncio.fromDoc).where((a) {
            if (u.esHanaga || a.kuvthzaId == null) return true;
            return a.kuvthzaId == u.kuvthzaId;
          }).toList());

  /// Crea ([id] nulo) o actualiza una novedad.
  static Future<void> guardarAnuncio(
    AppUser u, {
    String? id,
    required String titulo,
    required String cuerpo,
    required String? kuvthzaId,
    required List<Accion> acciones,
  }) {
    final data = {
      'titulo': titulo.trim(),
      'cuerpo': cuerpo.trim(),
      'kuvthzaId': kuvthzaId,
      'acciones': [for (final a in acciones) a.toMap()],
    };
    final col = _fs.collection('anuncios');
    if (id != null) return col.doc(id).update(data);
    return col.add({
      ...data,
      'autor': u.display,
      'autorUid': u.uid,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> borrarAnuncio(String id) => _fs.collection('anuncios').doc(id).delete();

  // ---- Fotos ----
  static Stream<List<Foto>> fotos() => _fs
      .collection('fotos')
      .orderBy('sabado', descending: true)
      .snapshots()
      .map((s) => s.docs.map(Foto.fromDoc).toList());

  static Future<void> subirFoto(Uint8List bytes, String nombre, bool esVideo, DateTime sabado) async {
    final url = await Cloudinary.subir(bytes, nombre, video: esVideo, carpeta: 'fotos');
    await _fs.collection('fotos').add({
      'url': url,
      'esVideo': esVideo,
      'sabado': Timestamp.fromDate(sabado),
    });
  }

  // ---- Chat ----
  static Stream<List<Mensaje>> mensajes(String room) => _fs
      .collection('chats')
      .doc(room)
      .collection('mensajes')
      .orderBy('fecha', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(Mensaje.fromDoc).toList());

  static Future<void> enviar(String room, AppUser u, String texto) =>
      _fs.collection('chats').doc(room).collection('mensajes').add({
        'uid': u.uid,
        'autor': u.display,
        'texto': texto.trim(),
        'fecha': FieldValue.serverTimestamp(),
      });

  // ---- Usuarios (Hanagá) ----
  static Stream<List<AppUser>> usuarios() => _fs
      .collection('users')
      .orderBy('nombre')
      .snapshots()
      .map((s) => s.docs.map(AppUser.fromDoc).toList());

  /// Un boguer con kuvthzá pasa a ser madrij automáticamente.
  static Future<void> actualizarUsuario(
    AppUser u, {
    required Rol rol,
    required String? kuvthzaId,
    required bool aprobado,
  }) {
    if (rol == Rol.boguer && kuvthzaId != null) rol = Rol.madrij;
    return _fs.collection('users').doc(u.uid).update({
      'rol': rol.name,
      'kuvthzaId': kuvthzaId,
      'aprobado': aprobado,
    });
  }

  static Future<void> actualizarPerfil(String uid, {String? nombre, String? apodo}) =>
      _fs.collection('users').doc(uid).update({
        if (nombre != null) 'nombre': nombre.trim(),
        if (apodo != null) 'apodo': apodo.trim(),
      });

  static Future<void> subirAvatar(String uid, Uint8List bytes) async {
    final url = await Cloudinary.subir(bytes, '$uid.jpg', carpeta: 'avatars');
    await _fs.collection('users').doc(uid).update({'fotoUrl': url});
  }
}
