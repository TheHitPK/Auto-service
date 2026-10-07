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

/// Número con coma decimal, como se escribe en español.
String formatoDecimal(double n, [int decimales = 1]) =>
    n.toStringAsFixed(decimales).replaceAll('.', ',');

/// Acepta ISO 8601 (formato propio) y "dd/mm/aaaa, hh:mm" (backups del HTML).
DateTime? _leerFecha(Object? v) {
  if (v is! String) return null;
  final iso = DateTime.tryParse(v);
  if (iso != null) return iso;
  final m = RegExp(r'(\d{2})/(\d{2})/(\d{4}),?\s*(\d{2}):(\d{2})').firstMatch(v);
  if (m == null) return null;
  int n(int i) => int.parse(m.group(i)!);
  return DateTime(n(3), n(2), n(1), n(4), n(5));
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

  Registro editado({required int km, String? descripcion, String? costo}) => Registro(
        tipo: tipo,
        servicioId: servicioId,
        km: km,
        fecha: fecha,
        descripcion: descripcion ?? this.descripcion,
        costo: costo ?? this.costo,
        tipoAceite: tipoAceite,
        viscosidad: viscosidad,
        marca: marca,
        intervalo: intervalo,
      );

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
        fecha: _leerFecha(j['fecha']) ?? DateTime.now(),
        descripcion: j['descripcion'] as String? ?? '',
        costo: j['costo']?.toString() ?? '',
        tipoAceite: j['tipoAceite'] as String?,
        viscosidad: j['viscosidad'] as String?,
        marca: j['marca'] as String?,
        intervalo: (j['intervalo'] as num?)?.toInt(),
      );
}

enum EstadoServicio { vencido, revisar, proximo, ok }

class Proximo {
  Proximo(this.servicio, this.intervaloKm, this.ultimo, int kmBase, int kmActual)
      : kmProximo = (ultimo?.km ?? kmBase) + intervaloKm,
        kmFaltan = (ultimo?.km ?? kmBase) + intervaloKm - kmActual;

  final Servicio servicio;
  final int intervaloKm;
  final Registro? ultimo;
  final int kmProximo;
  final int kmFaltan;

  /// Sin registro previo no se sabe si está vencido: se marca "revisar".
  EstadoServicio get estado {
    if (kmFaltan <= 0) return ultimo == null ? EstadoServicio.revisar : EstadoServicio.vencido;
    if (kmFaltan <= intervaloKm * 0.15) return EstadoServicio.proximo;
    return EstadoServicio.ok;
  }

  bool get vencido => estado == EstadoServicio.vencido;
}

enum Nivel { ok, proximo, urgente }

class EstadoAceite {
  EstadoAceite(this.registro, int kmActual, DateTime ahora)
      : dias = ahora.difference(registro.fecha).inDays.clamp(0, 99999),
        kmRecorridos = (kmActual - registro.km).clamp(0, 9999999),
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
        Nivel.proximo => 'Prepárate (límite ${formatoKm(limite)} km o $diasLimite días).',
        Nivel.ok =>
          'Te quedan ${formatoKm(limite - kmRecorridos)} km o ${diasLimite - dias} días.',
      };
}

/// Una carga de combustible.
class Carga {
  Carga({
    required this.fecha,
    required this.odometro,
    required this.litros,
    required this.tanqueLleno,
    required this.kmRecorridos,
    required this.fuenteKm,
    this.precioL,
  });

  static const fuenteOdometro = 'odómetro';
  static const fuenteTrip = 'trip';

  final DateTime fecha;
  final int odometro;
  final double litros;
  final double? precioL;
  final bool tanqueLleno;

  /// Km desde la carga anterior; 0 en la primera carga.
  final double kmRecorridos;

  /// De dónde salió [kmRecorridos]: odómetro o trip.
  final String fuenteKm;

  double? get costoTotal => precioL == null ? null : litros * precioL!;

  Map<String, dynamic> toJson() => {
        'fecha': fecha.toIso8601String(),
        'odometro': odometro,
        'litros': litros,
        'precioL': ?precioL,
        'tanqueLleno': tanqueLleno,
        'kmRecorridos': kmRecorridos,
        'fuenteKm': fuenteKm,
      };

