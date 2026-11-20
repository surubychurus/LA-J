import 'package:flutter/material.dart';
import 'arduino/arduino_service.dart';
import 'db/libreria_db.dart';
import 'escaner_screen.dart';
import 'isbn.dart';
import 'lector_usb.dart';
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

class _LibreriaScreenState extends State<LibreriaScreen> with SingleTickerProviderStateMixin {
  final _service = LibreriaService();
  final _arduino = ArduinoService();
  late final _tabs = TabController(length: 3, vsync: this);
  final _catalogoKey = GlobalKey<_CatalogoTabState>();
  final _precioKey = GlobalKey<_PrecioTabState>();
  late final _lector = LectorUsb(alLeer: _alEscanearUsb);

  LibreriaDb? _db;
  bool _cargando = true;
  String? _errorDb;

  @override
  void initState() {
    super.initState();
    _lector.activar();
    _iniciarDb();
  }

  Future<void> _iniciarDb() async {
    try {
      final db = await LibreriaDb.abrir();
      await _service.conectarDb(db, sembrar: true);
      _db = db;
    } catch (e) {
      _errorDb = 'No se pudo abrir la base de datos ($e). Los datos no se guardarán.';
      _service.cargarEjemplos();
    }
    if (mounted) setState(() => _cargando = false);
  }

  /// Llega el código del lector USB: se usa según la pestaña activa.
  /// Se ignora si hay otra pantalla/diálogo encima (p. ej. el formulario).
  void _alEscanearUsb(String code) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    switch (_tabs.index) {
      case 0:
        _catalogoKey.currentState?.alEscanear(code);
      case 1:
        _VentaTab.agregarCodigo(context, _service, _arduino, code);
      case 2:
        _precioKey.currentState?.consultarCodigo(code);
    }
  }

  @override
  void dispose() {
    _lector.desactivar();
    _tabs.dispose();
    _arduino.dispose();
    final db = _db;
    _service.pendientes.whenComplete(() => db?.cerrar());
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Librería'),
          bottom: TabBar(controller: _tabs, tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Catálogo'),
            Tab(icon: Icon(Icons.point_of_sale), text: 'Venta'),
            Tab(icon: Icon(Icons.sell), text: 'Precio'),
          ]),
        ),
        body: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              final e = _errorDb ?? _service.errorDb;
              if (e == null) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Colors.red.withValues(alpha: 0.12),
                padding: const EdgeInsets.all(8),
                child: Text(e, style: const TextStyle(fontSize: 12)),
              );
            },
          ),
          _BarraArduino(arduino: _arduino),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              _CatalogoTab(key: _catalogoKey, service: _service),
              _VentaTab(service: _service, arduino: _arduino),
              _PrecioTab(key: _precioKey, service: _service, arduino: _arduino),
            ]),
          ),
        ]),
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
  const _CatalogoTab({super.key, required this.service});
  @override
  State<_CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<_CatalogoTab> {
  String _q = '';

  /// Código leído por el lector USB: si existe se edita, si no se abre "añadir" con el código puesto.
  Future<void> alEscanear(String code) async {
    final libro = widget.service.buscarPorCodigo(code);
    if (libro != null) return _editar(libro);
    final isbn = Isbn.normalizar(code);
    if (isbn == null) return _aviso(context, 'Código inválido: $code');
    await _nuevo(isbn: isbn);
  }

  Future<void> _nuevo({String? isbn}) async {
    final libro = await Navigator.of(context)
        .push<Libro>(MaterialPageRoute(builder: (_) => LibroForm(isbnInicial: isbn)));
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
        onPressed: () => _nuevo(),
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
  final ArduinoService arduino;
  const _VentaTab({required this.service, required this.arduino});

  Future<void> _escanearYAgregar(BuildContext context) async {
    final code = await _escanear(context);
    if (code == null || !context.mounted) return;
    agregarCodigo(context, service, arduino, code);
  }

  /// Agrega al carrito el libro de un código (cámara o lector USB).
  static void agregarCodigo(
      BuildContext context, LibreriaService service, ArduinoService arduino, String code) {
    try {
      service.agregarAlCarrito(code);
      final libro = service.buscarPorCodigo(code);
      if (libro != null) arduino.mostrarLibro(libro);
    } on LibreriaException catch (e) {
      _aviso(context, e.mensaje);
    }
  }

  void _cobrar(BuildContext context) {
    try {
      final v = service.cobrar();
      arduino.ventaCobrada(v.total);
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
                ? const Center(child: Text('Escanea con el lector USB o la cámara para empezar la venta'))
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
  final ArduinoService arduino;
  const _PrecioTab({super.key, required this.service, required this.arduino});
  @override
  State<_PrecioTab> createState() => _PrecioTabState();
}

class _PrecioTabState extends State<_PrecioTab> {
  Libro? _libro;
  String? _mensaje;

  Future<void> _consultar() async {
    final code = await _escanear(context);
    if (code != null) consultarCodigo(code);
  }

  /// Muestra el precio de un código (cámara o lector USB).
  void consultarCodigo(String code) {
    final l = widget.service.buscarPorCodigo(code);
    if (l != null) {
      widget.arduino.mostrarLibro(l);
    } else {
      widget.arduino.mostrarMensaje('NO ENCONTRADO');
    }
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
            Text(_mensaje ?? 'Escanea con el lector USB o la cámara para ver el precio',
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

// ---------------- Barra de estado del Arduino ----------------
class _BarraArduino extends StatelessWidget {
  final ArduinoService arduino;
  const _BarraArduino({required this.arduino});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: arduino,
      builder: (context, _) {
        final e = arduino.estado;
        final color = switch (e) {
          EstadoArduino.listo => Colors.green,
          EstadoArduino.error => Colors.red,
          EstadoArduino.conectando => Colors.orange,
          EstadoArduino.desconectado => Colors.grey,
        };
        return Container(
          color: color.withValues(alpha: 0.12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Icon(Icons.usb, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(arduino.mensaje, style: const TextStyle(fontSize: 12))),
            TextButton(
              onPressed: e == EstadoArduino.conectando ? null : arduino.conectar,
              child: Text(arduino.conectado ? 'Reconectar' : 'Conectar Arduino'),
            ),
          ]),
        );
      },
    );
  }
}
