import 'package:app_2214/libreria/lector_usb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime ahora;
  late List<String> leidos;
  late LectorUsb lector;

  setUp(() {
    ahora = DateTime(2026);
    leidos = [];
    lector = LectorUsb(alLeer: leidos.add, reloj: () => ahora);
  });

  void teclear(String s, {int ms = 10}) {
    for (final c in s.split('')) {
      lector.procesar(caracter: c);
      ahora = ahora.add(Duration(milliseconds: ms));
    }
  }

  test('código rápido + Enter se emite', () {
    teclear('9780306406157');
    lector.procesar(esFin: true);
    expect(leidos, ['9780306406157']);
  });

  test('dos escaneos seguidos', () {
    teclear('9780306406157');
    lector.procesar(esFin: true);
    ahora = ahora.add(const Duration(seconds: 1));
    teclear('9780451524935');
    lector.procesar(esFin: true);
    expect(leidos, ['9780306406157', '9780451524935']);
  });

  test('una persona tecleando lento no cuenta como lector', () {
    teclear('9780306406157', ms: 400);
    lector.procesar(esFin: true);
    expect(leidos, isEmpty);
  });

  test('códigos muy cortos se ignoran', () {
    teclear('123');
    lector.procesar(esFin: true);
    expect(leidos, isEmpty);
  });

  test('ignora teclas no imprimibles (Shift, etc.)', () {
    lector.procesar(caracter: null);
    teclear('9780306406157');
    lector.procesar(esFin: true);
    expect(leidos, ['9780306406157']);
  });
}
