import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

Future<mobile.DatabaseFactory> crearFabricaDb() async {
  if (Platform.isAndroid || Platform.isIOS) return mobile.databaseFactory;
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi;
}
