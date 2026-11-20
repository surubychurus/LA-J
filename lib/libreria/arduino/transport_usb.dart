import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import 'arduino_transport.dart';

ArduinoTransport crearTransporte() => _UsbAndroid();

/// Arduino por cable USB OTG en Android.
class _UsbAndroid implements ArduinoTransport {
  UsbPort? _puerto;
  StreamSubscription<Uint8List>? _subDatos;
  StreamSubscription<UsbEvent>? _subEventos;
  final _datos = StreamController<Uint8List>.broadcast();
  final _desc = StreamController<void>.broadcast();

  @override
  bool get soportado => Platform.isAndroid;
  @override
  Stream<Uint8List> get datos => _datos.stream;
  @override
  Stream<void> get desconexion => _desc.stream;

  @override
  Future<void> abrir({int baudRate = 9600}) async {
    await cerrar();
    final dispositivos = await UsbSerial.listDevices();
    if (dispositivos.isEmpty) {
      throw StateError('No hay ningún Arduino enchufado (¿cable OTG?)');
    }
    // Android pide permiso al usuario la primera vez.
    final puerto = await dispositivos.first.create();
    if (puerto == null || !await puerto.open()) {
      throw StateError('No se pudo abrir el puerto USB (permiso denegado u ocupado)');
    }
    await puerto.setPortParameters(
        baudRate, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    _puerto = puerto;
    _subDatos = puerto.inputStream?.listen(_datos.add);
    _subEventos = UsbSerial.usbEventStream?.listen((e) {
      if (e.event == UsbEvent.ACTION_USB_DETACHED && !_desc.isClosed) _desc.add(null);
    });
  }

  @override
  Future<void> escribir(Uint8List bytes) async {
    final p = _puerto;
    if (p == null) throw StateError('Puerto cerrado');
    await p.write(bytes);
  }

  @override
  Future<void> cerrar() async {
    final p = _puerto;
    _puerto = null;
    try { await _subDatos?.cancel(); } catch (_) {}
    try { await _subEventos?.cancel(); } catch (_) {}
    _subDatos = null;
    _subEventos = null;
    if (p != null) {
      try { await p.close(); } catch (_) {}
    }
  }
}
