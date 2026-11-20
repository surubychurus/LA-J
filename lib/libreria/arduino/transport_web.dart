import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'arduino_transport.dart';

// --- Web Serial API (solo Chrome / Edge de escritorio, en https o localhost) ---
@JS('navigator.serial')
external _Serial? get _serial;

extension type _Serial._(JSObject _) implements JSObject {
  external JSPromise<_Port> requestPort();
  external void addEventListener(String tipo, JSFunction f);
  external void removeEventListener(String tipo, JSFunction f);
}

extension type _Port._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> open(JSObject opciones);
  external JSPromise<JSAny?> close();
  external _Readable get readable;
  external _Writable get writable;
}

extension type _Readable._(JSObject _) implements JSObject {
  external _Reader getReader();
}

extension type _Reader._(JSObject _) implements JSObject {
  external JSPromise<_Lectura> read();
  external JSPromise<JSAny?> cancel();
  external void releaseLock();
}

extension type _Lectura._(JSObject _) implements JSObject {
  external JSUint8Array? get value;
  external bool get done;
}

extension type _Writable._(JSObject _) implements JSObject {
  external _Writer getWriter();
}

extension type _Writer._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> write(JSUint8Array datos);
  external void releaseLock();
}

ArduinoTransport crearTransporte() => _WebSerial();

class _WebSerial implements ArduinoTransport {
  _Port? _puerto;
  _Reader? _lector;
  _Writer? _escritor;
  JSFunction? _alDesconectar;
  final _datos = StreamController<Uint8List>.broadcast();
  final _desc = StreamController<void>.broadcast();

  @override
  bool get soportado => _serial != null;
  @override
  Stream<Uint8List> get datos => _datos.stream;
  @override
  Stream<void> get desconexion => _desc.stream;

  @override
  Future<void> abrir({int baudRate = 9600}) async {
    await cerrar(); // si quedó un puerto agarrado, se suelta primero
    // El navegador obliga a que el usuario elija el puerto con un clic.
    final puerto = await _serial!.requestPort().toDart;
    await puerto.open({'baudRate': baudRate}.jsify() as JSObject).toDart;
    _puerto = puerto;
    _escritor = puerto.writable.getWriter();
    _lector = puerto.readable.getReader();

    _alDesconectar = ((JSObject _) {
      if (!_desc.isClosed) _desc.add(null);
    }).toJS;
    _serial!.addEventListener('disconnect', _alDesconectar!);

    _leer(_lector!);
  }

  Future<void> _leer(_Reader lector) async {
    try {
      while (true) {
        final r = await lector.read().toDart;
        if (r.done) break;
        final v = r.value;
        if (v != null) _datos.add(v.toDart);
      }
    } catch (_) {
      if (!_desc.isClosed) _desc.add(null);
    }
  }

  @override
  Future<void> escribir(Uint8List bytes) async {
    final e = _escritor;
    if (e == null) throw StateError('Puerto cerrado');
    await e.write(bytes.toJS).toDart;
  }

  @override
  Future<void> cerrar() async {
    final puerto = _puerto;
    final lector = _lector;
    final escritor = _escritor;
    _puerto = null;
    _lector = null;
    _escritor = null;
    if (_alDesconectar != null) {
      try {
        _serial?.removeEventListener('disconnect', _alDesconectar!);
      } catch (_) {}
      _alDesconectar = null;
    }
    // Orden obligatorio: primero lector y escritor, después el puerto.
    if (lector != null) {
      try { await lector.cancel().toDart; } catch (_) {}
      try { lector.releaseLock(); } catch (_) {}
    }
    if (escritor != null) {
      try { escritor.releaseLock(); } catch (_) {}
    }
    if (puerto != null) {
      try { await puerto.close().toDart; } catch (_) {}
    }
  }
}
