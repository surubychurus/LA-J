import 'package:flutter/material.dart';
import 'escaner_screen.dart';
import 'libreria_service.dart';
import 'libro_form.dart';
import 'models.dart';

/// Pantalla principal de la librería: Catálogo · Venta · Consulta de precio.
/// Uso: `Navigator.push(context, MaterialPageRoute(builder: (_) => const LibreriaScreen()))`
class LibreriaScreen extends StatefulWidget {
  const LibreriaScreen({super.key});

  @override
  State<LibreriaScreen> createState() => _LibreriaScreenState();
}

class _LibreriaScreenState extends State<LibreriaScreen> {
  final _service = LibreriaService(conDatosDeEjemplo: true);

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Librería'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.menu_book), text: 'Catálogo'),
            Tab(icon: Icon(Icons.point_of_sale), text: 'Venta'),
            Tab(icon: Icon(Icons.sell), text: 'Precio'),
          ]),
        ),
        body: TabBarView(children: [
          _CatalogoTab(service: _service),
          _VentaTab(service: _service),
          _PrecioTab(service: _service),
        ]),
      ),
    );
  }
}

String _dinero(double v) => '\$${v.toStringAsFixed(2)}';

void _aviso(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<String?> _escanear(BuildContext c) =>
    Navigator.of(c).push<String>(MaterialPageRoute(builder: (_) => const EscanerScreen()));

// ---------------- Catálogo ----------------
class _CatalogoTab extends StatefulWidget {
  final LibreriaService service;
  const _CatalogoTab({required this.service});
  @override
  State<_CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<_CatalogoTab> {
  String _q = '';

  Future<void> _nuevo() async {
    final libro = await Navigator.of(context)
        .push<Libro>(MaterialPageRoute(builder: (_) => const LibroForm()));
    if (libro == null || !mounted) return;
    try {
      widget.service.agregarLibro(libro);
    } on LibreriaException catch (e) {
      _aviso(context, e.mensaje);
    }
  }

  Future<void> _editar(Libro l) async {
    final nuevo = await Navigator.of(context)
        .push<Libro>(MaterialPageRoute(builder: (_) => LibroForm(libro: l)));
    if (nuevo == null || !mounted) return;
    try {
      widget.service.editarLibro(l.isbn, nuevo);
    } on LibreriaException catch (e) {
      _aviso(context, e.mensaje);
    }
  }

  Future<void> _eliminar(Libro l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar libro'),
        content: Text('¿Eliminar "${l.titulo}" del catálogo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) widget.service.eliminarLibro(l.isbn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Añadir libro'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Buscar título, autor, categoría o ISBN'),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: widget.service,
            builder: (context, _) {
              final libros = widget.service.buscarTexto(_q);
              if (libros.isEmpty) return const Center(child: Text('Sin libros'));
              return ListView.separated(
                itemCount: libros.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final l = libros[i];
                  return ListTile(
                    title: Text(l.titulo),
                    subtitle: Text('${l.autor}  ·  ${l.isbn}\nStock: ${l.stock}'),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(_dinero(l.precio), style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _editar(l)),
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _eliminar(l)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ---------------- Venta ----------------
class _VentaTab extends StatelessWidget {
  final LibreriaService service;
  const _VentaTab({required this.service});

  Future<void> _escanearYAgregar(BuildContext context) async {
    final code = await _escanear(context);
    if (code == null || !context.mounted) return;
    try {
      service.agregarAlCarrito(code);
    } on LibreriaException catch (e) {
      _aviso(context, e.mensaje);
    }
  }

  void _cobrar(BuildContext context) {
    try {
      final v = service.cobrar();
      _aviso(context, 'Venta registrada: ${v.unidades} uds · ${_dinero(v.total)}');
    } on LibreriaException catch (e) {
      _aviso(context, e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final items = service.carrito;
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _escanearYAgregar(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear libro'),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('Escanea un libro para empezar la venta'))
                : ListView(children: [
                    for (final i in items)
                      ListTile(
                        title: Text(i.libro.titulo),
                        subtitle: Text('${i.cantidad} × ${_dinero(i.libro.precio)}'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_dinero(i.subtotal)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => service.quitarDelCarrito(i.libro.isbn),
                          ),
                        ]),
                      ),
                  ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: Text('Total: ${_dinero(service.totalCarrito)}',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              TextButton(
                  onPressed: items.isEmpty ? null : service.vaciarCarrito,
                  child: const Text('Vaciar')),
              const SizedBox(width: 8),
              FilledButton(
                  onPressed: items.isEmpty ? null : () => _cobrar(context),
                  child: const Text('Cobrar')),
            ]),
          ),
        ]);
      },
    );
  }
}

// ---------------- Consulta de precio ----------------
class _PrecioTab extends StatefulWidget {
  final LibreriaService service;
  const _PrecioTab({required this.service});
  @override
  State<_PrecioTab> createState() => _PrecioTabState();
}

class _PrecioTabState extends State<_PrecioTab> {
  Libro? _libro;
  String? _mensaje;

  Future<void> _consultar() async {
    final code = await _escanear(context);
    if (code == null) return;
    final l = widget.service.buscarPorCodigo(code);
    setState(() {
      _libro = l;
      _mensaje = l == null ? 'No encontrado en el catálogo ($code)' : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = _libro;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (l != null) ...[
            Text(l.titulo,
                style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            Text(l.autor),
            const SizedBox(height: 12),
            Text(_dinero(l.precio), style: Theme.of(context).textTheme.displayMedium),
            Text(l.stock > 0 ? 'Disponible: ${l.stock}' : 'Agotado'),
          ] else
            Text(_mensaje ?? 'Escanea un código de barras para ver el precio',
                textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _consultar,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Consultar precio'),
          ),
        ]),
      ),
    );
  }
}
