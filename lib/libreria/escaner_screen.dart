import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'lector_usb.dart';

/// Abre la cámara y devuelve (Navigator.pop) el primer código leído.
/// En web/escritorio sin cámara se puede escribir el código a mano; los
/// lectores USB/Bluetooth funcionan como teclado y escriben en ese campo.
class EscanerScreen extends StatefulWidget {
  final String titulo;
  const EscanerScreen({super.key, this.titulo = 'Escanear código'});

  @override
  State<EscanerScreen> createState() => _EscanerScreenState();
}

class _EscanerScreenState extends State<EscanerScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final _manual = TextEditingController();
  bool _listo = false;
  late final _usb = LectorUsb(alLeer: _devolver);

  @override
  void initState() {
    super.initState();
    _usb.activar();
  }

  void _devolver(String code) {
    if (_listo) return;
    _listo = true;
    Navigator.of(context).pop(code);
  }

  @override
  void dispose() {
    _usb.desactivar();
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo), actions: [
        IconButton(
          icon: const Icon(Icons.flash_on),
          onPressed: () => _controller.toggleTorch(),
        ),
      ]),
      body: Column(children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final v = capture.barcodes.firstOrNull?.rawValue;
              if (v != null && v.isNotEmpty) _devolver(v);
            },
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo usar la cámara.\nEscribe el código abajo.',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _manual,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'O escribe / pasa el lector USB aquí',
              suffixIcon: IconButton(
                icon: const Icon(Icons.check),
                onPressed: () {
                  if (_manual.text.trim().isNotEmpty) _devolver(_manual.text.trim());
                },
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) _devolver(v.trim());
            },
          ),
        ),
      ]),
    );
  }
}
