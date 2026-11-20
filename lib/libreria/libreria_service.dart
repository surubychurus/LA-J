import 'package:flutter/foundation.dart';
import 'isbn.dart';
import 'models.dart';

class LibreriaException implements Exception {
  final String mensaje;
  LibreriaException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Catálogo + carrito + ventas, en memoria.
/// Para persistir, reemplazar los mapas por Firestore/SQLite usando
/// [Libro.toMap] / [Libro.fromMap] (la UI no cambia).
class LibreriaService extends ChangeNotifier {
  final Map<String, Libro> _catalogo = {};
  final List<ItemVenta> _carrito = [];
  final List<Venta> _ventas = [];

  LibreriaService({bool conDatosDeEjemplo = false}) {
    if (conDatosDeEjemplo) _cargarEjemplo();
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
    _catalogo[isbn] = libro.copyWith(isbn: isbn);
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
    _catalogo[isbn] = nuevo.copyWith(isbn: isbn);
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
    _carrito.removeWhere((i) => i.libro.isbn == isbn);
    notifyListeners();
  }

  /// Suma unidades al stock (recepción de mercadería).
  void reponerStock(String isbn, int unidades) {
    final l = _catalogo[isbn];
    if (l == null) throw LibreriaException('El libro no existe');
    if (unidades <= 0) throw LibreriaException('Cantidad inválida');
    _catalogo[isbn] = l.copyWith(stock: l.stock + unidades);
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
    _carrito.clear();
    notifyListeners();
    return venta;
  }

  void _cargarEjemplo() {
    const datos = [
      Libro(isbn: '9780306406157', titulo: 'Cien años de soledad', autor: 'Gabriel García Márquez', categoria: 'Novela', precio: 18.5, stock: 8),
      Libro(isbn: '9780140449136', titulo: 'El Quijote', autor: 'Miguel de Cervantes', categoria: 'Clásicos', precio: 22.0, stock: 5),
      Libro(isbn: '9780451524935', titulo: '1984', autor: 'George Orwell', categoria: 'Ficción', precio: 14.9, stock: 12),
    ];
    for (final l in datos) {
      if (Isbn.esEan13Valido(l.isbn)) _catalogo[l.isbn] = l;
    }
  }
}
