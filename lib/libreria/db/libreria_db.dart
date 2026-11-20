import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models.dart';
import 'db_factory.dart';

/// Base de datos SQLite de la librería: catálogo y ventas.
///
/// Las ventas guardan copia del título y el precio al momento de vender, así
/// el historial no cambia si después se edita o se elimina el libro.
class LibreriaDb {
  LibreriaDb._(this._db);
  final Database _db;

  /// [fabrica] y [ruta] solo se pasan en tests (p. ej. inMemoryDatabasePath).
  static Future<LibreriaDb> abrir({DatabaseFactory? fabrica, String? ruta}) async {
    final f = fabrica ?? await crearFabricaDb();
    final r = ruta ?? p.join(await f.getDatabasesPath(), 'libreria.db');
    final db = await f.openDatabase(
      r,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onCreate: (d, _) async {
          await d.execute('''
            CREATE TABLE libros(
              isbn TEXT PRIMARY KEY,
              titulo TEXT NOT NULL,
              autor TEXT NOT NULL DEFAULT '',
              categoria TEXT NOT NULL DEFAULT '',
              precio REAL NOT NULL,
              stock INTEGER NOT NULL DEFAULT 0
            )''');
          await d.execute('''
            CREATE TABLE ventas(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fecha TEXT NOT NULL
            )''');
          await d.execute('''
            CREATE TABLE venta_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              venta_id INTEGER NOT NULL REFERENCES ventas(id) ON DELETE CASCADE,
              isbn TEXT NOT NULL,
              titulo TEXT NOT NULL,
              precio REAL NOT NULL,
              cantidad INTEGER NOT NULL
            )''');
        },
      ),
    );
    return LibreriaDb._(db);
  }

  // ---- Catálogo ----
  Future<List<Libro>> libros() async {
    final filas = await _db.query('libros', orderBy: 'titulo COLLATE NOCASE');
    return filas.map(Libro.fromMap).toList();
  }

  /// Inserta o reemplaza (clave: isbn).
  Future<void> guardarLibro(Libro l) =>
      _db.insert('libros', l.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  /// Edita un libro; si cambió el ISBN, lo mueve de clave.
  Future<void> reemplazarLibro(String isbnOriginal, Libro l) => _db.transaction((t) async {
        await t.delete('libros', where: 'isbn = ?', whereArgs: [isbnOriginal]);
        await t.insert('libros', l.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      });

  Future<void> eliminarLibro(String isbn) =>
      _db.delete('libros', where: 'isbn = ?', whereArgs: [isbn]);

  // ---- Ventas ----
  /// Guarda el ticket y descuenta el stock, todo en una sola transacción.
  Future<void> registrarVenta(Venta v) => _db.transaction((t) async {
        final id = await t.insert('ventas', {'fecha': v.fecha.toIso8601String()});
        for (final i in v.items) {
          await t.insert('venta_items', {
            'venta_id': id,
            'isbn': i.libro.isbn,
            'titulo': i.libro.titulo,
            'precio': i.libro.precio,
            'cantidad': i.cantidad,
          });
          await t.rawUpdate('UPDATE libros SET stock = stock - ? WHERE isbn = ?',
              [i.cantidad, i.libro.isbn]);
        }
      });

  Future<List<Venta>> ventas() async {
    final cab = await _db.query('ventas', orderBy: 'id');
    final res = <Venta>[];
    for (final c in cab) {
      final items = await _db.query('venta_items',
          where: 'venta_id = ?', whereArgs: [c['id']], orderBy: 'id');
      res.add(Venta(
        DateTime.parse(c['fecha'] as String),
        items
            .map((i) => ItemVenta(
                  Libro(
                    isbn: i['isbn'] as String,
                    titulo: i['titulo'] as String,
                    precio: (i['precio'] as num).toDouble(),
                  ),
                  i['cantidad'] as int,
                ))
            .toList(),
      ));
    }
    return res;
  }

  Future<void> cerrar() => _db.close();
}
