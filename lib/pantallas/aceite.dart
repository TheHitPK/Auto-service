import 'package:flutter/material.dart';

import '../datos/catalogo.dart';
import '../estado_app.dart';
import '../main.dart';
import '../tema.dart';
import '../widgets.dart';

class PantallaAceite extends StatefulWidget {
  const PantallaAceite({super.key});

  @override
  State<PantallaAceite> createState() => _PantallaAceiteState();
}

class _PantallaAceiteState extends State<PantallaAceite> {
  String _tipo = 'mineral';
  String _viscosidad = viscosidades.keys.first;
  String _marca = marcasAceite.keys.first;
  final _otraMarca = TextEditingController();
  final _km = TextEditingController();
  final _intervalo = TextEditingController();

  @override
  void dispose() {
    _otraMarca.dispose();
    _km.dispose();
    _intervalo.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    final app = Alcance.of(context).app;
    final marca = _marca == marcaOtra ? _otraMarca.text.trim() : _marca;
    final km = int.tryParse(_km.text) ?? 0;
    if (marca.isEmpty) return aviso(context, 'Escribe el nombre de la marca.');
    if (km <= 0) return aviso(context, 'Ingresa un kilometraje válido.');
    final ultimo = app.ultimoRegistro(idAceite);
    if (ultimo != null &&
        ultimo.km >= km &&
        !await confirmar(context,
            'Ya hay un cambio registrado a los ${formatoKm(ultimo.km)} km. ¿Registrar igual?')) {
      return;
    }
    final intervalo = int.tryParse(_intervalo.text) ?? 0;
    await app.registrar(Registro(
      tipo: Registro.preventivo,
      servicioId: idAceite,
      km: km,
      fecha: DateTime.now(),
      tipoAceite: _tipo,
      viscosidad: _viscosidad,
      marca: marca,
      intervalo: intervalo > 0 ? intervalo : intervaloPorTipoAceite[_tipo],
    ));
    if (!mounted) return;
    _km.clear();
    _intervalo.clear();
    aviso(context, 'Cambio de aceite registrado.');
  }

  @override
  Widget build(BuildContext context) {
    final app = Alcance.of(context).app;
    const separador = SizedBox(height: 14);
    return Pagina(
      titulo: 'Aceite',
      child: DosColumnas(
        izquierda: ListenableBuilder(listenable: app, builder: (context, _) => _Estado(app.aceite)),
        derecha: Tarjeta(
          titulo: 'Registrar cambio de aceite',
          icono: Icons.edit_note,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo de aceite'),
                items: [
                  for (final e in tiposAceite.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _tipo = v!),
              ),
              separador,
              DropdownButtonFormField<String>(
                initialValue: _viscosidad,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Viscosidad (SAE)',
                  helperText: 'El manual del Optra sugiere 15W-40 o 10W-30',
                ),
                items: [
                  for (final e in viscosidades.entries)
                    DropdownMenuItem(
                        value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => _viscosidad = v!,
              ),
              separador,
              DropdownButtonFormField<String>(
                initialValue: _marca,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Marca'),
                items: [
                  for (final e in marcasAceite.entries)
                    DropdownMenuItem(
                        value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _marca = v!),
              ),
              if (_marca == marcaOtra) ...[
                separador,
                TextField(
                  controller: _otraMarca,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Especifica la marca',
                    hintText: 'Ej: Liqui Moly, Wolf...',
                  ),
                ),
              ],
              separador,
              TextField(
                controller: _km,
                keyboardType: TextInputType.number,
                inputFormatters: soloDigitos,
                decoration: InputDecoration(
                  labelText: 'Kilometraje al momento del cambio',
                  suffixText: 'km',
                  suffixIcon: IconButton(
                    tooltip: 'Usar kilometraje actual',
                    icon: const Icon(Icons.speed),
                    onPressed: () => _km.text = '${app.kmActual}',
                  ),
                ),
              ),
              separador,
              TextField(
                controller: _intervalo,
                keyboardType: TextInputType.number,
                inputFormatters: soloDigitos,
                decoration: InputDecoration(
                  labelText: 'Intervalo de cambio',
                  suffixText: 'km',
                  hintText: '${intervaloPorTipoAceite[_tipo]} (sugerido)',
                  helperText: 'Vacío = sugerido para ${tiposAceite[_tipo]!.toLowerCase()}',
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _registrar,
                icon: const Icon(Icons.oil_barrel),
                label: const Text('Registrar cambio de aceite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  const _Estado(this.aceite);

  final EstadoAceite? aceite;

  @override
  Widget build(BuildContext context) {
    final a = aceite;
    const nota = TextoTenue(
        'Intervalos sugeridos: mineral 5.000 km · semisintético 7.000 km · sintético 10.000 km');
    if (a == null) {
      return const Tarjeta(
        titulo: 'Último cambio',
        icono: Icons.oil_barrel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aún no has registrado un cambio de aceite.'),
            SizedBox(height: 12),
            nota,
          ],
        ),
      );
    }
    final color = colorNivel(a.nivel);
    final r = a.registro;
    final avance = (a.kmRecorridos / a.limite).clamp(0.0, 1.0);
    return Tarjeta(
      titulo: 'Último cambio',
      icono: Icons.oil_barrel,
      borde: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: TextoTenue(formatoFecha(r.fecha))),
              Etiqueta(a.etiqueta, color: color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Cifra('${a.dias}', 'días')),
              Expanded(child: _Cifra(formatoKm(a.kmRecorridos), 'km recorridos')),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: avance,
              minHeight: 12,
              color: color,
              backgroundColor: colorBorde,
            ),
          ),
          const SizedBox(height: 6),
          TextoTenue('${formatoKm(a.kmRecorridos)} de ${formatoKm(a.limite)} km'),
          const SizedBox(height: 14),
          Text(
            [tiposAceite[r.tipoAceite], r.viscosidad, r.marca]
                .where((e) => e != null && e.isNotEmpty)
                .join(' · '),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(a.recomendacion, style: TextStyle(fontSize: 18, color: color)),
          const SizedBox(height: 14),
          nota,
        ],
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(this.valor, this.nombre);

  final String valor;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valor, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        TextoTenue(nombre),
      ],
    );
  }
}
