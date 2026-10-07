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
            tooltip: 'Editar',
            iconSize: 28,
            padding: const EdgeInsets.all(12),
            icon: const Icon(Icons.edit_outlined, color: colorTenue),
            onPressed: () => showDialog<void>(context: context, builder: (_) => _Editor(r)),
          ),
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

/// Corrige el kilometraje de un registro y, si es correctivo, su descripción y costo.
class _Editor extends StatefulWidget {
  const _Editor(this.registro);

  final Registro registro;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _km = TextEditingController(text: '${widget.registro.km}');
  late final _descripcion = TextEditingController(text: widget.registro.descripcion);
  late final _costo = TextEditingController(text: widget.registro.costo);

  @override
  void dispose() {
    _km.dispose();
    _descripcion.dispose();
    _costo.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final r = widget.registro;
    final km = int.tryParse(_km.text);
    if (km == null) return aviso(context, 'Ingresa un kilometraje válido.');
    await Alcance.of(context).app.reemplazar(
          r,
          r.esPreventivo
              ? r.editado(km: km)
              : r.editado(km: km, descripcion: _descripcion.text.trim(), costo: _costo.text.trim()),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const separador = SizedBox(height: 14);
    return AlertDialog(
      title: Text(widget.registro.esPreventivo ? widget.registro.nombre : 'Editar reparación'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                inputFormatters: soloDigitos,
                decoration: const InputDecoration(labelText: 'Kilometraje', suffixText: 'km'),
              ),
              if (!widget.registro.esPreventivo) ...[
                separador,
                TextField(
                  controller: _descripcion,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                separador,
                TextField(
                  controller: _costo,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Costo', prefixText: r'$ '),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: const Text('Guardar')),
      ],
    );
  }
}
