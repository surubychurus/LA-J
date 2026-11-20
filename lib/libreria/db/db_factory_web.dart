import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

Future<mobile.DatabaseFactory> crearFabricaDb() async => databaseFactoryFfiWebNoWebWorker;
