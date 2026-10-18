import 'package:cloud_firestore/cloud_firestore.dart';

enum Rol { janij, boguer, madrij, hanaga }

extension RolX on Rol {
  String get label => switch (this) {
        Rol.janij => 'Janij',
        Rol.boguer => 'Boguer',
        Rol.madrij => 'Madrij',
        Rol.hanaga => 'Hanagá',
      };
  static Rol parse(String? s) =>
      Rol.values.firstWhere((r) => r.name == s, orElse: () => Rol.janij);
}

class Kuvthza {
  final String id;
  final String nombre;
  Kuvthza(this.id, this.nombre);
  factory Kuvthza.fromDoc(DocumentSnapshot d) =>
      Kuvthza(d.id, (d.data() as Map)['nombre'] ?? '');
}

class AppUser {
  final String uid;
  final String email;
  final String nombre;
  final String apodo;
  final Rol rol;
  final String? kuvthzaId;
  final bool aprobado;
  final String? fotoUrl;

  AppUser({
    required this.uid,
    required this.email,
    required this.nombre,
    required this.apodo,
    required this.rol,
    required this.kuvthzaId,
    required this.aprobado,
    this.fotoUrl,
  });

  factory AppUser.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return AppUser(
      uid: d.id,
      email: m['email'] ?? '',
      nombre: m['nombre'] ?? '',
      apodo: m['apodo'] ?? '',
      rol: RolX.parse(m['rol']),
      kuvthzaId: m['kuvthzaId'],
      aprobado: m['aprobado'] ?? false,
      fotoUrl: m['fotoUrl'],
    );
  }

  String get display => apodo.isNotEmpty ? apodo : nombre;

  bool get esStaff => rol == Rol.madrij || rol == Rol.hanaga;
  bool get esHanaga => rol == Rol.hanaga;

  /// Puede publicar anuncios: madrij (solo su kuvthza) y hanaga (todos).
  bool get puedePublicar => esStaff;

  /// Madrij y Hanagá suben fotos/videos.
  bool get puedeSubirFotos => esStaff;
}

class Anuncio {
  final String id;
  final String titulo;
  final String cuerpo;
  final DateTime fecha;
  final String? kuvthzaId; // null = general
  final String autor;
  Anuncio(this.id, this.titulo, this.cuerpo, this.fecha, this.kuvthzaId, this.autor);

  factory Anuncio.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Anuncio(
      d.id,
      m['titulo'] ?? '',
      m['cuerpo'] ?? '',
      (m['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      m['kuvthzaId'],
      m['autor'] ?? '',
    );
  }
}

class Foto {
  final String id;
  final String url;
  final bool esVideo;
  final DateTime sabado;
  Foto(this.id, this.url, this.esVideo, this.sabado);

  factory Foto.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Foto(
      d.id,
      m['url'] ?? '',
      m['esVideo'] ?? false,
      (m['sabado'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Mensaje {
  final String id;
  final String uid;
  final String autor;
  final String texto;
  final DateTime fecha;
  Mensaje(this.id, this.uid, this.autor, this.texto, this.fecha);

  factory Mensaje.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return Mensaje(
      d.id,
      m['uid'] ?? '',
      m['autor'] ?? '',
      m['texto'] ?? '',
      (m['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class ChatRoom {
  final String id;
  final String titulo;
  final String subtitulo;
  ChatRoom(this.id, this.titulo, this.subtitulo);
}

/// Chats a los que tiene acceso cada rol.
List<ChatRoom> chatsFor(AppUser u, List<Kuvthza> kuvthzot) {
  final k = kuvthzot.where((e) => e.id == u.kuvthzaId).firstOrNull;
  final rooms = <ChatRoom>[];
  switch (u.rol) {
    case Rol.janij:
      if (k != null) rooms.add(ChatRoom('k_${k.id}', k.nombre, 'Chat de tu kuvthzá'));
    case Rol.boguer:
      rooms.addAll([
        ChatRoom('bogrut', 'Bogrut', 'Todos los bogrim'),
        ChatRoom('banquito', 'Banquito', 'Chat del banquito'),
      ]);
    case Rol.madrij:
      if (k != null) {
        rooms.add(ChatRoom('k_${k.id}', k.nombre, 'Kuvthzá completa'));
        rooms.add(ChatRoom('km_${k.id}', '${k.nombre} · Madrijim', 'Solo madrijim'));
      }
      rooms.add(ChatRoom('bogrut', 'Bogrut', 'Todos los bogrim'));
    case Rol.hanaga:
      rooms.addAll([
        ChatRoom('bogrut', 'Bogrut', 'Todos los bogrim'),
        ChatRoom('banquito', 'Banquito', 'Chat del banquito'),
        ChatRoom('hanaga', 'Hanagá', 'Solo la Hanagá'),
      ]);
  }
  return rooms;
}
