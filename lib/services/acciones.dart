import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models.dart';

/// Ejecuta el botón de una novedad. Devuelve false si no se pudo abrir.
Future<bool> ejecutarAccion(Accion a, Anuncio n) {
  final v = a.valor.trim();
  Uri? uri;
  switch (a.tipo) {
    case TipoAccion.enlace:
      uri = Uri.tryParse(v.startsWith('http') ? v : 'https://$v');
    case TipoAccion.llamar:
      uri = Uri(scheme: 'tel', path: v.replaceAll(' ', ''));
    case TipoAccion.whatsapp:
      uri = Uri.parse('https://wa.me/${v.replaceAll(RegExp(r'[^0-9]'), '')}');
    case TipoAccion.mapa:
      uri = Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': v});
    case TipoAccion.calendario:
      final ini = a.inicio;
      if (ini == null) return Future.value(false);
      final fin = a.fin ?? ini.add(const Duration(hours: 1));
      final f = DateFormat("yyyyMMdd'T'HHmmss'Z'");
      // Plantilla de Google Calendar: funciona en web y en el celular.
      uri = Uri.https('calendar.google.com', '/calendar/render', {
        'action': 'TEMPLATE',
        'text': n.titulo,
        'details': n.cuerpo,
        'dates': '${f.format(ini.toUtc())}/${f.format(fin.toUtc())}',
        if (v.isNotEmpty) 'location': v,
      });
  }
  if (uri == null) return Future.value(false);
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
