import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:app_2214/libreria/arduino/arduino_service.dart';
import 'package:app_2214/libreria/arduino/arduino_transport.dart';
import 'package:app_2214/libreria/models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeTransport implements ArduinoTransport {
  final enviado = <String>[];
  final _datos = StreamController<Uint8List>.broadcast();
  final _desc = StreamController<void>.broadcast();
  bool falla = false;

  void arduinoDice(String s) => _datos.add(Uint8List.fromList(utf8.encode(s)));
  void desenchufar() => _desc.add(null);

  @override
  bool get soportado => true;
  @override
  Future<void> abrir({int baudRate = 9600}) async {
    if (falla) throw StateError('ocupado');
  }
  @override
  Future<void> escribir(Uint8List b) async => enviado.add(utf8.decode(b));
  @override
  Stream<Uint8List> get datos => _datos.stream;
  @override
  Stream<void> get desconexion => _desc.stream;
  @override
  Future<void> cerrar() async {}
}

Future<void> pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeTransport t;
  late ArduinoService a;
  setUp(() {
    t = FakeTransport();
    a = ArduinoService(transport: t, esperaReady: const Duration(milliseconds: 50));
  });
  tearDown(() => a.dispose());

  test('READY deja el Arduino listo (aunque llegue partido)', () async {
    await a.conectar();
    expect(a.estado, EstadoArduino.conectando);
    t.arduinoDice('REA');
    t.arduinoDice('DY\r\n');
    await pump();
    expect(a.estado, EstadoArduino.listo);
  });

  test('sin READY igual queda listo tras la espera', () async {
    await a.conectar();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(a.estado, EstadoArduino.listo);
  });

  test('ERR:LCD avisa de la pantalla', () async {
    await a.conectar();
    t.arduinoDice('ERR:LCD\n');
    await pump();
    expect(a.estado, EstadoArduino.error);
    expect(a.mensaje, contains('LCD'));
  });

  test('enviar escribe la línea con salto de línea', () async {
    await a.conectar();
    t.arduinoDice('READY\n');
    await pump();
    await a.mostrarLibro(const Libro(
        isbn: '9780306406157', titulo: 'Cien años de soledad', precio: 18.5, stock: 8));
    expect(t.enviado.single, 'LIBRO|Cien anos de sol|18.50|8\n');
  });

  test('sin conexión no lanza y avisa', () async {
    final ok = await a.mostrarTotal(10);
    expect(ok, isFalse);
    expect(a.estado, EstadoArduino.error);
    expect(t.enviado, isEmpty);
  });

  test('error al abrir queda en error', () async {
    t.falla = true;
    await a.conectar();
    expect(a.estado, EstadoArduino.error);
    expect(a.mensaje, contains('No se pudo conectar'));
  });

  test('desenchufar muestra aviso de corriente', () async {
    await a.conectar();
    t.desenchufar();
    await pump();
    expect(a.estado, EstadoArduino.error);
    expect(a.mensaje, contains('corriente'));
    expect(await a.enviar('X'), isFalse);
  });

  test('lcd limpia tildes, separadores y largo', () {
    expect(ArduinoService.lcd('Ñandú|\nXYZ'), 'Nandu  XYZ');
    expect(ArduinoService.lcd('a' * 40).length, 16);
  });
}
