import 'dart:typed_data';
import 'arduino_transport.dart';

ArduinoTransport crearTransporte() => _SinPuerto();

class _SinPuerto implements ArduinoTransport {
  @override
  bool get soportado => false;
  @override
  Future<void> abrir({int baudRate = 9600}) async =>
      throw UnsupportedError('Puerto serie no disponible en esta plataforma');
  @override
  Future<void> escribir(Uint8List bytes) async {}
  @override
  Stream<Uint8List> get datos => const Stream.empty();
  @override
  Stream<void> get desconexion => const Stream.empty();
  @override
  Future<void> cerrar() async {}
}
