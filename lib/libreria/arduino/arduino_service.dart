import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models.dart';
import 'arduino_transport.dart';
import 'transport_factory.dart';

enum EstadoArduino { desconectado, conectando, listo, error }

/// Habla con el Arduino: manda líneas de texto (terminadas en \n) y
/// entiende sus respuestas READY / OK / ERR:LCD. Misma lógica que el
/// JavaScript del sistema anterior, pero en Dart.
///
/// Nunca lanza al mandar: si no hay Arduino, solo deja un aviso en [mensaje]
/// para que la venta siga funcionando.
class ArduinoService extends ChangeNotifier {
  ArduinoService({
    ArduinoTransport? transport,
    this.esperaReady = const Duration(seconds: 4),
    this.formatoLibro = _formatoLibroPorDefecto,
  }) : _t = transport ?? crearTransporte();

  /// Línea que se manda al Arduino al mostrar un libro. Si tu sketch espera
  /// otro formato, pasa aquí tu propia función al crear el servicio:
  ///   ArduinoService(formatoLibro: (l) => '${ArduinoService.lcd(l.titulo)}|${l.precio}');
  final String Function(Libro) formatoLibro;

  // Todas las líneas son `arriba|abajo` (fila 1 | fila 2 de la pantalla).
  static String _formatoLibroPorDefecto(Libro l) =>
      '${lcd(l.titulo)}|${l.precio.toStringAsFixed(2)}';

  final ArduinoTransport _t;
  final Duration esperaReady;

  EstadoArduino estado = EstadoArduino.desconectado;
  String mensaje = 'Arduino no conectado.';

  /// Última línea mandada / recibida (para diagnosticar la pantalla).
  String? ultimoEnviado;
  String? ultimoRecibido;

  StreamSubscription<dynamic>? _subDatos;
  StreamSubscription<void>? _subDesc;
  Timer? _timerReady;
  String _pendiente = '';
  bool _desenchufado = false;

  bool get soportado => _t.soportado;
  bool get conectado =>
      estado == EstadoArduino.listo || estado == EstadoArduino.conectando;

  void _set(EstadoArduino e, String m) {
    estado = e;
    mensaje = m;
    notifyListeners();
  }

  /// Se hace UNA vez al empezar la jornada. En web debe venir de un clic.
  Future<void> conectar() async {
    if (!_t.soportado) {
      _set(EstadoArduino.error,
          'Esta plataforma no puede usar el puerto serie. En web abre la página en Chrome o Edge de escritorio; en Android usa un cable OTG.');
      return;
    }
    await _soltar();
    _desenchufado = false;
    _set(EstadoArduino.conectando, 'Conectando...');
    try {
      await _t.abrir(baudRate: 9600);
    } catch (e) {
      await _soltar();
      _set(EstadoArduino.error, 'No se pudo conectar: $e. Elige el puerto del Arduino.');
      return;
    }
    _subDatos = _t.datos.listen(_alRecibir);
    _subDesc = _t.desconexion.listen((_) => _alDesconectar());
    // Al abrir el puerto el Uno se reinicia (~2 s) y avisa con READY.
    _set(EstadoArduino.conectando, 'Conectando... el Arduino se está reiniciando (2 segundos).');
    _timerReady = Timer(esperaReady, () {
      if (estado == EstadoArduino.conectando) {
        _set(EstadoArduino.listo, 'Arduino conectado (no confirmó READY).');
      }
    });
  }

  Future<void> desconectar() async {
    await _soltar();
    _set(EstadoArduino.desconectado, 'Arduino no conectado.');
  }

  void _alRecibir(List<int> bytes) {
    _pendiente += utf8.decode(bytes, allowMalformed: true);
    int corte;
    while ((corte = _pendiente.indexOf('\n')) >= 0) {
      final linea = _pendiente.substring(0, corte).trim();
      _pendiente = _pendiente.substring(corte + 1);
      _procesar(linea);
    }
  }

  void _procesar(String linea) {
    if (linea.isNotEmpty) {
      ultimoRecibido = linea;
      notifyListeners();
    }
    if (linea == 'READY' || linea == 'OK') {
      _timerReady?.cancel();
      if (estado != EstadoArduino.listo || mensaje != 'Arduino conectado. Ya se puede escanear.') {
        _set(EstadoArduino.listo, 'Arduino conectado. Ya se puede escanear.');
      }
    } else if (linea == 'ERR:LCD') {
      _set(EstadoArduino.error,
          'El Arduino funciona pero NO detecta la pantalla LCD. Revisa el cableado.');
    }
  }

  // Si pasa justo al escanear, casi siempre es falta de corriente: el Arduino
  // prende LED, zumbador y pantalla a la vez y la placa se apaga un instante.
  void _alDesconectar() {
    _desenchufado = true;
    _soltar();
    _set(EstadoArduino.error,
        'Se dejó de ver el Arduino por USB: se desenchufó, o se apagó un instante por falta de corriente. Vuelve a conectar.');
  }

  /// Manda una línea cruda. Devuelve false si no se pudo (sin lanzar).
  Future<bool> enviar(String linea) async {
    if (!conectado) {
      _set(EstadoArduino.error,
          'Acción registrada, pero el Arduino no está conectado. Pulsa "Conectar Arduino".');
      return false;
    }
    try {
      await _t.escribir(Uint8List.fromList(utf8.encode('$linea\n')));
      ultimoEnviado = linea;
      notifyListeners();
      return true;
    } catch (e) {
      final desenchufado = _desenchufado;
      await _soltar();
      if (!desenchufado) {
        _set(EstadoArduino.error, 'No se pudo mandar al Arduino ($e). Vuelve a conectar.');
      }
      return false;
    }
  }

  // ---- Mensajes de la librería ----
  // Para cambiar el formato que entiende tu sketch, edita SOLO estas funciones.

  /// `titulo|precio`  (título arriba, precio abajo; sin stock)
  Future<bool> mostrarLibro(Libro l) => enviar(formatoLibro(l));

  /// `TOTAL|monto`
  Future<bool> mostrarTotal(double total) => enviar('TOTAL|${total.toStringAsFixed(2)}');

  /// `GRACIAS|monto`
  Future<bool> ventaCobrada(double total) => enviar('GRACIAS|${total.toStringAsFixed(2)}');

  /// `texto|` (solo la fila de arriba)
  Future<bool> mostrarMensaje(String texto) => enviar('${lcd(texto)}|');

  /// Texto seguro para una LCD: sin tildes, sin el separador `|`, ni saltos de línea.
  static String lcd(String s, [int max = 16]) {
    const de = 'áàäâãéèëêíìïîóòöôõúùüûñçÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑÇ';
    const a = 'aaaaaeeeeiiiiooooouuuuncAAAAAEEEEIIIIOOOOOUUUUNC';
    final b = StringBuffer();
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      final i = de.indexOf(c);
      b.write(i >= 0 ? a[i] : c);
    }
    var t = b.toString().replaceAll(RegExp(r'[|\r\n]'), ' ').trim();
    if (t.length > max) t = t.substring(0, max);
    return t;
  }

  Future<void> _soltar() async {
    _timerReady?.cancel();
    _timerReady = null;
    await _subDatos?.cancel();
    await _subDesc?.cancel();
    _subDatos = null;
    _subDesc = null;
    _pendiente = '';
    await _t.cerrar();
  }

  @override
  void dispose() {
    _soltar();
    super.dispose();
  }
}
