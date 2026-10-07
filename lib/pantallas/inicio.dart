import 'package:flutter/material.dart';

import '../estado_app.dart';
import '../main.dart';
import '../obd/obd_controller.dart';
import '../servicios/exportar.dart';
import '../tema.dart';
import '../widgets.dart';
import 'aceite.dart';
import 'combustible.dart';
import 'config.dart';
import 'diagnostico.dart';
import 'historial.dart';
import 'mantenimientos.dart';
import 'obd.dart';
import 'registrar.dart';

class _Acceso {
  _Acceso(this.icono, this.nombre, this.alTocar, {this.insignia, this.color = colorTenue});

  final IconData icono;
  final String nombre;
  final VoidCallback alTocar;
  final String? insignia;
  final Color color;
}

class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  void _abrir(BuildContext context, Widget pantalla) {
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => pantalla));
  }

  Future<void> _notificaciones(BuildContext context) async {
    final app = Alcance.of(context).app;
    if (app.notificacionesActivas) {
      aviso(context, 'Las notificaciones ya están activas.');
      return;
    }
    final ok = await app.activarNotificaciones();
    if (!context.mounted) return;
    aviso(
      context,
      ok
          ? 'Notificaciones activadas.'
          : 'Permiso denegado. Habilítalo en Ajustes > Aplicaciones > StereoApp.',
    );
  }

  List<_Acceso> _accesos(BuildContext context, AppState app, ObdController obd) {
    final aceite = app.aceite;
    final vencidos = app.alertas;
    final tramos = app.tramos;
    final codigos = obd.cantidadCodigos ?? 0;
    return [
      _Acceso(
        Icons.local_gas_station,
        'Combustible',
        () => _abrir(context, const PantallaCombustible()),
        insignia: tramos.isEmpty ? 'Sin datos' : '${formatoDecimal(tramos.last.kmL)} km/L',
        color: tramos.isEmpty ? colorTenue : colorRendimiento(tramos.last.kmL, app),
      ),
      _Acceso(
        Icons.oil_barrel,
        'Aceite',
        () => _abrir(context, const PantallaAceite()),
        insignia: aceite?.etiqueta ?? 'Sin registro',
        color: aceite == null ? colorTenue : colorNivel(aceite.nivel),
      ),
      _Acceso(
        Icons.build,
        'Mantenimientos',
        () => _abrir(context, const PantallaMantenimientos()),
        insignia: vencidos == 0 ? 'Al día' : '$vencidos por atender',
        color: vencidos == 0 ? colorOk : colorPeligro,
      ),
      _Acceso(
        Icons.bluetooth_searching,
        'OBD-II',
        () => _abrir(context, const PantallaObd()),
        insignia: switch (obd.estado) {
          EstadoObd.conectando => 'Conectando',
          EstadoObd.desconectado => 'Off',
          EstadoObd.conectado => codigos > 0 ? '$codigos códigos' : 'Conectado',
        },
        color: switch (obd.estado) {
          EstadoObd.conectando => colorAviso,
          EstadoObd.desconectado => colorTenue,
          EstadoObd.conectado => codigos > 0 ? colorPeligro : colorOk,
        },
      ),
      _Acceso(Icons.troubleshoot, 'Diagnóstico',
          () => _abrir(context, const PantallaDiagnostico())),
      _Acceso(Icons.edit_note, 'Registrar', () => _abrir(context, const PantallaRegistrar())),
      _Acceso(
        Icons.history,
        'Historial',
        () => _abrir(context, const PantallaHistorial()),
        insignia: '${app.historial.length}',
        color: colorPrimario,
      ),
      _Acceso(Icons.settings, 'Configuración', () => _abrir(context, const PantallaConfig())),
      _Acceso(Icons.ios_share, 'Exportar', () => _abrir(context, const PantallaExportar())),
      _Acceso(
        Icons.notifications,
        'Notificaciones',
        () => _notificaciones(context),
        insignia: app.notificacionesActivas ? 'ON' : 'Off',
        color: app.notificacionesActivas ? colorOk : colorTenue,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final alcance = Alcance.of(context);
    return Pagina(
      titulo: 'StereoApp',
      scroll: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([alcance.app, alcance.obd]),
        builder: (context, _) {
          final accesos = _accesos(context, alcance.app, alcance.obd);
          return LayoutBuilder(builder: (context, c) {
            const hueco = 12.0;
            if (c.maxWidth < anchoDosColumnas) {
              return SingleChildScrollView(
                child: Column(
                  children: [
                    _Resumen(alcance.app),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: hueco,
                      crossAxisSpacing: hueco,
                      childAspectRatio: 0.9,
                      children: [for (final a in accesos) _Mosaico(a)],
                    ),
                  ],
                ),
              );
            }
            // Horizontal: resumen a la izquierda y los 10 accesos en 5x2 llenando el alto.
            const anchoResumen = 300.0;
            final ancho = (c.maxWidth - anchoResumen - 16 - hueco * 4) / 5;
            final alto = ((c.maxHeight - hueco) / 2).clamp(120.0, 260.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: anchoResumen,
                  child: SingleChildScrollView(child: _Resumen(alcance.app)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 5,
                    mainAxisSpacing: hueco,
                    crossAxisSpacing: hueco,
                    childAspectRatio: ancho / alto,
                    children: [for (final a in accesos) _Mosaico(a)],
                  ),
                ),
              ],
            );
          });
        },
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  const _Resumen(this.app);

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final aceite = app.aceite;
    final color = aceite == null ? Colors.white : colorNivel(aceite.nivel);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_car, size: 34),
              const SizedBox(height: 6),
              Text('Optra ${app.modelo}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(app.placa.isEmpty ? 'Sin placa' : app.placa,
                  style: const TextStyle(fontSize: 17, letterSpacing: 1)),
              const SizedBox(height: 10),
              Etiqueta(app.motor, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Dato('Kilómetros', formatoKm(app.kmActual), alTocar: () => pedirKilometraje(context)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Dato('Días aceite', aceite == null ? '-' : '${aceite.dias}', color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: _Dato('Km aceite', aceite == null ? '-' : formatoKm(aceite.kmRecorridos),
                  color: color),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato(this.nombre, this.valor, {this.color = Colors.white, this.alTocar});

  final String nombre;
  final String valor;
  final Color color;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              FittedBox(
                child: Text(valor,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color)),
              ),
              Text(nombre.toUpperCase(),
                  style: const TextStyle(fontSize: 12, color: colorTenue, letterSpacing: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mosaico extends StatelessWidget {
  const _Mosaico(this.acceso);

  final _Acceso acceso;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: acceso.alTocar,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(acceso.icono, size: 44, color: colorPrimario),
                const SizedBox(height: 8),
                Text(acceso.nombre,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (acceso.insignia != null) ...[
                  const SizedBox(height: 8),
                  Etiqueta(acceso.insignia!, color: acceso.color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
