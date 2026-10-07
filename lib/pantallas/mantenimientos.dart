import 'package:flutter/material.dart';

import '../estado_app.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets.dart';
import 'registrar.dart';

class PantallaMantenimientos extends StatelessWidget {
  const PantallaMantenimientos({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    return Pagina(
      titulo: 'Mantenimientos',
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final proximos = app.proximos();
          return Tarjeta(
            titulo: 'Próximos servicios',
            icono: Icons.build,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextoTenue(app.kmInicial > 0
                    ? 'Los servicios sin registro se cuentan desde los '
                        '${formatoKm(app.kmInicial)} km (inicio en la app).'
                    : 'Indica el "kilometraje al empezar" en Configuración para que los '
                        'servicios sin registro se calculen mejor.'),
                const SizedBox(height: 6),
                for (final (i, p) in proximos.indexed) ...[
                  if (i > 0) const Divider(),
                  _Fila(p),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.p);

  final Proximo p;

  @override
  Widget build(BuildContext context) {
    final (color, etiqueta) = switch (p.estado) {
      EstadoServicio.vencido => (colorPeligro, 'VENCIDO ${formatoKm(-p.kmFaltan)} km'),
      EstadoServicio.revisar => (colorAviso, 'Revisar'),
      EstadoServicio.proximo => (colorAviso, 'Faltan ${formatoKm(p.kmFaltan)} km'),
      EstadoServicio.ok => (colorOk, 'Faltan ${formatoKm(p.kmFaltan)} km'),
    };
    final ultimo = p.ultimo;
    final etiquetas = [
      if (p.servicio.esCritico) const Etiqueta('Crítico', color: colorAviso),
      Etiqueta(etiqueta, color: color),
    ];
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => PantallaRegistrar(servicioId: p.servicio.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        // En pantallas angostas las etiquetas bajan debajo del nombre.
        child: LayoutBuilder(builder: (context, c) {
          final ancho = c.maxWidth >= 560;
          return Row(
            children: [
              Container(
                width: 6,
                height: 52,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 14),
              Icon(
                p.servicio.esSensor ? Icons.sensors : Icons.build_circle_outlined,
                color: colorTenue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.servicio.nombre,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    TextoTenue(
                      '${ultimo == null ? 'Sin registro' : 'Último a los ${formatoKm(ultimo.km)} km'}'
                      ' · próximo a los ${formatoKm(p.kmProximo)} km',
                    ),
                    if (!ancho) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 8, runSpacing: 6, children: etiquetas),
                    ],
                  ],
                ),
              ),
              if (ancho) ...[
                const SizedBox(width: 12),
                Wrap(spacing: 8, children: etiquetas),
              ],
              const Icon(Icons.chevron_right, color: colorTenue),
            ],
          );
        }),
      ),
    );
  }
}
