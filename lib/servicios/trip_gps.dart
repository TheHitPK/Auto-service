import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../estado_app.dart';

/// Mide el trip con el GPS, para quien no tiene escáner OBD.
/// Solo cuenta mientras la app está abierta.
class TripGps extends ChangeNotifier {
  TripGps(this._app);

  final AppState _app;
  StreamSubscription<Position>? _sub;
  Position? _anterior;

  bool get activo => _sub != null;

  /// Devuelve null si arrancó, o el motivo por el que no pudo.
  Future<String?> iniciar() async {
    if (activo) return null;
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'La ubicación está apagada en el dispositivo.';
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
    if (permiso == LocationPermission.denied || permiso == LocationPermission.deniedForever) {
      return 'Sin permiso de ubicación. Habilítalo en los ajustes de la app.';
    }
    _anterior = null;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(_alMoverse, onError: (Object e) {
      debugPrint('GPS: $e');
      detener();
    });
    notifyListeners();
    return null;
  }

  void _alMoverse(Position p) {
    final anterior = _anterior;
    _anterior = p;
    if (anterior == null) return;
    final metros =
        Geolocator.distanceBetween(anterior.latitude, anterior.longitude, p.latitude, p.longitude);
    // Saltos grandes entre dos lecturas son errores de señal, no recorrido.
    if (metros > 5 && metros < 500) _app.acumularDistancia(metros / 1000);
  }

  Future<void> detener() async {
    final sub = _sub;
    _sub = null;
    _anterior = null;
    await sub?.cancel();
    notifyListeners();
  }
}
