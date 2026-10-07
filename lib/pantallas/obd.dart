import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../datos/dtc_catalogo.dart';
import '../main.dart';
import '../obd/obd_controller.dart';
import '../obd/transporte.dart';
import '../tema.dart';
import '../widgets.dart';
import 'registrar.dart';

class PantallaObd extends StatelessWidget {
  const PantallaObd({super.key});

  @override
  Widget build(BuildContext context) {
    final obd = Alcance.of(context).obd;
    return Pagina(
      titulo: 'Escáner OBD-II',
      child: ListenableBuilder(
        listenable: obd,
        builder: (context, _) => DosColumnas(
          izquierda: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Conexion(obd),
              if (obd.conectado) ...[
                const SizedBox(height: 16),
                _EnVivo(obd.datos),
              ],
            ],
          ),
          derecha: _Codigos(obd),
        ),
      ),
    );
  }
}

class _Conexion extends StatelessWidget {
  const _Conexion(this.obd);

  final ObdController obd;

  Future<void> _conectar(BuildContext context) async {
    final dispositivo = await showDialog<DispositivoObd>(
      context: context,
      builder: (_) => _Selector(obd),
    );
    if (dispositivo != null) await obd.conectar(dispositivo);
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = obd.estado != EstadoObd.desconectado;
    return Tarjeta(
      titulo: 'Adaptador Bluetooth',
      icono: Icons.bluetooth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LedObd(obd, tamano: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  obd.mensaje,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: obd.error ? colorPeligro : null,
                  ),
                ),
              ),
              if (obd.estado == EstadoObd.conectando)
                const SizedBox.square(
                    dimension: 24, child: CircularProgressIndicator(strokeWidth: 3)),
            ],
          ),
          if (obd.adaptador.isNotEmpty) ...[
            const SizedBox(height: 6),
            TextoTenue(obd.adaptador),
          ],
          const SizedBox(height: 14),
          ocupado
              ? OutlinedButton.icon(
                  onPressed: obd.desconectar,
                  icon: const Icon(Icons.link_off),
                  label: Text(obd.conectado ? 'Desconectar' : 'Cancelar'),
                )
              : FilledButton.icon(
                  onPressed: () => _conectar(context),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Conectar escáner'),
                ),
        ],
      ),
    );
  }
}

class _EnVivo extends StatelessWidget {
  const _EnVivo(this.d);

  final DatosVivos d;

  @override
  Widget build(BuildContext context) {
    final temp = d.temperatura;
    final voltaje = d.voltaje;
    final celdas = [
      _Medida('RPM', d.rpm?.toString()),
      _Medida('Velocidad', d.velocidad?.toString(), unidad: 'km/h'),
      _Medida(
        'Temperatura',
        temp?.toString(),
        unidad: '°C',
        color: temp == null
            ? null
            : (temp >= 105 ? colorPeligro : (temp >= 98 ? colorAviso : null)),
      ),
      _Medida('Carga motor', d.carga?.toString(), unidad: '%'),
      _Medida('Acelerador', d.acelerador?.toString(), unidad: '%'),
      _Medida(
        'Batería',
        voltaje?.toStringAsFixed(1),
        unidad: 'V',
        color: voltaje == null ? null : (voltaje < 11.8 ? colorPeligro : null),
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      const hueco = 12.0;
      final ancho = (c.maxWidth - hueco * 2) / 3;
      return Wrap(
        spacing: hueco,
        runSpacing: hueco,
        children: [for (final m in celdas) SizedBox(width: ancho, child: m)],
      );
    });
  }
}

class _Medida extends StatelessWidget {
  const _Medida(this.nombre, this.valor, {this.unidad = '', this.color});

