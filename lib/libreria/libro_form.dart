import 'package:flutter/material.dart';
import 'escaner_screen.dart';
import 'isbn.dart';
import 'models.dart';

/// Formulario para añadir (libro == null) o editar un libro.
/// Devuelve el [Libro] resultante por Navigator.pop.
class LibroForm extends StatefulWidget {
  final Libro? libro;
  final String? isbnInicial;
  const LibroForm({super.key, this.libro, this.isbnInicial});

  @override
  State<LibroForm> createState() => _LibroFormState();
}

class _LibroFormState extends State<LibroForm> {
  final _key = GlobalKey<FormState>();
  late final _isbn = TextEditingController(text: widget.libro?.isbn ?? widget.isbnInicial ?? '');
  late final _titulo = TextEditingController(text: widget.libro?.titulo ?? '');
  late final _autor = TextEditingController(text: widget.libro?.autor ?? '');
  late final _categoria = TextEditingController(text: widget.libro?.categoria ?? '');
  late final _precio = TextEditingController(
      text: widget.libro == null ? '' : widget.libro!.precio.toStringAsFixed(2));
  late final _stock = TextEditingController(text: '${widget.libro?.stock ?? 0}');

  Future<void> _escanear() async {
    final code = await Navigator.of(context)
        .push<String>(MaterialPageRoute(builder: (_) => const EscanerScreen()));
    if (code != null) setState(() => _isbn.text = Isbn.normalizar(code) ?? code);
  }

  void _guardar() {
    if (!_key.currentState!.validate()) return;
    Navigator.of(context).pop(Libro(
      isbn: Isbn.normalizar(_isbn.text)!,
      titulo: _titulo.text.trim(),
      autor: _autor.text.trim(),
      categoria: _categoria.text.trim(),
      precio: double.parse(_precio.text.replaceAll(',', '.')),
      stock: int.parse(_stock.text),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.libro != null;
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar libro' : 'Nuevo libro')),
      body: Form(
        key: _key,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
            controller: _isbn,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Código de barras / ISBN',
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _escanear,
              ),
            ),
            validator: (v) =>
                Isbn.normalizar(v ?? '') == null ? 'Código ISBN/EAN-13 inválido' : null,
          ),
          TextFormField(
            controller: _titulo,
            decoration: const InputDecoration(labelText: 'Título'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
          ),
          TextFormField(controller: _autor, decoration: const InputDecoration(labelText: 'Autor')),
          TextFormField(
              controller: _categoria, decoration: const InputDecoration(labelText: 'Categoría')),
          TextFormField(
            controller: _precio,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Precio'),
            validator: (v) {
              final n = double.tryParse((v ?? '').replaceAll(',', '.'));
              return (n == null || n < 0) ? 'Precio inválido' : null;
            },
          ),
          TextFormField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Stock'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return (n == null || n < 0) ? 'Stock inválido' : null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _guardar, child: const Text('Guardar')),
        ]),
      ),
    );
  }
}
