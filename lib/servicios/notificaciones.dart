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

  Future<void> iniciar() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  @override
  Future<bool> activas() async => await _android?.areNotificationsEnabled() ?? false;

  @override
  Future<bool> solicitarPermiso() async =>
      await _android?.requestNotificationsPermission() ?? false;

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
        ),
      );
}
