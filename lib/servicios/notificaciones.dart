import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract class Notificador {
  Future<bool> activas();
  Future<bool> solicitarPermiso();
  Future<void> mostrar(int id, String titulo, String cuerpo);
}

class NotificadorLocal implements Notificador {
  final _plugin = FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _ios =>
      _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

  Future<void> iniciar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // El permiso se pide cuando el usuario toca "Notificaciones", no al abrir.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  @override
  Future<bool> activas() async =>
      await _android?.areNotificationsEnabled() ??
      (await _ios?.checkPermissions())?.isEnabled ??
      false;

  @override
  Future<bool> solicitarPermiso() async =>
      await _android?.requestNotificationsPermission() ??
      await _ios?.requestPermissions(alert: true, badge: true, sound: true) ??
      false;

  @override
  Future<void> mostrar(int id, String titulo, String cuerpo) => _plugin.show(
        id: id,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mantenimiento',
            'Mantenimientos vencidos',
            channelDescription: 'Avisos de servicios que ya pasaron su kilometraje',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
}
