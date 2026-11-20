import 'package:app_2214/libreria/isbn.dart';
import 'package:app_2214/libreria/libreria_service.dart';
import 'package:app_2214/libreria/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Isbn', () {
    test('valida EAN-13', () {
      expect(Isbn.esEan13Valido('9780306406157'), isTrue);
      expect(Isbn.esEan13Valido('9780306406158'), isFalse);
    });
    test('ISBN-10 se normaliza a 13', () {
      expect(Isbn.normalizar('0-306-40615-2'), '9780306406157');
    });
    test('rechaza basura', () {
      expect(Isbn.normalizar('123'), isNull);
    });
  });

  group('LibreriaService', () {
    late LibreriaService s;
    setUp(() {
      s = LibreriaService();
      s.agregarLibro(const Libro(
          isbn: '9780306406157', titulo: 'A', precio: 10, stock: 3));
    });

    test('no permite duplicados ni ISBN inválido', () {
      expect(() => s.agregarLibro(const Libro(isbn: '9780306406157', titulo: 'B', precio: 1)),
          throwsA(isA<LibreriaException>()));
      expect(() => s.agregarLibro(const Libro(isbn: '111', titulo: 'B', precio: 1)),
          throwsA(isA<LibreriaException>()));
    });

    test('editar cambia precio', () {
      s.editarLibro('9780306406157',
          s.buscarPorCodigo('9780306406157')!.copyWith(precio: 12.5));
      expect(s.buscarPorCodigo('9780306406157')!.precio, 12.5);
    });

    test('venta descuenta stock y suma total', () {
      s.agregarAlCarrito('9780306406157', cantidad: 2);
      final v = s.cobrar();
      expect(v.total, 20);
      expect(s.buscarPorCodigo('9780306406157')!.stock, 1);
      expect(s.carrito, isEmpty);
    });

    test('no vende más que el stock', () {
      expect(() => s.agregarAlCarrito('9780306406157', cantidad: 4),
          throwsA(isA<LibreriaException>()));
    });

    test('código desconocido', () {
      expect(() => s.agregarAlCarrito('9780140449136'), throwsA(isA<LibreriaException>()));
    });
  });
}
