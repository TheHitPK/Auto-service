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
              children: [
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
    final color = p.vencido ? colorPeligro : (p.cercano ? colorAviso : colorOk);
    final ultimo = p.ultimo;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => PantallaRegistrar(servicioId: p.servicio.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
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
                    'Próximo a los ${formatoKm(p.kmProximo)} km · '
                    '${ultimo == null ? 'nunca registrado' : 'último a los ${formatoKm(ultimo.km)} km'}',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (p.servicio.esCritico) ...[
              const Etiqueta('Crítico', color: colorAviso),
              const SizedBox(width: 8),
            ],
            Etiqueta(
              p.vencido ? 'VENCIDO ${formatoKm(-p.kmFaltan)} km' : 'Faltan ${formatoKm(p.kmFaltan)} km',
              color: color,
            ),
            const Icon(Icons.chevron_right, color: colorTenue),
          ],
        ),
      ),
    );
  }
}
