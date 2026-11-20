import 'package:flutter/foundation.dart';
import 'db/libreria_db.dart';
import 'isbn.dart';
import 'models.dart';

class LibreriaException implements Exception {
  final String mensaje;
  LibreriaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Catálogo + carrito + ventas.
/// Trabaja en memoria (rápido y síncrono) y, si se le conecta una
/// [LibreriaDb] con [conectarDb], cada cambio se guarda también en SQLite.
class LibreriaService extends ChangeNotifier {
  final Map<String, Libro> _catalogo = {};
  final List<ItemVenta> _carrito = [];
  final List<Venta> _ventas = [];

  LibreriaService({bool conDatosDeEjemplo = false}) {
    if (conDatosDeEjemplo) cargarEjemplos();
  }

  // ---- Persistencia (SQLite) ----
  LibreriaDb? _db;
  Future<void> _cola = Future.value();
  bool _muerto = false;

  /// Último error al guardar en la base de datos (null si todo bien).
  String? errorDb;

  /// Se completa cuando terminaron todos los guardados pendientes.
  Future<void> get pendientes => _cola;

  /// Carga catálogo y ventas desde la base. Si está vacía y [sembrar], la
  /// llena con los libros de ejemplo.
  Future<void> conectarDb(LibreriaDb db, {bool sembrar = false}) async {
    _db = null; // sin escribir mientras se carga
    var libros = await db.libros();
    if (libros.isEmpty && sembrar) {
      for (final l in ejemplos) {
        await db.guardarLibro(l);
      }
      libros = await db.libros();
    }
    _catalogo
      ..clear()
      ..addEntries(libros.map((l) => MapEntry(l.isbn, l)));
    _ventas
      ..clear()
      ..addAll(await db.ventas());
    _carrito.clear();
    _db = db;
    errorDb = null;
    notifyListeners();
  }

  /// Los guardados se hacen de a uno y en orden; un fallo no frena la venta.
  void _persistir(Future<void> Function(LibreriaDb db) op) {
    final db = _db;
    if (db == null) return;
    _cola = _cola.then((_) => op(db)).catchError((Object e) {
      errorDb = 'No se pudo guardar en la base de datos: $e';
      if (!_muerto) notifyListeners();
    });
  }

  @override
  void dispose() {
    _muerto = true;
    super.dispose();
  }

  // ---- Catálogo ----
  List<Libro> get libros {
    final l = _catalogo.values.toList()
      ..sort((a, b) => a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase()));
    return List.unmodifiable(l);
  }

  Libro? buscarPorCodigo(String codigo) {
    final isbn = Isbn.normalizar(codigo);
    return isbn == null ? null : _catalogo[isbn];
  }

  List<Libro> buscarTexto(String q) {
    final t = q.trim().toLowerCase();
    if (t.isEmpty) return libros;
    return libros
        .where((l) =>
            l.titulo.toLowerCase().contains(t) ||
            l.autor.toLowerCase().contains(t) ||
            l.categoria.toLowerCase().contains(t) ||
            l.isbn.contains(t))
        .toList();
  }

  void agregarLibro(Libro libro) {
    final isbn = _validar(libro);
    if (_catalogo.containsKey(isbn)) {
      throw LibreriaException('Ya existe un libro con el código $isbn');
    }
    final guardado = libro.copyWith(isbn: isbn);
    _catalogo[isbn] = guardado;
    _persistir((db) => db.guardarLibro(guardado));
    notifyListeners();
  }

  /// Edita un libro. Si cambia el ISBN, se mueve de clave.
  void editarLibro(String isbnOriginal, Libro nuevo) {
    if (!_catalogo.containsKey(isbnOriginal)) {
      throw LibreriaException('El libro no existe');
    }
    final isbn = _validar(nuevo);
    if (isbn != isbnOriginal && _catalogo.containsKey(isbn)) {
      throw LibreriaException('Ya existe un libro con el código $isbn');
    }
    _catalogo.remove(isbnOriginal);
    final guardado = nuevo.copyWith(isbn: isbn);
    _catalogo[isbn] = guardado;
    _persistir((db) => db.reemplazarLibro(isbnOriginal, guardado));
    // Mantener el carrito coherente con los datos nuevos.
    for (var i = 0; i < _carrito.length; i++) {
      if (_carrito[i].libro.isbn == isbnOriginal) {
        final c = _carrito[i].cantidad.clamp(0, nuevo.stock);
        if (c == 0) {
          _carrito.removeAt(i);
          i--;
        } else {
          _carrito[i] = ItemVenta(_catalogo[isbn]!, c);
        }
      }
    }
    notifyListeners();
  }

