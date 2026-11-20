import 'dart:typed_data';

/// Canal de bytes hacia el Arduino. Hay una implementación por plataforma:
/// web (Web Serial), Android (USB OTG) y una vacía para el resto.
abstract class ArduinoTransport {
  /// false si esta plataforma/navegador no puede usar puerto serie.
  bool get soportado;

  /// Abre el puerto (en web el usuario elige el puerto; debe llamarse desde un clic).
  Future<void> abrir({int baudRate = 9600});

  Future<void> escribir(Uint8List bytes);

  /// Bytes que llegan del Arduino (stream broadcast).
  Stream<Uint8List> get datos;

  /// Emite cuando el sistema deja de ver el dispositivo USB.
  Stream<void> get desconexion;

  /// Suelta lector, escritor y puerto, en ese orden. Nunca lanza.
  Future<void> cerrar();
}
