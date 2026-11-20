import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lector de códigos de barras USB / Bluetooth en modo "teclado" (el más común).
///
/// El lector "teclea" el código muy rápido y termina con Enter. Esta clase
/// escucha el teclado a nivel global (sin necesitar un campo enfocado), junta
/// las teclas que llegan seguidas y, al recibir Enter, llama a [alLeer].
/// Una persona escribiendo no se confunde con un lector: entre tecla y tecla
/// pasa más de [maxEntreTeclas].
///
/// Si hay un campo de texto enfocado se deja que el campo reciba el código
/// normalmente (útil para el buscador o el formulario) y no se dispara [alLeer].
class LectorUsb {
  LectorUsb({
    required this.alLeer,
    this.maxEntreTeclas = const Duration(milliseconds: 100),
    this.largoMinimo = 6,
    DateTime Function()? reloj,
  }) : _reloj = reloj ?? DateTime.now;

  final void Function(String codigo) alLeer;
  final Duration maxEntreTeclas;
  final int largoMinimo;
  final DateTime Function() _reloj;

  final StringBuffer _buf = StringBuffer();
  DateTime? _ultima;

  void activar() => HardwareKeyboard.instance.addHandler(_alTecla);
  void desactivar() => HardwareKeyboard.instance.removeHandler(_alTecla);

  bool _alTecla(KeyEvent e) {
    if (e is! KeyDownEvent) return false;
    if (_enCampoDeTexto()) {
      _buf.clear();
      return false;
    }
    final k = e.logicalKey;
    final fin = k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.tab;
    procesar(caracter: e.character, esFin: fin);
    return false; // no se consume: el resto de la app sigue viendo la tecla
  }

  bool _enCampoDeTexto() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  /// Lógica pura (se prueba sin teclado). Devuelve true si emitió un código.
  bool procesar({String? caracter, bool esFin = false}) {
    final ahora = _reloj();
    final lento = _ultima != null && ahora.difference(_ultima!) > maxEntreTeclas;
    if (lento) _buf.clear();

    if (esFin) {
      final codigo = _buf.toString();
      _buf.clear();
      _ultima = null;
      if (codigo.length >= largoMinimo && !lento) {
        alLeer(codigo);
        return true;
      }
      return false;
    }
    // Solo caracteres imprimibles de un código (dígitos, letras, guion).
    if (caracter != null && caracter.length == 1 && RegExp(r'[0-9A-Za-z\-]').hasMatch(caracter)) {
      _buf.write(caracter);
      _ultima = ahora;
    }
    return false;
  }
}
