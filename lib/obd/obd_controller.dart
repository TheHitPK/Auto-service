import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'elm327.dart';
import 'transporte.dart';

enum EstadoObd { desconectado, conectando, conectado }

class DatosVivos {
  int? rpm;
  int? temperatura;
  int? velocidad;
  int? carga;
  int? acelerador;
  double? voltaje;
}

class ObdController extends ChangeNotifier {
  static const _claveUltimo = 'obd_ultimo';

  EstadoObd estado = EstadoObd.desconectado;
  String mensaje = 'Desconectado';
  bool error = false;
  DispositivoObd? dispositivo;
  DatosVivos datos = DatosVivos();

  /// Luz Check Engine y cantidad de códigos según la computadora (PID 01).
  bool? checkEngine;
  int? cantidadCodigos;

  /// null = todavía no se han leído.
  List<String>? almacenados;
  List<String>? pendientes;
  bool leyendoCodigos = false;

  Elm327? _elm;
  TransporteObd? _transporte;
  int _sesion = 0;

  bool get conectado => estado == EstadoObd.conectado;
  String get adaptador => _elm?.version ?? '';

  /// Pide los permisos de Bluetooth. La ubicación solo existe en el manifiesto
  /// para Android 11 o inferior, donde el escaneo BLE la exige.
  Future<bool> pedirPermisos() async {
    final r = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    await Permission.locationWhenInUse.request();
    return r.values.every((e) => e.isGranted);
  }

  Future<List<DispositivoObd>> emparejados() => TransporteClasico.emparejados();

  Future<DispositivoObd?> ultimoDispositivo() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_claveUltimo);
    if (crudo == null) return null;
    return DispositivoObd.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
  }

  /// Al abrir la app en el estéreo: reconecta con el último adaptador sin preguntar.
  Future<void> reconectarUltimo() async {
    final ultimo = await ultimoDispositivo();
    if (ultimo == null || !await Permission.bluetoothConnect.isGranted) return;
    await conectar(ultimo);
  }

  Future<void> conectar(DispositivoObd d) async {
    await desconectar();
    final sesion = ++_sesion;
    dispositivo = d;
    estado = EstadoObd.conectando;
    error = false;
    mensaje = 'Conectando con ${d.etiqueta}...';
    notifyListeners();

    final transporte = _transporte = d.transporte();
    final elm = _elm = Elm327(transporte);
    try {
      await transporte.conectar();
      if (sesion != _sesion) return;
      mensaje = 'Iniciando comunicación con el auto...';
      notifyListeners();
      await elm.iniciar();
      if (sesion != _sesion) return;
    } catch (e) {
      if (sesion != _sesion) return;
      await _cerrar();
      _fallo(_describir(e));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveUltimo, jsonEncode(d));
    estado = EstadoObd.conectado;
    mensaje = 'Conectado a ${d.etiqueta}';
    notifyListeners();

    unawaited(transporte.desconectado.then((_) async {
      if (sesion != _sesion) return;
      await _cerrar();
      _fallo('Se perdió la conexión con el adaptador');
    }));
    unawaited(_sondear(sesion, elm));
  }

  Future<void> desconectar() async {
    _sesion++;
    await _cerrar();
    estado = EstadoObd.desconectado;
    error = false;
    mensaje = 'Desconectado';
    _limpiar();
    notifyListeners();
  }

  Future<void> leerCodigos() async {
    final elm = _elm;
    if (elm == null || !conectado || leyendoCodigos) return;
    final sesion = _sesion;
    leyendoCodigos = true;
    notifyListeners();
    try {
      final a = await elm.codigos(0x03);
      final p = await elm.codigos(0x07);
      if (sesion != _sesion) return;
      almacenados = a;
      pendientes = p.where((c) => !a.contains(c)).toList();
    } finally {
      leyendoCodigos = false;
      notifyListeners();
    }
  }

  Future<bool> borrarCodigos() async {
    final elm = _elm;
    if (elm == null || !conectado) return false;
    final ok = await elm.borrarCodigos();
    if (ok) await leerCodigos();
    return ok;
  }

  Future<void> _sondear(int sesion, Elm327 elm) async {
    var fallos = 0;
    while (sesion == _sesion) {
      try {
        final rpm = await elm.pid(0x0C);
        final temp = await elm.pid(0x05);
        final vel = await elm.pid(0x0D);
        final carga = await elm.pid(0x04);
        final acel = await elm.pid(0x11);
        final mil = await elm.pid(0x01);
        final voltaje = await elm.voltaje();
        if (sesion != _sesion) return;
        datos = DatosVivos()
          ..rpm = rpm != null && rpm.length >= 2 ? (rpm[0] * 256 + rpm[1]) ~/ 4 : null
          ..temperatura = temp != null ? temp[0] - 40 : null
          ..velocidad = vel?[0]
          ..carga = carga != null ? (carga[0] * 100 / 255).round() : null
          ..acelerador = acel != null ? (acel[0] * 100 / 255).round() : null
          ..voltaje = voltaje;
        if (mil != null) {
          checkEngine = mil[0] & 0x80 != 0;
          cantidadCodigos = mil[0] & 0x7F;
        }
        fallos = 0;
        notifyListeners();
      } on TimeoutException {
        if (sesion != _sesion) return;
        if (++fallos >= 3) {
          await _cerrar();
          _fallo('El adaptador dejó de responder');
          return;
        }
      } catch (e) {
        if (sesion != _sesion) return;
        await _cerrar();
        _fallo(_describir(e));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }

  void _fallo(String texto) {
    _sesion++;
    estado = EstadoObd.desconectado;
    error = true;
    mensaje = texto;
    _limpiar();
    notifyListeners();
  }

  void _limpiar() {
    datos = DatosVivos();
    checkEngine = null;
    cantidadCodigos = null;
    almacenados = null;
    pendientes = null;
    leyendoCodigos = false;
  }

  Future<void> _cerrar() async {
    final elm = _elm, transporte = _transporte;
    _elm = null;
    _transporte = null;
    try {
      await elm?.cerrar();
      await transporte?.cerrar();
    } catch (e) {
      debugPrint('Error al cerrar OBD: $e');
    }
  }

  String _describir(Object e) => switch (e) {
        ObdError() => e.mensaje,
        TimeoutException() => 'El adaptador no respondió. ¿Es un ELM327?',
        PlatformException() => 'No se pudo conectar: ${e.message ?? e.code}',
        _ => 'No se pudo conectar: $e',
      };
}
