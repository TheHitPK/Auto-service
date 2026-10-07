import 'package:flutter/material.dart';

import '../estado_app.dart';
import '../main.dart';
import '../obd/obd_controller.dart';
import '../servicios/trip_gps.dart';
import '../tema.dart';
import '../widgets.dart';

Color colorRendimiento(double kmL, AppState app) {
  final rango = app.rangoConsumo;
  if (kmL < rango.min * 0.85) return colorPeligro;
  return kmL < rango.min ? colorAviso : colorOk;
}

double? _decimal(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

class PantallaCombustible extends StatelessWidget {
  const PantallaCombustible({super.key});

  @override
  Widget build(BuildContext context) {
    final alcance = Alcance.of(context);
    final app = alcance.app;
    return Pagina(
      titulo: 'Combustible',
      child: ListenableBuilder(
        listenable: Listenable.merge([app, alcance.obd, alcance.gps]),
        builder: (context, _) => DosColumnas(
          izquierda: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Trip(app, alcance.obd, alcance.gps),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colorOk,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(64, 76),
                  textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                onPressed: () =>
                    showDialog<void>(context: context, builder: (_) => const _DialogoCarga()),
                icon: const Icon(Icons.local_gas_station, size: 30),
                label: const Text('Registrar carga'),
              ),
              const SizedBox(height: 16),
              _Estadisticas(app),
            ],
          ),
          derecha: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Diagnostico(app.diagnosticoConsumo),
              const SizedBox(height: 16),
              _Cargas(app),
            ],
          ),
        ),
      ),
    );
  }
}

class _Trip extends StatelessWidget {
  const _Trip(this.app, this.obd, this.gps);

  final AppState app;
  final ObdController obd;
  final TripGps gps;

  Future<void> _alternarGps(BuildContext context) async {
    if (gps.activo) return gps.detener();
    final problema = await gps.iniciar();
    if (context.mounted) aviso(context, problema ?? 'Trip por GPS iniciado.');
  }