  factory Carga.fromJson(Map<String, dynamic> j) => Carga(
        fecha: _leerFecha(j['fecha']) ?? DateTime.now(),
        odometro: (j['odometro'] as num?)?.toInt() ?? 0,
        litros: (j['litros'] as num?)?.toDouble() ?? 0,
        precioL: (j['precioL'] as num?)?.toDouble(),
        tanqueLleno: j['tanqueLleno'] as bool? ?? true,
        kmRecorridos: (j['kmRecorridos'] as num?)?.toDouble() ?? 0,
        fuenteKm: j['fuenteKm'] as String? ?? '',
      );
}

/// Rendimiento de una carga respecto a la anterior.
class Rendimiento {
  Rendimiento(this.km, double litros, double? precioL)
      : kmL = km / litros,
        l100 = litros / km * 100,
        costoKm = precioL == null ? null : litros * precioL / km;

  final double km;
  final double kmL;
  final double l100;
  final double? costoKm;
}

enum NivelConsumo { sinDatos, alto, normal, bajo }

class DiagnosticoConsumo {
  DiagnosticoConsumo(this.nivel, this.rango, {this.kmL = 0, this.l100 = 0, this.tramos = 0});

  final NivelConsumo nivel;
  final RangoConsumo rango;
  final double kmL;
  final double l100;

  /// Cuántos tramos entre cargas se promediaron.
  final int tramos;

  String get titulo => switch (nivel) {
        NivelConsumo.sinDatos => 'Sin datos suficientes',
        NivelConsumo.alto => 'CONSUMO ALTO',
        NivelConsumo.normal => 'CONSUMO NORMAL',
        NivelConsumo.bajo => 'CONSUMO BAJO (óptimo)',
      };

  String get mensaje {
    final promedio = '${formatoDecimal(kmL)} km/L';
    return switch (nivel) {
      NivelConsumo.sinDatos =>
        'Registra al menos 3 cargas llenas para un diagnóstico fiable. '
            'Por ahora hay $tramos ${tramos == 1 ? 'tramo válido' : 'tramos válidos'}.',
      NivelConsumo.alto => 'Tu promedio ($promedio) está muy por debajo del rango normal de tu motor.',
      NivelConsumo.normal => 'Tu promedio ($promedio) está dentro del rango normal de tu motor.',
      NivelConsumo.bajo => 'Tu promedio ($promedio) es mejor que el rango normal. ¡Excelente eficiencia!',
    };
  }

  List<String> get recomendaciones => switch (nivel) {
        NivelConsumo.sinDatos => const [],
        NivelConsumo.alto => const [
            'Revisar bujías (desgaste o suciedad)',
            'Limpiar o reemplazar el filtro de aire',
            'Revisar el sensor MAF (puede estar sucio)',
            'Revisar el sensor de oxígeno (O2)',
            'Verificar la presión de los neumáticos (30–32 PSI)',
            'Revisar la inyección (inyectores sucios)',
            'Evitar aceleradas bruscas y frenadas innecesarias',
          ],
        NivelConsumo.normal => const [
            'Continúa con el mantenimiento preventivo regular.',
            'Mantén la presión de neumáticos adecuada.',
          ],
        NivelConsumo.bajo => const [
            'Mantén el estilo de conducción actual.',
            'Ten en cuenta que quizá la mayoría de tus trayectos son en carretera.',
          ],
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

  /// Odómetro al empezar a usar la app: base de los servicios sin registro.
  int kmInicial = 0;
  final List<Registro> historial = [];
  final List<Carga> cargas = [];

  /// Km recorridos desde la última carga, medidos por OBD o GPS.
  double tripKm = 0;
  DateTime? tripDesde;

  /// Rango de consumo personalizado; null = el estándar del motor.
  double? consumoMin;
  double? consumoMax;

  final Set<String> _notificados = {};
  bool notificacionesActivas = false;

  int? _velocidadAnterior;
  DateTime? _momentoAnterior;
  double _tripGuardado = 0;

  Map<String, dynamic> _aJson() => {
        'motor': motor,
        'modelo': modelo,
        'placa': placa,
        'kmActual': kmActual,
        'kmInicial': kmInicial,
        'historial': historial,
        'cargas': cargas,
        'trip': {'kmAcumulado': tripKm, 'desde': tripDesde?.toIso8601String()},
        'consumoMin': ?consumoMin,
        'consumoMax': ?consumoMax,
        'notificados': _notificados.toList(),
      };

  void _desdeJson(Map<String, dynamic> j) {
    List<T> lista<T>(String clave, T Function(Map<String, dynamic>) crear) => [
          for (final e in j[clave] as List? ?? [])
            if (e is Map) crear(Map<String, dynamic>.from(e)),
        ];
    final registros = lista('historial', Registro.fromJson);
    final repostajes = lista('cargas', Carga.fromJson);
    final trip = j['trip'] is Map ? j['trip'] as Map : const {};
    // El HTML guarda el rango como objeto y solo es propio si dice "personalizado".
    final rango = j['eficienciaEstandar'];
    final Map? propio = rango is Map && '${rango['label']}'.contains('personalizado') ? rango : null;

    motor = j['motor'] as String? ?? 'T18SED';
    modelo = j['modelo'] as String? ?? 'DESIGN';
    placa = j['placa'] as String? ?? '';
    kmActual = (j['kmActual'] as num?)?.toInt() ?? 0;
    kmInicial = (j['kmInicial'] as num?)?.toInt() ?? 0;
    historial
      ..clear()
      ..addAll(registros);
    cargas
      ..clear()
      ..addAll(repostajes);
    tripKm = (trip['kmAcumulado'] as num?)?.toDouble() ?? 0;
    tripDesde = _leerFecha(trip['desde']);
    consumoMin = ((propio == null ? j['consumoMin'] : propio['min']) as num?)?.toDouble();
    consumoMax = ((propio == null ? j['consumoMax'] : propio['max']) as num?)?.toDouble();
    final notificados = j['notificados'];
    _notificados
      ..clear()
      ..addAll(switch (notificados) {
        List() => notificados.whereType<String>(),
        Map() => notificados.keys.whereType<String>(),
        _ => const <String>[],
      });
    _tripGuardado = tripKm;
  }

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_clave);
    if (crudo != null) {
      try {
        _desdeJson(jsonDecode(crudo) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Estado guardado ilegible: $e');
      }
    }
    notificacionesActivas = await notificador?.activas() ?? false;
    notifyListeners();
    await verificarVencimientos();
  }

