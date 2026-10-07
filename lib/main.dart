import 'dart:async';

import 'package:flutter/material.dart';

import 'estado_app.dart';
import 'obd/obd_controller.dart';
import 'pantallas/inicio.dart';
import 'servicios/notificaciones.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notificador = NotificadorLocal();
  try {
    await notificador.iniciar();
  } catch (e) {
    debugPrint('Notificaciones no disponibles: $e');
  }
  final app = AppState(notificador: notificador);
  await app.cargar();
  final obd = ObdController();
  unawaited(obd.reconectarUltimo());
  runApp(StereoApp(app: app, obd: obd));
}

/// Da acceso al estado de la app y al controlador OBD desde cualquier pantalla.
class Alcance extends InheritedWidget {
  const Alcance({super.key, required this.app, required this.obd, required super.child});

  final AppState app;
  final ObdController obd;

  static Alcance of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Alcance>()!;

  @override
  bool updateShouldNotify(Alcance oldWidget) => app != oldWidget.app || obd != oldWidget.obd;
}

class StereoApp extends StatelessWidget {
  const StereoApp({super.key, required this.app, required this.obd});

  final AppState app;
  final ObdController obd;

  @override
  Widget build(BuildContext context) {
    return Alcance(
      app: app,
      obd: obd,
      child: MaterialApp(
        title: 'StereoApp',
        debugShowCheckedModeBanner: false,
        theme: temaApp(),
        home: const PantallaInicio(),
      ),
    );
  }
}
