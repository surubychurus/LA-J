/// Utilidades para códigos de barras de libros (EAN-13 / ISBN-13).
class Isbn {
  /// Deja solo dígitos (los lectores a veces devuelven guiones o espacios).
  static String limpiar(String s) => s.replaceAll(RegExp(r'[^0-9Xx]'), '').toUpperCase();

  /// Valida el dígito de control de un EAN-13 (los ISBN-13 empiezan en 978/979).
  static bool esEan13Valido(String code) {
    final c = limpiar(code);
    if (c.length != 13 || c.contains('X')) return false;
    var suma = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(c[i]);
      suma += i.isEven ? d : d * 3;
    }
    return (10 - suma % 10) % 10 == int.parse(c[12]);
  }

  /// Valida un ISBN-10 (dígito de control módulo 11).
  static bool esIsbn10Valido(String code) {
    final c = limpiar(code);
    if (c.length != 10) return false;
    var suma = 0;
    for (var i = 0; i < 10; i++) {
      final ch = c[i];
      final v = (ch == 'X' && i == 9) ? 10 : int.tryParse(ch);
      if (v == null) return false;
      suma += v * (10 - i);
    }
    return suma % 11 == 0;
  }

  /// Convierte ISBN-10 a ISBN-13 (prefijo 978).
  static String isbn10a13(String code) {
    final base = '978${limpiar(code).substring(0, 9)}';
    var suma = 0;
    for (var i = 0; i < 12; i++) {
      final d = int.parse(base[i]);
      suma += i.isEven ? d : d * 3;
    }
    return '$base${(10 - suma % 10) % 10}';
  }

  /// Normaliza lo que se escanea a la clave usada en el catálogo (13 dígitos).
  /// Devuelve null si el código no es un ISBN/EAN válido.
  static String? normalizar(String code) {
    final c = limpiar(code);
    if (c.length == 13 && esEan13Valido(c)) return c;
    if (c.length == 10 && esIsbn10Valido(c)) return isbn10a13(c);
    return null;
  }
}
