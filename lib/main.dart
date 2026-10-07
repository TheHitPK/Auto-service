import 'dart:async';

import 'package:flutter/material.dart';

import 'estado_app.dart';
import 'obd/obd_controller.dart';
import 'pantallas/inicio.dart';
import 'servicios/notificaciones.dart';
import 'servicios/trip_gps.dart';
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
  final gps = TripGps(app);
  final obd = ObdController()
    // Con el GPS midiendo, la velocidad del OBD contaría el recorrido dos veces.
    ..alVelocidad = (kmh) => app.acumularVelocidad(gps.activo ? null : kmh);
  unawaited(obd.reconectarUltimo());
  runApp(StereoApp(app: app, obd: obd, gps: gps));
}

/// Da acceso al estado de la app y a los controladores desde cualquier pantalla.
class Alcance extends InheritedWidget {
  const Alcance({
    super.key,
    required this.app,
    required this.obd,
    required this.gps,
    required super.child,
  });

  final AppState app;
  final ObdController obd;
  final TripGps gps;

  static Alcance of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Alcance>()!;

  @override
  bool updateShouldNotify(Alcance oldWidget) =>
      app != oldWidget.app || obd != oldWidget.obd || gps != oldWidget.gps;
}

class StereoApp extends StatelessWidget {
  const StereoApp({super.key, required this.app, required this.obd, required this.gps});

  final AppState app;
  final ObdController obd;
  final TripGps gps;

  @override
  Widget build(BuildContext context) {
    return Alcance(
      app: app,
      obd: obd,
      gps: gps,
      child: MaterialApp(
        title: 'StereoApp',
        debugShowCheckedModeBanner: false,
        theme: temaApp(),
        home: const PantallaInicio(),
      ),
    );
  }
}
