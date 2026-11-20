// Elige la implementación según la plataforma (web / Android-io / ninguna).
export 'transport_stub.dart'
    if (dart.library.js_interop) 'transport_web.dart'
    if (dart.library.io) 'transport_usb.dart';
