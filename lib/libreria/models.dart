/// Modelos de la librería de ejemplo.
class Libro {
  final String isbn; // EAN-13 / ISBN-13 (lo que lee el código de barras)
  final String titulo;
  final String autor;
  final String categoria;
  final double precio;
  final int stock;

  const Libro({
    required this.isbn,
    required this.titulo,
    this.autor = '',
    this.categoria = '',
    required this.precio,
    this.stock = 0,
  });

  Libro copyWith({
    String? isbn,
    String? titulo,
    String? autor,
    String? categoria,
    double? precio,
    int? stock,
  }) =>
      Libro(
        isbn: isbn ?? this.isbn,
        titulo: titulo ?? this.titulo,
        autor: autor ?? this.autor,
        categoria: categoria ?? this.categoria,
        precio: precio ?? this.precio,
        stock: stock ?? this.stock,
      );

  Map<String, dynamic> toMap() => {
        'isbn': isbn,
        'titulo': titulo,
        'autor': autor,
        'categoria': categoria,
        'precio': precio,
        'stock': stock,
      };

  factory Libro.fromMap(Map<String, dynamic> m) => Libro(
        isbn: m['isbn'] as String,
        titulo: m['titulo'] as String,
        autor: (m['autor'] ?? '') as String,
        categoria: (m['categoria'] ?? '') as String,
        precio: (m['precio'] as num).toDouble(),
        stock: (m['stock'] ?? 0) as int,
      );
}

class ItemVenta {
  final Libro libro;
  final int cantidad;
  const ItemVenta(this.libro, this.cantidad);

  double get subtotal => libro.precio * cantidad;
  ItemVenta conCantidad(int c) => ItemVenta(libro, c);
}

class Venta {
  final DateTime fecha;
  final List<ItemVenta> items;
  const Venta(this.fecha, this.items);

  double get total => items.fold(0, (s, i) => s + i.subtotal);
  int get unidades => items.fold(0, (s, i) => s + i.cantidad);
}