  final String nombre;
  final String? valor;
  final String unidad;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(
          children: [
            FittedBox(
              child: Text(
                valor ?? '—',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color ?? colorPrimario,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            FittedBox(
              child: Text(
                unidad.isEmpty ? nombre.toUpperCase() : '${nombre.toUpperCase()} · $unidad',
                style: const TextStyle(fontSize: 13, color: colorTenue, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Codigos extends StatelessWidget {
  const _Codigos(this.obd);

  final ObdController obd;

  Future<void> _leer(BuildContext context) async {
    try {
      await obd.leerCodigos();
    } catch (e) {
      if (context.mounted) aviso(context, 'No se pudieron leer los códigos.');
    }
  }

  Future<void> _borrar(BuildContext context) async {
    final ok = await confirmar(
      context,
      '¿Borrar los códigos y apagar el Check Engine?\n\n'
      'Hazlo con el motor apagado y el encendido en ON. Si la falla sigue '
      'presente, el código volverá a aparecer.',
      accion: 'Borrar códigos',
    );
    if (!ok) return;
    try {
      final borrado = await obd.borrarCodigos();
      if (context.mounted) {
        aviso(context, borrado ? 'Códigos borrados.' : 'El auto no aceptó el borrado.');
      }
    } catch (e) {
      if (context.mounted) aviso(context, 'No se pudieron borrar los códigos.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final almacenados = obd.almacenados;
    final pendientes = obd.pendientes ?? const <String>[];
    final todos = [...?almacenados, ...pendientes];
    final mil = obd.checkEngine;
    return Tarjeta(
      titulo: 'Códigos de falla (DTC)',
      icono: Icons.report_problem,
      borde: todos.isNotEmpty ? colorPeligro : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!obd.conectado)
            const TextoTenue('Conecta el escáner para leer los errores de la computadora.')
          else ...[
            if (mil != null)
              Row(
                children: [
                  Icon(Icons.engineering, color: mil ? colorAviso : colorOk, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check Engine ${mil ? 'ENCENDIDO' : 'apagado'} · '
                      '${obd.cantidadCodigos} códigos confirmados',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: obd.leyendoCodigos ? null : () => _leer(context),
                    icon: obd.leyendoCodigos
                        ? const SizedBox.square(
                            dimension: 20, child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.search),
                    label: Text(obd.leyendoCodigos ? 'Leyendo...' : 'Leer códigos'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: colorPeligro),
                    onPressed: obd.leyendoCodigos ? null : () => _borrar(context),
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Borrar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (almacenados == null)
              const TextoTenue('Toca "Leer códigos" para consultar la computadora.')
            else if (todos.isEmpty)
              const Row(
                children: [
                  Icon(Icons.check_circle, color: colorOk, size: 30),
                  SizedBox(width: 10),
                  Text('Sin códigos de falla.', style: TextStyle(fontSize: 18)),
                ],
              )
            else ...[
              for (final c in almacenados) _Codigo(c, 'Confirmado', colorPeligro),
              for (final c in pendientes) _Codigo(c, 'Pendiente', colorAviso),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        PantallaRegistrar(descripcion: 'Códigos OBD: ${todos.join(', ')}'),
                  ),
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text('Anotar en el historial'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Codigo extends StatelessWidget {
  const _Codigo(this.codigo, this.tipo, this.color);

  final String codigo;
  final String tipo;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                codigo,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
              const Spacer(),
              Etiqueta(tipo, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(descripcionDtc(codigo), style: const TextStyle(fontSize: 17)),
        ],
      ),
    );
  }
}

/// Lista de adaptadores: los emparejados por Bluetooth clásico (la mayoría de
/// los ELM327) y los BLE que se encuentren cerca.
class _Selector extends StatefulWidget {
  const _Selector(this.obd);

  final ObdController obd;

  @override
  State<_Selector> createState() => _SelectorState();
}

class _SelectorState extends State<_Selector> {
  static final _pareceObd = RegExp(r'obd|elm|v-?link|vgate|icar|konnwei|viecar|veepeak',
      caseSensitive: false);

  String? _problema;
  bool _sinPermiso = false;
  List<DispositivoObd> _emparejados = [];
  List<DispositivoObd> _ble = [];
  bool _buscando = false;
  StreamSubscription<List<ScanResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _sub?.cancel();
    FlutterBluePlus.stopScan().catchError((_) {});
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _problema = null;
      _sinPermiso = false;
    });
    try {
      if (!await widget.obd.pedirPermisos()) {
        setState(() {
          _sinPermiso = true;
          _problema = 'La app necesita el permiso de "Dispositivos cercanos" para usar el Bluetooth.';
        });
        return;
      }
      if (!await TransporteClasico.encendido()) {
        setState(() => _problema = 'El Bluetooth está apagado. Enciéndelo en los ajustes del estéreo.');
        return;
      }
      final emparejados = await widget.obd.emparejados();
      // Los que parecen adaptadores OBD van primero.
      emparejados.sort((a, b) {
        final pa = _pareceObd.hasMatch(a.nombre) ? 0 : 1;
        final pb = _pareceObd.hasMatch(b.nombre) ? 0 : 1;
        return pa != pb ? pa - pb : a.etiqueta.compareTo(b.etiqueta);
      });
      if (!mounted) return;
      setState(() => _emparejados = emparejados);
      await _buscarBle();
    } catch (e) {
      if (mounted) setState(() => _problema = 'Error de Bluetooth: $e');
    }
  }

  Future<void> _buscarBle() async {
    try {
      if (!await FlutterBluePlus.isSupported) return;
      _sub ??= FlutterBluePlus.scanResults.listen((resultados) {
        if (!mounted) return;
        setState(() {
          _ble = [
            for (final r in resultados)
              if (r.device.platformName.isNotEmpty || r.advertisementData.advName.isNotEmpty)
                DispositivoObd(
                  nombre: r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : r.advertisementData.advName,
                  direccion: r.device.remoteId.str,
                  ble: true,
                ),
          ];
        });
      });
      setState(() => _buscando = true);
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      await FlutterBluePlus.isScanning.where((s) => !s).first;
    } catch (e) {
      debugPrint('Escaneo BLE no disponible: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Widget _fila(DispositivoObd d) {
    return ListTile(
      minTileHeight: 64,
      leading: Icon(d.ble ? Icons.bluetooth_audio : Icons.bluetooth,
          color: _pareceObd.hasMatch(d.nombre) ? colorOk : colorTenue, size: 30),
      title: Text(d.etiqueta, style: const TextStyle(fontSize: 18)),
      subtitle: Text(d.direccion),
      onTap: () => Navigator.pop(context, d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final problema = _problema;
    return AlertDialog(
      title: const Text('Elige tu escáner'),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 520,
        child: problema != null
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(problema, style: const TextStyle(fontSize: 17)),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const _Seccion('Emparejados (Bluetooth clásico)'),
                  if (_emparejados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextoTenue(
                          'Ninguno. Empareja el adaptador en Ajustes > Bluetooth del estéreo '
                          '(PIN 1234 o 0000) y vuelve aquí.'),
                    ),
                  for (final d in _emparejados) _fila(d),
                  _Seccion('Bluetooth LE cercanos', cargando: _buscando),
                  if (_ble.isEmpty && !_buscando)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextoTenue('No se encontraron adaptadores BLE.'),
                    ),
                  for (final d in _ble) _fila(d),
                ],
              ),
      ),
      actions: [
        if (_sinPermiso)
          OutlinedButton(onPressed: openAppSettings, child: const Text('Abrir ajustes')),
        if (problema != null)
          OutlinedButton(onPressed: _cargar, child: const Text('Reintentar'))
        else if (!_buscando)
          OutlinedButton(onPressed: _buscarBle, child: const Text('Buscar de nuevo')),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
      ],
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion(this.titulo, {this.cargando = false});

  final String titulo;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(titulo.toUpperCase(),
              style: const TextStyle(
                  fontSize: 13, color: colorPrimario, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          if (cargando) ...[
            const SizedBox(width: 10),
            const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}