  void eliminarLibro(String isbn) {
    _catalogo.remove(isbn);
    _persistir((db) => db.eliminarLibro(isbn));
    _carrito.removeWhere((i) => i.libro.isbn == isbn);
    notifyListeners();
  }

  /// Suma unidades al stock (recepción de mercadería).
  void reponerStock(String isbn, int unidades) {
    final l = _catalogo[isbn];
    if (l == null) throw LibreriaException('El libro no existe');
    if (unidades <= 0) throw LibreriaException('Cantidad inválida');
    final nuevo = l.copyWith(stock: l.stock + unidades);
    _catalogo[isbn] = nuevo;
    _persistir((db) => db.guardarLibro(nuevo));
    notifyListeners();
  }

  String _validar(Libro l) {
    final isbn = Isbn.normalizar(l.isbn);
    if (isbn == null) {
      throw LibreriaException('Código de barras/ISBN inválido: ${l.isbn}');
    }
    if (l.titulo.trim().isEmpty) throw LibreriaException('Falta el título');
    if (l.precio < 0) throw LibreriaException('El precio no puede ser negativo');
    if (l.stock < 0) throw LibreriaException('El stock no puede ser negativo');
    return isbn;
  }

  // ---- Venta ----
  List<ItemVenta> get carrito => List.unmodifiable(_carrito);
  double get totalCarrito => _carrito.fold(0, (s, i) => s + i.subtotal);
  List<Venta> get ventas => List.unmodifiable(_ventas);
  double get totalVendido => _ventas.fold(0, (s, v) => s + v.total);

  /// Agrega un libro al carrito (por ejemplo, tras escanear su código).
  void agregarAlCarrito(String codigo, {int cantidad = 1}) {
    final libro = buscarPorCodigo(codigo);
    if (libro == null) {
      throw LibreriaException('Código no encontrado en el catálogo');
    }
    final idx = _carrito.indexWhere((i) => i.libro.isbn == libro.isbn);
    final actual = idx >= 0 ? _carrito[idx].cantidad : 0;
    if (actual + cantidad > libro.stock) {
      throw LibreriaException('Sin stock suficiente de "${libro.titulo}" (quedan ${libro.stock})');
    }
    if (idx >= 0) {
      _carrito[idx] = _carrito[idx].conCantidad(actual + cantidad);
    } else {
      _carrito.add(ItemVenta(libro, cantidad));
    }
    notifyListeners();
  }

  void quitarDelCarrito(String isbn) {
    _carrito.removeWhere((i) => i.libro.isbn == isbn);
    notifyListeners();
  }

  void vaciarCarrito() {
    _carrito.clear();
    notifyListeners();
  }

  /// Confirma la venta: descuenta stock y registra el ticket.
  Venta cobrar() {
    if (_carrito.isEmpty) throw LibreriaException('El carrito está vacío');
    for (final i in _carrito) {
      final l = _catalogo[i.libro.isbn];
      if (l == null || l.stock < i.cantidad) {
        throw LibreriaException('Sin stock de "${i.libro.titulo}"');
      }
    }
    for (final i in _carrito) {
      final l = _catalogo[i.libro.isbn]!;
      _catalogo[l.isbn] = l.copyWith(stock: l.stock - i.cantidad);
    }
    final venta = Venta(DateTime.now(), List.of(_carrito));
    _ventas.add(venta);
    _persistir((db) => db.registrarVenta(venta));
    _carrito.clear();
    notifyListeners();
    return venta;
  }

  static const ejemplos = [
    Libro(isbn: '9780306406157', titulo: 'Cien años de soledad', autor: 'Gabriel García Márquez', categoria: 'Novela', precio: 18.5, stock: 8),
    Libro(isbn: '9780140449136', titulo: 'El Quijote', autor: 'Miguel de Cervantes', categoria: 'Clásicos', precio: 22.0, stock: 5),
    Libro(isbn: '9780451524935', titulo: '1984', autor: 'George Orwell', categoria: 'Ficción', precio: 14.9, stock: 12),
  ];

  /// Carga los libros de ejemplo solo en memoria (sin base de datos).
  void cargarEjemplos() {
    for (final l in ejemplos) {
      _catalogo[l.isbn] = l;
    }
    notifyListeners();
  }
}
