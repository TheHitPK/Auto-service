import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DispositivoObd {
  const DispositivoObd({required this.nombre, required this.direccion, required this.ble});

  final String nombre;
  final String direccion;
  final bool ble;

  String get etiqueta => nombre.isEmpty ? direccion : nombre;

  Map<String, dynamic> toJson() => {'nombre': nombre, 'direccion': direccion, 'ble': ble};

  factory DispositivoObd.fromJson(Map<String, dynamic> j) => DispositivoObd(
        nombre: j['nombre'] as String? ?? '',
        direccion: j['direccion'] as String? ?? '',
        ble: j['ble'] as bool? ?? false,
      );

  TransporteObd transporte() => ble ? TransporteBle(direccion) : TransporteClasico(direccion);
}

/// Canal serie hacia el adaptador ELM327, sea cual sea el tipo de Bluetooth.
abstract class TransporteObd {
  Stream<List<int>> get entrada;

  /// Se completa cuando el adaptador corta la conexión por su cuenta.
  Future<void> get desconectado;

  Future<void> conectar();
  Future<void> escribir(List<int> datos);
  Future<void> cerrar();
}

/// Bluetooth clásico (SPP), implementado en BtClassicChannel.kt.
class TransporteClasico implements TransporteObd {
  TransporteClasico(this.direccion);

  static const _metodos = MethodChannel('stereoapp/bt_classic');
  static const _eventos = EventChannel('stereoapp/bt_classic/datos');

  final String direccion;
  final _entrada = StreamController<List<int>>.broadcast();
  final _desconectado = Completer<void>();
  StreamSubscription<dynamic>? _sub;

  static Future<bool> encendido() async =>
      await _metodos.invokeMethod<bool>('encendido') ?? false;

  static Future<List<DispositivoObd>> emparejados() async {
    final lista = await _metodos.invokeListMethod<Map<dynamic, dynamic>>('emparejados') ?? [];
    return [
      for (final d in lista)
        DispositivoObd(
          nombre: d['nombre'] as String? ?? '',
          direccion: d['direccion'] as String,
          ble: false,
        ),
    ];
  }

  @override
  Stream<List<int>> get entrada => _entrada.stream;

  @override
  Future<void> get desconectado => _desconectado.future;

  @override
  Future<void> conectar() async {
    _sub = _eventos.receiveBroadcastStream().listen((evento) {
      if (evento is Uint8List) {
        _entrada.add(evento);
      } else if (!_desconectado.isCompleted) {
        _desconectado.complete();
      }
    });
    await _metodos.invokeMethod<void>('conectar', {'direccion': direccion});
  }

  @override
  Future<void> escribir(List<int> datos) =>
      _metodos.invokeMethod<void>('escribir', {'datos': Uint8List.fromList(datos)});

  @override
  Future<void> cerrar() async {
    await _sub?.cancel();
    await _metodos.invokeMethod<void>('desconectar');
  }
}

/// Bluetooth LE: los ELM327 BLE exponen un servicio serie con una
/// característica de notificación y otra de escritura (FFE0, FFF0, 18F0...).
class TransporteBle implements TransporteObd {
  TransporteBle(String direccion) : _device = BluetoothDevice.fromId(direccion);

  static const _serviciosConocidos = ['ffe0', 'fff0', '18f0'];

  final BluetoothDevice _device;
  final _entrada = StreamController<List<int>>.broadcast();
  final _desconectado = Completer<void>();
  final _subs = <StreamSubscription<dynamic>>[];
  BluetoothCharacteristic? _escritura;

  @override
  Stream<List<int>> get entrada => _entrada.stream;

  @override
  Future<void> get desconectado => _desconectado.future;

  @override
  Future<void> conectar() async {
    await _device.connect(timeout: const Duration(seconds: 15));
    final (notificacion, escritura) = _elegir(await _device.discoverServices());
    _escritura = escritura;
    _subs.add(notificacion.onValueReceived.listen(_entrada.add));
    await notificacion.setNotifyValue(true);
    _subs.add(_device.connectionState.listen((estado) {
      if (estado == BluetoothConnectionState.disconnected && !_desconectado.isCompleted) {
        _desconectado.complete();
      }
    }));
  }

  (BluetoothCharacteristic, BluetoothCharacteristic) _elegir(List<BluetoothService> servicios) {
    (BluetoothCharacteristic, BluetoothCharacteristic)? generico;
    for (final s in servicios) {
      BluetoothCharacteristic? notificacion, escritura;
      for (final c in s.characteristics) {
        final p = c.properties;
        if (p.notify || p.indicate) notificacion ??= c;
        if (p.write || p.writeWithoutResponse) escritura ??= c;
      }
      if (notificacion == null || escritura == null) continue;
      final uuid = s.uuid.str128.toLowerCase();
      if (_serviciosConocidos.any((k) => uuid.startsWith('0000$k-'))) {
        return (notificacion, escritura);
      }
      // Servicios estándar (GAP/GATT, 0x18xx) no son el puerto serie.
      if (!uuid.startsWith('000018')) generico ??= (notificacion, escritura);
    }
    if (generico == null) {
      throw StateError('El dispositivo no parece un adaptador OBD-II BLE');
    }
    return generico;
  }

  @override
  Future<void> escribir(List<int> datos) async {
    final c = _escritura;
    if (c == null) throw StateError('Sin conexión');
    await c.write(datos, withoutResponse: !c.properties.write);
  }

  @override
  Future<void> cerrar() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _device.disconnect();
  }
}
