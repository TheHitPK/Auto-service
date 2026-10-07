import 'package:flutter/material.dart';

import '../estado_app.dart';
import '../main.dart';
import '../servicios/exportar.dart';
import '../tema.dart';
import '../widgets.dart';

class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({super.key});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  /// null = todos.
  String? _filtro;

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    return Pagina(
      titulo: 'Historial',
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final registros = app.historialOrdenado(_filtro);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('Todos')),
                  ButtonSegment(value: Registro.preventivo, label: Text('Preventivos')),
                  ButtonSegment(value: Registro.correctivo, label: Text('Correctivos')),
                ],
                selected: {_filtro},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(64, 56)),
                  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 17)),
                ),
                onSelectionChanged: (s) => setState(() => _filtro = s.first),
              ),
              const SizedBox(height: 16),
              Tarjeta(
                child: registros.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: TextoTenue('No hay registros.')),
                      )
                    : Column(
                        children: [
                          for (final (i, r) in registros.indexed) ...[
                            if (i > 0) const Divider(),
                            _Fila(r),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => exportarHistorial(context),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Exportar CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: colorPeligro),
                      onPressed: app.historial.isEmpty
                          ? null
                          : () async {
                              if (await confirmar(context, '¿Borrar TODO el historial?',
                                  accion: 'Borrar todo')) {
                                await app.borrarHistorial();
                              }
                            },
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Borrar todo'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila(this.r);

  final Registro r;

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                TextoTenue(
                  '${formatoFecha(r.fecha)} · ${formatoKm(r.km)} km'
                  '${r.costo.isEmpty ? '' : ' · \$${r.costo}'}',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          r.esPreventivo
              ? const Etiqueta('Preventivo')
              : const Etiqueta('Correctivo', color: colorPeligro),
          IconButton(
            tooltip: 'Eliminar',
            iconSize: 28,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.delete_outline, color: colorTenue),
            onPressed: () async {
              if (await confirmar(context, '¿Eliminar "${r.nombre}"?', accion: 'Eliminar')) {
                await app.eliminar(r);
              }
            },
          ),
        ],
      ),
    );
  }
}
