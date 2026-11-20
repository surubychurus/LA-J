// Elige el motor de SQLite según la plataforma:
//  - Android / iOS: sqflite
//  - Windows / Linux / macOS: sqflite_common_ffi
//  - Web: sqflite_common_ffi_web (necesita web/sqlite3.wasm, ver LEEME)
export 'db_factory_io.dart' if (dart.library.js_interop) 'db_factory_web.dart';
