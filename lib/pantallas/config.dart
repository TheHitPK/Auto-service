import 'package:flutter/material.dart';

import '../datos/catalogo.dart';
import '../estado_app.dart';
import '../main.dart';
import '../widgets.dart';

class PantallaConfig extends StatefulWidget {
  const PantallaConfig({super.key});

  @override
  State<PantallaConfig> createState() => _PantallaConfigState();
}

class _PantallaConfigState extends State<PantallaConfig> {
  late String _modelo;
  late String _motor;
  late final TextEditingController _placa;
  late final TextEditingController _km;
  late final TextEditingController _kmInicial;
  late final TextEditingController _consumoMin;
  late final TextEditingController _consumoMax;
  bool _iniciado = false;

  static String _texto(double? n) => n == null ? '' : formatoDecimal(n);

  static double? _numero(String texto) => double.tryParse(texto.trim().replaceAll(',', '.'));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    final app = Alcance.of(context).app;
    _modelo = modelos.contains(app.modelo) ? app.modelo : modelos.first;
    _motor = motores.containsKey(app.motor) ? app.motor : motores.keys.first;
    _placa = TextEditingController(text: app.placa);
    _km = TextEditingController(text: '${app.kmActual}');
    _kmInicial = TextEditingController(text: '${app.kmInicial}');
    _consumoMin = TextEditingController(text: _texto(app.consumoMin));
    _consumoMax = TextEditingController(text: _texto(app.consumoMax));
  }

  @override
  void dispose() {
    _placa.dispose();
    _km.dispose();
    _kmInicial.dispose();
    _consumoMin.dispose();
    _consumoMax.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await Alcance.of(context).app.guardarConfig(
          modelo: _modelo,
          placa: _placa.text,
          motor: _motor,
          kmActual: int.tryParse(_km.text) ?? 0,
          kmInicial: int.tryParse(_kmInicial.text) ?? 0,
          consumoMin: _numero(_consumoMin.text),
          consumoMax: _numero(_consumoMax.text),
        );
    if (!mounted) return;
    aviso(context, 'Configuración guardada.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const separador = SizedBox(height: 14);
    return Pagina(
      titulo: 'Configuración',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Tarjeta(
            titulo: 'Vehículo',
            icono: Icons.directions_car,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _modelo,
                  decoration: const InputDecoration(labelText: 'Modelo / Versión'),
                  items: [for (final m in modelos) DropdownMenuItem(value: m, child: Text(m))],
                  onChanged: (v) => _modelo = v!,
                ),
                separador,
                TextField(
                  controller: _placa,
                  maxLength: 10,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Placa (matrícula)',
                    hintText: 'Ej: ABC-123',
                    counterText: '',
                  ),
                ),
                separador,
                DropdownButtonFormField<String>(
                  initialValue: _motor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Motor'),
                  items: [
                    for (final e in motores.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _motor = v!),
                ),
                separador,
                TextField(
                  controller: _km,
                  keyboardType: TextInputType.number,
                  inputFormatters: soloDigitos,
                  decoration:
                      const InputDecoration(labelText: 'Odómetro actual', suffixText: 'km'),
                ),
                separador,
                TextField(
                  controller: _kmInicial,
                  keyboardType: TextInputType.number,
                  inputFormatters: soloDigitos,
                  decoration: const InputDecoration(
                    labelText: 'Kilometraje al empezar a usar la app',
                    suffixText: 'km',
                    helperText: 'Punto de partida para los servicios sin registro previo',
                  ),
                ),
                separador,
                Builder(builder: (context) {
                  final estandar = consumoEstandar(_motor);
                  const decimal = TextInputType.numberWithOptions(decimal: true);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _consumoMin,
                          keyboardType: decimal,
                          decoration: InputDecoration(
                            labelText: 'Consumo normal mín.',
                            suffixText: 'km/L',
                            hintText: formatoDecimal(estandar.min),
                            helperText: 'Vacío = estándar del motor',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _consumoMax,
                          keyboardType: decimal,
                          decoration: InputDecoration(
                            labelText: 'Consumo normal máx.',
                            suffixText: 'km/L',
                            hintText: formatoDecimal(estandar.max),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _guardar,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar configuración'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
