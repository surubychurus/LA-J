import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import 'db.dart';

/// Notificaciones locales (no necesitan servidor ni internet).
/// Por ahora: recordatorio semanal de los sábados a las 14:30.
class Notifs {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _prefKey = 'recordatorio_sabado';
  static const _idSabado = 1;
  static bool _ready = false;

  static bool get soportado => !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  static Future<bool> recordatorioActivo() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_prefKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Si no se puede leer la zona, queda UTC: mejor eso que no avisar.
    }
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
          requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
    ));
    _ready = true;
  }

  /// Pide permiso (Android 13+/iOS) y deja programado el aviso semanal,
  /// o lo cancela si el usuario lo desactivó.
  static Future<void> sincronizar() async {
    if (!soportado) return;
    try {
      await _init();
      if (!await recordatorioActivo()) {
        await _plugin.cancel(_idSabado);
        return;
      }
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
      await _programarSabado();
    } catch (e) {
      debugPrint('Notifs.sincronizar: $e');
    }
  }

  static Future<void> setRecordatorio(bool on) async {
    try {
      (await SharedPreferences.getInstance()).setBool(_prefKey, on);
    } catch (_) {}
    await sincronizar();
  }

  static tz.TZDateTime _proximoSabado1430() {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, 14, 30);
    d = d.add(Duration(days: (DateTime.saturday - d.weekday) % 7));
    if (!d.isAfter(now)) d = d.add(const Duration(days: 7));
    return d;
  }

  static Future<void> _programarSabado() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sabado',
        'Recordatorio del sábado',
        channelDescription: 'Aviso semanal de la actividad de los sábados',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    Future<void> programar(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          _idSabado,
          '¡¡TE ESPERAMOS!!',
          'Hoy a las 14:30 · Jazit Hanoar',
          _proximoSabado1430(),
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
    try {
      await programar(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // Sin permiso de alarmas exactas: puede demorar unos minutos.
      await programar(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  // ---- Avisos de novedades y chat (con la app abierta o en segundo plano) ----

  /// Sala de chat abierta en pantalla: no se avisa de sus mensajes.
  static String? salaActiva;
  static final _subs = <StreamSubscription>[];

  static bool get _enPrimerPlano =>
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  static Future<void> detener() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
  }

  static Future<void> _mostrar(int id, String canal, String canalNombre, String titulo, String cuerpo) {
    return _plugin.show(
      id,
      titulo,
      cuerpo,
      NotificationDetails(
        android: AndroidNotificationDetails(canal, canalNombre,
            importance: Importance.high, priority: Priority.high),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Escucha novedades y chats del usuario y muestra una notificación por cada
  /// elemento nuevo que no sea suyo. Lo anterior a la apertura de la app no avisa.
  static Future<void> escuchar(AppUser u) async {
    if (!soportado) return;
    await detener();
    try {
      await _init();

      // Novedades
      Set<String>? vistos;
      _subs.add(Db.anuncios(u).listen((lista) {
        if (vistos == null) {
          vistos = lista.map((a) => a.id).toSet();
          return;
        }
        for (final a in lista) {
          if (!vistos!.add(a.id) || a.autorUid == u.uid) continue;
          _mostrar(a.id.hashCode & 0x7fffffff, 'novedades', 'Novedades', a.titulo,
              a.cuerpo.isEmpty ? 'Nueva novedad' : a.cuerpo);
        }
      }));

      // Chats
      final ks = await Db.kuvthzot().first;
      for (final room in chatsFor(u, ks)) {
        String? ultimo;
        var primero = true;
        _subs.add(Db.ultimoMensaje(room.id).listen((m) {
          if (primero) {
            primero = false;
            ultimo = m?.id;
            return;
          }
          if (m == null || m.id == ultimo) return;
          ultimo = m.id;
          if (m.uid == u.uid) return;
          if (_enPrimerPlano && salaActiva == room.id) return;
          _mostrar(room.id.hashCode & 0x7fffffff, 'chat', 'Chat', room.titulo, '${m.autor}: ${m.texto}');
        }));
      }
    } catch (e) {
      debugPrint('Notifs.escuchar: $e');
    }
  }
}