  @override
  Widget build(BuildContext context) {
    final grabando = gps.activo || obd.conectado;
    final estado = gps.activo
        ? 'Midiendo con GPS'
        : (obd.conectado ? 'Midiendo con OBD' : 'Inactivo: conecta el OBD o usa el GPS');
    final desde = app.tripDesde;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF14507A), Color(0xFF0A2D47)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('KM DESDE LA ÚLTIMA CARGA',
              style: TextStyle(fontSize: 13, letterSpacing: 2, color: Colors.white70)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatoDecimal(app.tripKm)} km',
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            'Odómetro: ${formatoKm(app.kmActual)} km'
            '${desde == null ? '' : ' · desde ${formatoFecha(desde)}'}',
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.circle, size: 12, color: grabando ? colorOk : colorTenue),
              const SizedBox(width: 8),
              Expanded(child: Text(estado, style: const TextStyle(fontSize: 15))),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (await confirmar(context, '¿Reiniciar el trip a 0?', accion: 'Reiniciar')) {
                      await app.reiniciarTrip();
                    }
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reiniciar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _alternarGps(context),
                  icon: Icon(gps.activo ? Icons.stop_circle : Icons.satellite_alt),
                  label: Text(gps.activo ? 'Parar GPS' : 'Usar GPS'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Estadisticas extends StatelessWidget {
  const _Estadisticas(this.app);

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final tramos = app.tramos;
    if (tramos.isEmpty) {
      return const Tarjeta(
        titulo: 'Estadísticas',
        icono: Icons.bar_chart,
        child: TextoTenue('Registra al menos 2 cargas llenas para ver el rendimiento.'),
      );
    }
    final ultimo = tramos.last;
    final ultimos = tramos.length > 5 ? tramos.sublist(tramos.length - 5) : tramos;
    final promedio = ultimos.fold(0.0, (s, t) => s + t.kmL) / ultimos.length;
    final costos = [for (final t in tramos) ?t.costoKm];
    final costoKm = costos.isEmpty ? null : costos.reduce((a, b) => a + b) / costos.length;
    Widget fila(Widget a, Widget b) => Row(
          children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
        );
    return Tarjeta(
      titulo: 'Estadísticas',
      icono: Icons.bar_chart,
      child: Column(
        children: [
          fila(
            _Cifra('Último rendimiento', formatoDecimal(ultimo.kmL), 'km/L',
                color: colorRendimiento(ultimo.kmL, app)),
            _Cifra('Último consumo', formatoDecimal(ultimo.l100), 'L/100 km'),
          ),
          const SizedBox(height: 12),
          fila(
            _Cifra('Promedio (${ultimos.length})', formatoDecimal(promedio), 'km/L'),
            _Cifra('Costo por km', costoKm == null ? '—' : formatoDecimal(costoKm, 2), ''),
          ),
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.nombre, this.valor, this.unidad, {this.color});

  final String nombre;
  final String valor;
  final String unidad;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(nombre.toUpperCase(),
            style: const TextStyle(fontSize: 12, color: colorTenue, letterSpacing: 0.5)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(
            TextSpan(
              text: valor,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color),
              children: [
                TextSpan(
                  text: unidad.isEmpty ? '' : ' $unidad',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: colorTenue),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Diagnostico extends StatelessWidget {
  const _Diagnostico(this.d);

  final DiagnosticoConsumo d;

  @override
  Widget build(BuildContext context) {
    final color = switch (d.nivel) {
      NivelConsumo.sinDatos => colorTenue,
      NivelConsumo.alto => colorPeligro,
      NivelConsumo.normal => colorOk,
      NivelConsumo.bajo => colorPrimario,
    };
    final rango = 'Rango normal ${d.rango.nombre}: '
        '${formatoDecimal(d.rango.min)} – ${formatoDecimal(d.rango.max)} km/L';
    return Tarjeta(
      titulo: 'Diagnóstico de consumo',
      icono: Icons.monitor_heart,
      borde: d.nivel == NivelConsumo.sinDatos ? null : color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.titulo, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text(d.mensaje),
          const SizedBox(height: 10),
          if (d.nivel != NivelConsumo.sinDatos) ...[
            Row(
              children: [
                Expanded(child: _Cifra('Promedio', formatoDecimal(d.kmL), 'km/L')),
                Expanded(child: _Cifra('Consumo', formatoDecimal(d.l100), 'L/100 km')),
              ],
            ),
            const SizedBox(height: 10),
          ],
          TextoTenue(d.nivel == NivelConsumo.sinDatos
              ? rango
              : '$rango. Basado en ${d.tramos == 1 ? 'el último tramo' : 'los últimos ${d.tramos} tramos'}.'),
          for (final r in d.recomendaciones)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_right, color: color),
                  Expanded(child: Text(r)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Cargas extends StatelessWidget {
  const _Cargas(this.app);

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final cargas = app.cargasOrdenadas.reversed.toList();
    return Tarjeta(
      titulo: 'Historial de cargas',
      icono: Icons.receipt_long,
      child: cargas.isEmpty
          ? const TextoTenue('No hay cargas registradas.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, c) in cargas.indexed) ...[
                  if (i > 0) const Divider(),
                  _FilaCarga(app, c),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: colorPeligro),
                  onPressed: () async {
                    if (await confirmar(context, '¿Borrar las ${cargas.length} cargas registradas?',
                        accion: 'Borrar todas')) {
                      await app.borrarCargas();
                    }
                  },
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Borrar todas las cargas'),
                ),
              ],
            ),
    );
  }
}

class _FilaCarga extends StatelessWidget {
  const _FilaCarga(this.app, this.c);

  final AppState app;
  final Carga c;

  @override
  Widget build(BuildContext context) {
    final r = app.rendimiento(c);
    final total = c.costoTotal;
    final detalle = [
      '${formatoDecimal(c.litros, 2)} L',
      if (total != null) 'total ${formatoDecimal(total, 2)}',
      if (r != null) '${formatoDecimal(r.km)} km por ${c.fuenteKm}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${formatoKm(c.odometro)} km',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                TextoTenue('${formatoFecha(c.fecha)} · $detalle'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // El rendimiento de una carga parcial no dice nada: no se muestra.
          if (!c.tanqueLleno)
            const Etiqueta('Parcial', color: colorAviso)
          else if (r != null)
            Etiqueta('${formatoDecimal(r.kmL)} km/L', color: colorRendimiento(r.kmL, app)),
          IconButton(
            tooltip: 'Eliminar',
            iconSize: 28,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.delete_outline, color: colorTenue),
            onPressed: () async {
              if (await confirmar(context, '¿Eliminar esta carga?', accion: 'Eliminar')) {
                await app.eliminarCarga(c);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _DialogoCarga extends StatefulWidget {
  const _DialogoCarga();

  @override
  State<_DialogoCarga> createState() => _DialogoCargaState();
}

class _DialogoCargaState extends State<_DialogoCarga> {
  final _litros = TextEditingController();
  final _odometro = TextEditingController();
  final _precio = TextEditingController();
  bool _lleno = true;

  @override
  void dispose() {
    _litros.dispose();
    _odometro.dispose();
    _precio.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final app = Alcance.of(context).app;
    final Carga carga;
    try {
      carga = app.nuevaCarga(
        litros: _decimal(_litros.text) ?? 0,
        odometro: int.tryParse(_odometro.text),
        precioL: _decimal(_precio.text),
        tanqueLleno: _lleno,
      );
    } on FormatException catch (e) {
      return aviso(context, e.message);
    }
    if (app.discrepaConTrip(carga) &&
        !await confirmar(
          context,
          'El trip marca ${formatoDecimal(app.tripKm)} km y el odómetro '
          '${formatoDecimal(carga.kmRecorridos)} km.\n\nSe usará el odómetro, que es más fiable.',
          accion: 'Continuar',
        )) {
      return;
    }
    await app.registrarCarga(carga);
    if (!mounted) return;
    final rendimiento = carga.kmRecorridos > 0
        ? ' · ${formatoDecimal(carga.kmRecorridos / carga.litros)} km/L'
        : '';
    aviso(context, 'Carga registrada: ${formatoDecimal(carga.litros, 2)} L$rendimiento');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    final ultima = app.ultimaCarga;
    const separador = SizedBox(height: 14);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: const Text('Registrar carga'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _litros,
                autofocus: true,
                keyboardType: decimal,
                decoration: const InputDecoration(labelText: 'Litros cargados', suffixText: 'L'),
              ),
              separador,
              TextField(
                controller: _odometro,
                keyboardType: TextInputType.number,
                inputFormatters: soloDigitos,
                decoration: InputDecoration(
                  labelText: 'Odómetro actual (recomendado)',
                  suffixText: 'km',
                  hintText: '${app.odometroEsperado}',
                  helperText: 'Vacío = se usa el trip (${formatoDecimal(app.tripKm)} km)',
                ),
              ),
              separador,
              TextField(
                controller: _precio,
                keyboardType: decimal,
                decoration: const InputDecoration(labelText: 'Precio por litro (opcional)'),
              ),
              separador,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Llené hasta el tope'),
                subtitle: const Text('Las cargas parciales no cuentan para el rendimiento'),
                value: _lleno,
                onChanged: (v) => setState(() => _lleno = v),
              ),
              TextoTenue(ultima == null
                  ? 'Primera carga: servirá de punto de partida.'
                  : 'Última carga a los ${formatoKm(ultima.odometro)} km.'),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirmar, child: const Text('Confirmar')),
      ],
    );
  }
}
