import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'datos/catalogo.dart';
import 'servicios/notificaciones.dart';

String _dos(int n) => n.toString().padLeft(2, '0');

String formatoFecha(DateTime f) =>
    '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

String formatoKm(int km) {
  final s = km.abs().toString();
  final b = StringBuffer(km < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class Registro {
  Registro({
    required this.tipo,
    required this.servicioId,
    required this.km,
    required this.fecha,
    this.descripcion = '',
    this.costo = '',
    this.tipoAceite,
    this.viscosidad,
    this.marca,
    this.intervalo,
  });

  static const preventivo = 'preventivo';
  static const correctivo = 'correctivo';

  final String tipo;
  final String servicioId;
  final int km;
  final DateTime fecha;
  final String descripcion;
  final String costo;
  final String? tipoAceite;
  final String? viscosidad;
  final String? marca;
  final int? intervalo;

  bool get esPreventivo => tipo == preventivo;
  bool get esAceite => esPreventivo && servicioId == idAceite;

  /// Nombre legible, con el detalle del aceite si aplica.
  String get nombre {
    if (!esPreventivo) return descripcion.isEmpty ? 'Reparación' : descripcion;
    final base = servicioPorId(servicioId)?.nombre ?? servicioId;
    if (!esAceite) return base;
    final detalle = [tiposAceite[tipoAceite], viscosidad, marca]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    return detalle.isEmpty ? base : '$base ($detalle)';
  }

  Map<String, dynamic> toJson() => {
        'tipo': tipo,
        'servicioId': servicioId,
        'km': km,
        'fecha': fecha.toIso8601String(),
        'descripcion': descripcion,
        'costo': costo,
        'tipoAceite': ?tipoAceite,
        'viscosidad': ?viscosidad,
        'marca': ?marca,
        'intervalo': ?intervalo,
      };

  factory Registro.fromJson(Map<String, dynamic> j) => Registro(
        tipo: j['tipo'] as String? ?? preventivo,
        servicioId: j['servicioId'] as String? ?? '',
        km: (j['km'] as num?)?.toInt() ?? 0,
        fecha: DateTime.tryParse(j['fecha'] as String? ?? '') ?? DateTime.now(),
        descripcion: j['descripcion'] as String? ?? '',
        costo: j['costo'] as String? ?? '',
        tipoAceite: j['tipoAceite'] as String?,
        viscosidad: j['viscosidad'] as String?,
        marca: j['marca'] as String?,
        intervalo: (j['intervalo'] as num?)?.toInt(),
      );
}

class Proximo {
  Proximo(this.servicio, this.intervaloKm, this.ultimo, int kmActual)
      : kmProximo = (ultimo?.km ?? 0) + intervaloKm,
        kmFaltan = (ultimo?.km ?? 0) + intervaloKm - kmActual;

  final Servicio servicio;
  final int intervaloKm;
  final Registro? ultimo;
  final int kmProximo;
  final int kmFaltan;

  bool get vencido => kmFaltan <= 0;
  bool get cercano => !vencido && kmFaltan <= intervaloKm * 0.2;
}

enum Nivel { ok, proximo, urgente }

class EstadoAceite {
  EstadoAceite(this.registro, int kmActual, DateTime ahora)
      : dias = ahora.difference(registro.fecha).inDays,
        kmRecorridos = kmActual - registro.km,
        limite = registro.intervalo ?? intervaloPorTipoAceite[registro.tipoAceite] ?? 5000;

  static const diasLimite = 180;

  final Registro registro;
  final int dias;
  final int kmRecorridos;
  final int limite;

  Nivel get nivel {
    if (kmRecorridos >= limite || dias >= diasLimite) return Nivel.urgente;
    if (kmRecorridos >= limite * 0.8 || dias >= diasLimite - 30) return Nivel.proximo;
    return Nivel.ok;
  }

  String get etiqueta => switch (nivel) {
        Nivel.urgente => 'URGENTE',
        Nivel.proximo => 'Próximo',
        Nivel.ok => 'OK',
      };

  String get recomendacion => switch (nivel) {
        Nivel.urgente => '¡Cambia el aceite YA!',
        Nivel.proximo => 'Prepárate (${formatoKm(limite)} km o 6 meses).',
        Nivel.ok =>
          'Te quedan ${formatoKm(limite - kmRecorridos)} km o ${diasLimite - dias} días.',
      };
}

class AppState extends ChangeNotifier {
  AppState({this.notificador});

  static const _clave = 'estado';

  final Notificador? notificador;

  String motor = 'T18SED';
  String modelo = 'DESIGN';
  String placa = '';
  int kmActual = 0;
  final List<Registro> historial = [];
  final Set<String> _notificados = {};
  bool notificacionesActivas = false;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo != null) {
      try {
        final j = jsonDecode(crudo) as Map<String, dynamic>;
        motor = j['motor'] as String? ?? motor;
        modelo = j['modelo'] as String? ?? modelo;
        placa = j['placa'] as String? ?? '';
        kmActual = (j['kmActual'] as num?)?.toInt() ?? 0;
        historial
          ..clear()
          ..addAll((j['historial'] as List? ?? [])
              .map((e) => Registro.fromJson(Map<String, dynamic>.from(e as Map))));
        _notificados
          ..clear()
          ..addAll((j['notificados'] as List? ?? []).cast<String>());
      } catch (e) {
        debugPrint('Estado guardado ilegible: $e');
      }
    }
    notificacionesActivas = await notificador?.activas() ?? false;
    notifyListeners();
    await verificarVencimientos();
  }

  Future<void> _guardar() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _clave,
      jsonEncode({
        'motor': motor,
        'modelo': modelo,
        'placa': placa,
        'kmActual': kmActual,
        'historial': historial,
        'notificados': _notificados.toList(),
      }),
    );
    await verificarVencimientos();
  }

  // ---- Consultas ----

  Registro? ultimoRegistro(String servicioId) {
    Registro? mejor;
    for (final r in historial) {
      if (!r.esPreventivo || r.servicioId != servicioId) continue;
      if (mejor == null || r.km > mejor.km) mejor = r;
    }
    return mejor;
  }

  /// Servicios del plan ordenados del más urgente al más lejano.
  List<Proximo> proximos() {
    final lista = servicios.map((s) {
      final ultimo = ultimoRegistro(s.id);
      // El aceite usa el intervalo con el que se registró el último cambio.
      final intervalo = (s.id == idAceite ? ultimo?.intervalo : null) ?? s.intervaloKm;
      return Proximo(s, intervalo, ultimo, kmActual);
    }).toList();
    lista.sort((a, b) => a.kmFaltan.compareTo(b.kmFaltan));
    return lista;
  }

  int get vencidos => proximos().where((p) => p.vencido).length;

  EstadoAceite? get aceite {
    final ultimo = ultimoRegistro(idAceite);
    return ultimo == null ? null : EstadoAceite(ultimo, kmActual, DateTime.now());
  }

  /// Historial del más reciente al más antiguo, opcionalmente filtrado por tipo.
  List<Registro> historialOrdenado([String? tipo]) {
    final lista = historial.where((r) => tipo == null || r.tipo == tipo).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  // ---- Cambios ----

  Future<void> guardarConfig({
    required String modelo,
    required String placa,
    required String motor,
    required int kmActual,
  }) {
    this.modelo = modelo;
    this.placa = placa.trim().toUpperCase();
    this.motor = motor;
    this.kmActual = kmActual;
    return _guardar();
  }

  Future<void> actualizarKm(int km) {
    kmActual = km;
    return _guardar();
  }

  Future<void> registrar(Registro r) {
    historial.add(r);
    if (r.km > kmActual) kmActual = r.km;
    if (r.esPreventivo) _notificados.remove(r.servicioId);
    return _guardar();
  }

  Future<void> eliminar(Registro r) {
    historial.remove(r);
    return _guardar();
  }

  Future<void> borrarHistorial() {
    historial.clear();
    _notificados.clear();
    return _guardar();
  }

  String exportarCsv() {
    String celda(Object v) => '"${v.toString().replaceAll('"', '""')}"';
    final b = StringBuffer('Fecha,Kilometraje,Tipo,Servicio/Reparación,Costo\n');
    for (final r in historialOrdenado()) {
      b.writeln([
        formatoFecha(r.fecha),
        r.km,
        r.esPreventivo ? 'Preventivo' : 'Correctivo',
        r.nombre,
        r.costo,
      ].map(celda).join(','));
    }
    return b.toString();
  }

  // ---- Notificaciones ----

  Future<bool> activarNotificaciones() async {
    notificacionesActivas = await notificador?.solicitarPermiso() ?? false;
    notifyListeners();
    await verificarVencimientos();
    return notificacionesActivas;
  }

  /// Avisa una sola vez por cada servicio que pasa a estar vencido.
  Future<void> verificarVencimientos() async {
    final n = notificador;
    if (n == null || !notificacionesActivas) return;
    final vencidos = proximos().where((p) => p.vencido).toList();
    final ids = vencidos.map((p) => p.servicio.id).toSet();
    final antes = _notificados.length;
    _notificados.removeWhere((id) => !ids.contains(id));
    var cambio = _notificados.length != antes;
    for (final p in vencidos) {
      if (!_notificados.add(p.servicio.id)) continue;
      cambio = true;
      await n.mostrar(
        servicios.indexOf(p.servicio),
        '${p.servicio.nombre} VENCIDO',
        'Vencido por ${formatoKm(-p.kmFaltan)} km. ¡Atiéndelo!',
      );
    }
    if (!cambio) return;
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo == null) return;
    final j = jsonDecode(crudo) as Map<String, dynamic>;
    j['notificados'] = _notificados.toList();
    await prefs.setString(_clave, jsonEncode(j));
  }
}