  Future<void> _persistir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, jsonEncode(_aJson()));
  }

  Future<void> _guardar() async {
    notifyListeners();
    await _persistir();
    await verificarVencimientos();
  }

  // ---- Mantenimiento ----

  Registro? ultimoRegistro(String servicioId) {
    Registro? mejor;
    for (final r in historial) {
      if (!r.esPreventivo || r.servicioId != servicioId) continue;
      if (mejor == null || r.km > mejor.km) mejor = r;
    }
    return mejor;
  }

  /// Servicios del plan: primero vencidos, luego por revisar, próximos y al día.
  List<Proximo> proximos() {
    final lista = servicios.map((s) {
      final ultimo = ultimoRegistro(s.id);
      // El aceite usa el intervalo con el que se registró el último cambio.
      final intervalo = (s.id == idAceite ? ultimo?.intervalo : null) ?? s.intervaloKm;
      return Proximo(s, intervalo, ultimo, kmInicial, kmActual);
    }).toList();
    lista.sort((a, b) {
      final prioridad = a.estado.index.compareTo(b.estado.index);
      return prioridad != 0 ? prioridad : a.kmFaltan.compareTo(b.kmFaltan);
    });
    return lista;
  }

  /// Servicios vencidos o por revisar.
  int get alertas => proximos().where((p) => p.estado.index <= EstadoServicio.revisar.index).length;

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

  Future<void> guardarConfig({
    required String modelo,
    required String placa,
    required String motor,
    required int kmActual,
    required int kmInicial,
    double? consumoMin,
    double? consumoMax,
  }) {
    this.modelo = modelo;
    this.placa = placa.trim().toUpperCase();
    this.motor = motor;
    this.kmActual = kmActual;
    this.kmInicial = kmInicial > kmActual ? kmActual : kmInicial;
    final valido = consumoMin != null && consumoMax != null && consumoMin > 0 && consumoMax > consumoMin;
    this.consumoMin = valido ? consumoMin : null;
    this.consumoMax = valido ? consumoMax : null;
    return _guardar();
  }

  Future<void> actualizarKm(int km) {
    kmActual = km;
    return _guardar();
  }

  Future<void> registrar(Registro r) {
    // Dos cambios de aceite al mismo kilometraje son una corrección, no otro cambio.
    final ultimo = r.esAceite ? ultimoRegistro(idAceite) : null;
    if (ultimo != null && ultimo.km == r.km) historial.remove(ultimo);
    historial.add(r);
    if (r.km > kmActual) kmActual = r.km;
    if (r.esPreventivo) _notificados.remove(r.servicioId);
    return _guardar();
  }

  Future<void> reemplazar(Registro viejo, Registro nuevo) {
    final i = historial.indexOf(viejo);
    if (i < 0) return Future.value();
    historial[i] = nuevo;
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

  // ---- Trip ----

  /// Integra la velocidad del OBD en distancia. Con null se descarta la
  /// muestra anterior (el adaptador se desconectó).
  void acumularVelocidad(int? kmh, [DateTime? ahora]) {
    ahora ??= DateTime.now();
    final velocidad = _velocidadAnterior, momento = _momentoAnterior;
    _velocidadAnterior = kmh;
    _momentoAnterior = kmh == null ? null : ahora;
    if (kmh == null || velocidad == null || momento == null) return;
    final segundos = ahora.difference(momento).inMilliseconds / 1000;
    // Un hueco largo entre muestras no es un tramo recorrido a esa velocidad.
    if (segundos <= 0 || segundos >= 30) return;
    acumularDistancia((velocidad + kmh) / 2 * segundos / 3600);
  }

  void acumularDistancia(double km) {
    if (km <= 0 || km >= 5) return;
    tripKm += km;
    tripDesde ??= DateTime.now();
    notifyListeners();
    if (tripKm - _tripGuardado > 0.3) {
      _tripGuardado = tripKm;
      _persistir();
    }
  }

  void _reiniciarTrip() {
    tripKm = 0;
    tripDesde = null;
    _tripGuardado = 0;
    _velocidadAnterior = null;
    _momentoAnterior = null;
  }

  Future<void> reiniciarTrip() {
    _reiniciarTrip();
    return _guardar();
  }

  // ---- Combustible ----

  RangoConsumo get rangoConsumo {
    final estandar = consumoEstandar(motor);
    final min = consumoMin, max = consumoMax;
    if (min == null || max == null) return estandar;
    return RangoConsumo(min, max, '${estandar.nombre}, personalizado');
  }

  /// Cargas de la más antigua a la más reciente.
  List<Carga> get cargasOrdenadas => [...cargas]..sort((a, b) => a.fecha.compareTo(b.fecha));

  Carga? get ultimaCarga => cargas.isEmpty ? null : cargasOrdenadas.last;

  /// Odómetro que debería marcar el auto según la última carga y el trip.
  int get odometroEsperado => (ultimaCarga?.odometro ?? kmActual) + tripKm.round();

  Rendimiento? rendimiento(Carga c) {
    if (c.litros <= 0) return null;
    if (c.kmRecorridos > 0) return Rendimiento(c.kmRecorridos, c.litros, c.precioL);
    final orden = cargasOrdenadas;
    final i = orden.indexOf(c);
    if (i <= 0) return null;
    final km = c.odometro - orden[i - 1].odometro;
    return km <= 0 ? null : Rendimiento(km.toDouble(), c.litros, c.precioL);
  }

  /// Rendimientos válidos: cargas a tanque lleno que tienen una carga anterior.
  List<Rendimiento> get tramos {
    final orden = cargasOrdenadas;
    return [
      for (final c in orden.skip(1))
        if (c.tanqueLleno) ?rendimiento(c),
    ];
  }

  DiagnosticoConsumo get diagnosticoConsumo {
    final todos = tramos;
    final rango = rangoConsumo;
    if (todos.length < 2) {
      return DiagnosticoConsumo(NivelConsumo.sinDatos, rango, tramos: todos.length);
    }
    final ultimos = todos.length > 5 ? todos.sublist(todos.length - 5) : todos;
    final kmL = ultimos.fold(0.0, (s, t) => s + t.kmL) / ultimos.length;
    final l100 = ultimos.fold(0.0, (s, t) => s + t.l100) / ultimos.length;
    final nivel = kmL < rango.min * 0.85
        ? NivelConsumo.alto
        : (kmL > rango.max * 1.15 ? NivelConsumo.bajo : NivelConsumo.normal);
    return DiagnosticoConsumo(nivel, rango, kmL: kmL, l100: l100, tramos: ultimos.length);
  }

  /// Arma la carga con los km recorridos desde la anterior: del odómetro si
  /// se indicó (más fiable), si no del trip. Lanza [FormatException] con el
  /// motivo si no hay con qué calcularlos.
  Carga nuevaCarga({
    required double litros,
    int? odometro,
    double? precioL,
    bool tanqueLleno = true,
  }) {
    if (litros <= 0) throw const FormatException('Ingresa los litros cargados.');
    final ultima = ultimaCarga;
    final double km;
    final String fuente;
    if (odometro != null && ultima != null) {
      km = (odometro - ultima.odometro).toDouble();
      fuente = Carga.fuenteOdometro;
      if (km <= 0) {
        throw FormatException(
            'El odómetro debe ser mayor que el de la última carga (${formatoKm(ultima.odometro)} km).');
      }
    } else if (tripKm > 0) {
      km = tripKm;
      fuente = Carga.fuenteTrip;
    } else if (odometro != null) {
      km = 0;
      fuente = '${Carga.fuenteOdometro} (primera carga)';
    } else {
      throw const FormatException('No hay trip acumulado: ingresa el odómetro.');
    }
    return Carga(
      fecha: DateTime.now(),
      odometro: odometro ?? odometroEsperado,
      litros: litros,
      precioL: precioL,
      tanqueLleno: tanqueLleno,
      kmRecorridos: km,
      fuenteKm: fuente,
    );
  }

  /// El trip y el odómetro no coinciden en los km de esta carga.
  bool discrepaConTrip(Carga c) =>
      c.fuenteKm == Carga.fuenteOdometro && tripKm > 5 && (tripKm - c.kmRecorridos).abs() > 10;

  Future<void> registrarCarga(Carga c) {
    cargas.add(c);
    if (c.odometro > kmActual) kmActual = c.odometro;
    _reiniciarTrip();
    return _guardar();
  }

  Future<void> eliminarCarga(Carga c) {
    cargas.remove(c);
    return _guardar();
  }

  Future<void> borrarCargas() {
    cargas.clear();
    return _guardar();
  }

  // ---- Exportar / respaldo ----

  static String _csv(List<String> encabezado, Iterable<List<Object?>> filas) {
    String celda(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final b = StringBuffer('${encabezado.join(',')}\n');
    for (final fila in filas) {
      b.writeln(fila.map(celda).join(','));
    }
    return b.toString();
  }

  String exportarCsv() => _csv(
        ['Fecha', 'Kilometraje', 'Tipo', 'Servicio/Reparación', 'Costo'],
        historialOrdenado().map((r) => [
              formatoFecha(r.fecha),
              r.km,
              r.esPreventivo ? 'Preventivo' : 'Correctivo',
              r.nombre,
              r.costo,
            ]),
      );

  String exportarCargasCsv() => _csv(
        ['Fecha', 'Odómetro', 'Litros', 'Precio/L', 'Total', 'Km recorridos', 'km/L', 'L/100km', 'Tanque lleno', 'Fuente km'],
        cargasOrdenadas.reversed.map((c) {
          final r = rendimiento(c);
          return [
            formatoFecha(c.fecha),
            c.odometro,
            formatoDecimal(c.litros, 2),
            c.precioL == null ? '' : formatoDecimal(c.precioL!, 2),
            c.costoTotal == null ? '' : formatoDecimal(c.costoTotal!, 2),
            r == null ? '' : formatoDecimal(r.km),
            r == null ? '' : formatoDecimal(r.kmL, 2),
            r == null ? '' : formatoDecimal(r.l100, 2),
            c.tanqueLleno ? 'Sí' : 'No',
            c.fuenteKm,
          ];
        }),
      );

  /// Todo el estado, para guardarlo fuera de la app.
  String exportarJson() => const JsonEncoder.withIndent('  ').convert(_aJson());

  /// Reemplaza todo el estado por el de un backup (propio o del HTML v2).
  /// Lanza [FormatException] si el archivo no es un backup.
  Future<void> restaurar(String json) async {
    Object? j;
    try {
      j = jsonDecode(json);
    } on FormatException {
      throw const FormatException('El archivo no es un JSON válido.');
    }
    // Por si el backup viene envuelto junto a metadatos.
    if (j is Map<String, dynamic> && j['estado'] is Map<String, dynamic>) j = j['estado'];
    if (j is! Map<String, dynamic> || (j['historial'] is! List && j['cargas'] is! List)) {
      throw const FormatException('El archivo no es un backup de StereoApp.');
    }
    final anterior = _aJson();
    try {
      _desdeJson(j);
    } catch (_) {
      _desdeJson(jsonDecode(jsonEncode(anterior)) as Map<String, dynamic>);
      throw const FormatException('El backup está dañado.');
    }
    await _guardar();
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
    if (cambio) await _persistir();
  }
}
