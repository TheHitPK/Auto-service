import 'package:flutter/material.dart';

import '../datos/catalogo.dart';
import '../tema.dart';
import '../widgets.dart';

class PantallaDiagnostico extends StatefulWidget {
  const PantallaDiagnostico({super.key});

  @override
  State<PantallaDiagnostico> createState() => _PantallaDiagnosticoState();
}

class _PantallaDiagnosticoState extends State<PantallaDiagnostico> {
  final _activos = <String>{};

  /// Causas de los síntomas marcados; las que se repiten entre síntomas van primero.
  List<(String, int)> get _causas {
    final veces = <String, int>{};
    for (final id in _activos) {
      for (final causa in sintomas[id]!.$2) {
        veces[causa] = (veces[causa] ?? 0) + 1;
      }
    }
    final lista = [for (final e in veces.entries) (e.key, e.value)];
    lista.sort((a, b) => b.$2.compareTo(a.$2));
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final causas = _causas;
    return Pagina(
      titulo: 'Diagnóstico por síntomas',
      child: DosColumnas(
        izquierda: Tarjeta(
          titulo: 'Síntomas',
          icono: Icons.troubleshoot,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TextoTenue('Marca lo que presenta tu auto.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in sintomas.entries)
                    FilterChip(
                      label: Text(e.value.$1),
                      labelStyle: const TextStyle(fontSize: 17),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      selected: _activos.contains(e.key),
                      onSelected: (v) => setState(
                          () => v ? _activos.add(e.key) : _activos.remove(e.key)),
                    ),
                ],
              ),
            ],
          ),
        ),
        derecha: Tarjeta(
          titulo: 'Posibles causas',
          icono: Icons.search,
          borde: causas.isEmpty ? null : colorAviso,
          child: causas.isEmpty
              ? const TextoTenue('Selecciona uno o más síntomas.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (causa, veces) in causas)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_right, color: colorAviso),
                            Expanded(child: Text(causa, style: const TextStyle(fontSize: 18))),
                            if (veces > 1) Etiqueta('$veces síntomas', color: colorAviso),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    const TextoTenue(
                        'Conecta el escáner OBD-II para confirmar con los códigos de falla.'),
                  ],
                ),
        ),
      ),
    );
  }
}
