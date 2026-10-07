import 'dart:async';
import 'dart:convert';

import 'transporte.dart';

class ObdError implements Exception {
  ObdError(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Líneas útiles de una respuesta del ELM327: sin espacios, en mayúsculas
/// y sin los avisos de estado del adaptador.
List<String> lineasElm(String crudo) => crudo
    .split(RegExp(r'[\r\n]+'))
    .map((l) => l.replaceAll(' ', '').toUpperCase())
    .where((l) => l.isNotEmpty && !l.startsWith('SEARCHING') && !l.startsWith('BUSINIT'))
    .toList();

String _decodificarDtc(String hex4) {
  final n = int.parse(hex4[0], radix: 16);
  return '${'PCBU'[n >> 2]}${n & 3}${hex4.substring(1)}';
}

/// Extrae los códigos de falla de la respuesta a los modos 03, 07 o 0A.
///
/// En CAN el primer byte tras el modo es la cantidad de códigos, y las
/// respuestas largas llegan partidas en tramas ("0:", "1:"...). En los
/// protocolos antiguos cada línea trae hasta 3 códigos rellenados con 0000.
List<String> parsearDtc(String crudo, {required int modo, required bool can}) {
  final prefijo = (0x40 + modo).toRadixString(16).toUpperCase();
  final mensajes = <String>[];
  var multitrama = false;
  for (final linea in lineasElm(crudo)) {
    if (can && RegExp(r'^[0-9A-F]{3}$').hasMatch(linea)) {
      mensajes.add('');
      multitrama = true;
    } else if (multitrama && RegExp(r'^[0-9A-F]:').hasMatch(linea)) {
      mensajes.last += linea.substring(2);
    } else {
      mensajes.add(linea);
      multitrama = false;
    }
  }

  final codigos = <String>{};
  for (final m in mensajes) {
    if (!m.startsWith(prefijo) || !RegExp(r'^[0-9A-F]+$').hasMatch(m)) continue;
    var datos = m.substring(2);
    var maximo = datos.length ~/ 4;
    if (can) {
      if (datos.length < 2) continue;
      final cantidad = int.parse(datos.substring(0, 2), radix: 16);
      datos = datos.substring(2);
      maximo = cantidad < datos.length ~/ 4 ? cantidad : datos.length ~/ 4;
    }
    for (var i = 0; i < maximo; i++) {
      final hex = datos.substring(i * 4, i * 4 + 4);
      if (hex != '0000') codigos.add(_decodificarDtc(hex));
    }
  }
  return codigos.toList();
}

/// Bytes de datos de la respuesta a un PID del modo 01, o null si no hay dato.
List<int>? parsearPid(String crudo, int pid) {
  final prefijo = '41${pid.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  for (final linea in lineasElm(crudo)) {
    if (!linea.startsWith(prefijo)) continue;
    final datos = linea.substring(4);
    if (datos.length < 2 || !RegExp(r'^[0-9A-F]+$').hasMatch(datos)) continue;
    return [
      for (var k = 0; k + 2 <= datos.length; k += 2)
        int.parse(datos.substring(k, k + 2), radix: 16),
    ];
  }
  return null;
}

/// Conversación con un adaptador ELM327: un comando a la vez, cada
/// respuesta termina con el prompt '>'.
class Elm327 {
  Elm327(this._transporte) {
    _sub = _transporte.entrada.listen(_alRecibir);
  }

  final TransporteObd _transporte;
  late final StreamSubscription<List<int>> _sub;
  final _buffer = StringBuffer();
  Completer<String>? _pendiente;
  Future<void> _cola = Future.value();

  String version = '';
  bool can = false;

  void _alRecibir(List<int> datos) {
    for (final b in datos) {
      if (b == 0x3E) {
        _pendiente?.complete(_buffer.toString());
        _pendiente = null;
        _buffer.clear();
      } else if (b != 0) {
        _buffer.writeCharCode(b);
      }
    }
  }

  Future<String> comando(String cmd, {Duration espera = const Duration(seconds: 5)}) {
    final r = _cola.then((_) => _enviar(cmd, espera));
    _cola = r.then((_) {}, onError: (_) {});
    return r;
  }

  Future<String> _enviar(String cmd, Duration espera) async {
    _buffer.clear();
    final c = _pendiente = Completer<String>();
    try {
      await _transporte.escribir(ascii.encode('$cmd\r'));
      return await c.future.timeout(espera);
    } finally {
      if (identical(_pendiente, c)) _pendiente = null;
    }
  }

  /// Configura el adaptador y abre la comunicación con la computadora del auto.
  Future<void> iniciar() async {
    try {
      final r = lineasElm(await comando('ATZ', espera: const Duration(seconds: 6)));
      version = r.where((l) => l.contains('ELM')).firstOrNull ?? '';
    } on TimeoutException {
      // Algunos clones no responden al reinicio pero sí al resto.
    }
    for (final cmd in ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
      await comando(cmd);
    }
    final r = await comando('0100', espera: const Duration(seconds: 15));
    if (parsearPid(r, 0x00) == null) {
      throw ObdError('El adaptador no logró comunicarse con el auto. '
          'Verifica que el encendido esté en ON.');
    }
    // Responde p. ej. "A6": automático, protocolo 6. Del 6 en adelante son CAN.
    final p = lineasElm(await comando('ATDPN')).firstOrNull ?? '';
    final numero = p.isEmpty ? '' : p[p.length - 1];
    can = '6789ABC'.contains(numero) && numero.isNotEmpty;
  }

  Future<List<int>?> pid(int pid) async =>
      parsearPid(await comando('01${pid.toRadixString(16).padLeft(2, '0')}'), pid);

  Future<double?> voltaje() async {
    final m = RegExp(r'(\d+\.\d+)').firstMatch(await comando('ATRV'));
    return m == null ? null : double.tryParse(m.group(1)!);
  }

  /// Modo 03 = almacenados, 07 = pendientes.
  Future<List<String>> codigos(int modo) async {
    final r = await comando(modo.toRadixString(16).padLeft(2, '0'),
        espera: const Duration(seconds: 10));
    return parsearDtc(r, modo: modo, can: can);
  }

  /// Borra los códigos y apaga el Check Engine (modo 04).
  Future<bool> borrarCodigos() async {
    final r = await comando('04', espera: const Duration(seconds: 10));
    return lineasElm(r).any((l) => l.startsWith('44'));
  }

  Future<void> cerrar() => _sub.cancel();
}
