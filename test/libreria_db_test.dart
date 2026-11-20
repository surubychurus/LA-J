import 'dart:io';

import 'package:app_2214/libreria/db/libreria_db.dart';
import 'package:app_2214/libreria/libreria_service.dart';
import 'package:app_2214/libreria/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<bool> sqliteDisponible() async {
  try {
    sqfliteFfiInit();
    final d = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await d.close();
    return true;
  } catch (_) {
    return false; // p. ej. Windows sin sqlite3.dll
  }
}

Future<LibreriaDb> abrirMemoria() =>
    LibreriaDb.abrir(fabrica: databaseFactoryFfi, ruta: inMemoryDatabasePath);

Future<void> main() async {
  final ok = await sqliteDisponible();
  const a = Libro(isbn: '9780306406157', titulo: 'A', autor: 'X', precio: 10, stock: 5);

  group('LibreriaDb', () {
    test('guarda, edita y elimina libros', () async {
      final db = await abrirMemoria();
      await db.guardarLibro(a);
      expect((await db.libros()).single.titulo, 'A');
      await db.reemplazarLibro(a.isbn, a.copyWith(isbn: '9780451524935', precio: 12));
      final l = (await db.libros()).single;
      expect(l.isbn, '9780451524935');
      expect(l.precio, 12);
      await db.eliminarLibro(l.isbn);
      expect(await db.libros(), isEmpty);
      await db.cerrar();
    });

    test('venta descuenta stock y queda en el historial', () async {
      final db = await abrirMemoria();
      await db.guardarLibro(a);
      await db.registrarVenta(Venta(DateTime(2026, 1, 2), [ItemVenta(a, 2)]));
      expect((await db.libros()).single.stock, 3);
      final v = (await db.ventas()).single;
      expect(v.total, 20);
      expect(v.items.single.libro.titulo, 'A');
      await db.cerrar();
    });
  }, skip: ok ? false : 'sqlite3 no disponible en este equipo');

  group('LibreriaService + DB', () {
    test('los cambios y ventas persisten al reabrir', () async {
      // Archivo temporal para poder cerrar y reabrir la misma base.
      final dir = await Directory.systemTemp.createTemp('libreria_test');
      final ruta = '${dir.path}/t.db';
      try {
        // 1ª apertura: base vacía -> se siembran los 3 ejemplos
        var db = await LibreriaDb.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
        var s = LibreriaService();
        await s.conectarDb(db, sembrar: true);
        expect(s.libros.length, 3);
        await db.cerrar();

        // 2ª apertura: se edita un precio y se hace una venta
        db = await LibreriaDb.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
        s = LibreriaService();
        await s.conectarDb(db);
        s.editarLibro('9780306406157', s.buscarPorCodigo('9780306406157')!.copyWith(precio: 99));
        s.agregarAlCarrito('9780306406157', cantidad: 2);
        s.cobrar();
        await s.pendientes;
        expect(s.errorDb, isNull);
        await db.cerrar();

        // 3ª apertura: todo sigue ahí
        db = await LibreriaDb.abrir(fabrica: databaseFactoryFfi, ruta: ruta);
        s = LibreriaService();
        await s.conectarDb(db);
        final l = s.buscarPorCodigo('9780306406157')!;
        expect(l.precio, 99);
        expect(l.stock, 6); // 8 - 2
        expect(s.ventas.single.total, 198);
        await db.cerrar();
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }, skip: ok ? false : 'sqlite3 no disponible en este equipo');
}
