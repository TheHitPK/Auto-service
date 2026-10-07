import 'package:flutter/material.dart';

import '../datos/catalogo.dart';
import '../estado_app.dart';
import '../main.dart';
import '../widgets.dart';
import 'historial.dart';

class PantallaRegistrar extends StatefulWidget {
  const PantallaRegistrar({super.key, this.servicioId, this.descripcion});

  /// Servicio preventivo preseleccionado (al venir desde Mantenimientos).
  final String? servicioId;

  /// Descripción de una reparación correctiva (al venir desde los códigos OBD).
  final String? descripcion;

  @override
  State<PantallaRegistrar> createState() => _PantallaRegistrarState();
}

class _PantallaRegistrarState extends State<PantallaRegistrar> {
  late String _tipo = widget.descripcion == null ? Registro.preventivo : Registro.correctivo;
  late String _servicio = widget.servicioId ?? servicios.first.id;
  late final _descripcion = TextEditingController(text: widget.descripcion);
  final _costo = TextEditingController();
  final _km = TextEditingController();

  @override
  void dispose() {
    _descripcion.dispose();
    _costo.dispose();
    _km.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final app = Alcance.of(context).app;
    final km = int.tryParse(_km.text) ?? app.kmActual;
    if (km <= 0) return aviso(context, 'Ingresa un kilometraje válido.');
    final Registro registro;
    if (_tipo == Registro.preventivo) {
      final ultimo = app.ultimoRegistro(_servicio);
      if (ultimo != null &&
          ultimo.km >= km &&
          !await confirmar(context,
              'Ya hay un registro a los ${formatoKm(ultimo.km)} km. ¿Registrar igual?')) {
        return;
      }
      registro = Registro(
        tipo: Registro.preventivo,
        servicioId: _servicio,
        km: km,
        fecha: DateTime.now(),
      );
    } else {
      final descripcion = _descripcion.text.trim();
      if (descripcion.isEmpty) return aviso(context, 'Escribe una descripción.');
      registro = Registro(
        tipo: Registro.correctivo,
        servicioId: Registro.correctivo,
        descripcion: descripcion,
        costo: _costo.text.trim(),
        km: km,
        fecha: DateTime.now(),
      );
    }
    await app.registrar(registro);
    if (!mounted) return;
    aviso(context, 'Registrado.');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => const PantallaHistorial()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    const separador = SizedBox(height: 14);
    return Pagina(
      titulo: 'Registrar mantenimiento',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Tarjeta(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: Registro.preventivo,
                      icon: Icon(Icons.event_available),
                      label: Text('Preventivo'),
                    ),
                    ButtonSegment(
                      value: Registro.correctivo,
                      icon: Icon(Icons.handyman),
                      label: Text('Correctivo'),
                    ),
                  ],
                  selected: {_tipo},
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(64, 56)),
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 17)),
                  ),
                  onSelectionChanged: (s) => setState(() => _tipo = s.first),
                ),
                separador,
                if (_tipo == Registro.preventivo)
                  DropdownButtonFormField<String>(
                    initialValue: _servicio,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Servicio / Sensor'),
                    items: [
                      for (final s in servicios)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.nombre} (cada ${formatoKm(s.intervaloKm)} km)',
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => _servicio = v!,
                  )
                else ...[
                  TextField(
                    controller: _descripcion,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Ej: Cambio de bobina',
                    ),
                  ),
                  separador,
                  TextField(
                    controller: _costo,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Costo', prefixText: r'$ '),
                  ),
                ],
                separador,
                TextField(
                  controller: _km,
                  keyboardType: TextInputType.number,
                  inputFormatters: soloDigitos,
                  decoration: InputDecoration(
                    labelText: 'Kilometraje',
                    suffixText: 'km',
                    hintText: '${app.kmActual} (actual)',
                    helperText: 'Vacío = kilometraje actual',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _registrar,
                  icon: const Icon(Icons.check),
                  label: const Text('Registrar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
