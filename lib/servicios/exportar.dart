import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../widgets.dart';

/// Guarda [contenido] en el almacenamiento de la app y abre el diálogo de
/// compartir (por si el estéreo tiene Drive, correo, etc.).
Future<void> _guardarYCompartir(
  BuildContext context,
  String sufijo,
  String extension,
  String contenido,
) async {
  final app = Alcance.of(context).app;
  // En iPad el diálogo de compartir necesita saber desde dónde se abre.
  final caja = context.findRenderObject() as RenderBox?;
  final origen = caja == null ? null : caja.localToGlobal(Offset.zero) & caja.size;
  try {
    final carpeta = (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    final placa = app.placa.isEmpty ? 'sinplaca' : app.placa.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final fecha = DateTime.now().toIso8601String().substring(0, 10);
    final archivo = File('${carpeta.path}/optra_${placa}_$sufijo$fecha.$extension');
    // BOM para que Excel reconozca los acentos del CSV.
    final bom = extension == 'csv' ? [0xEF, 0xBB, 0xBF] : <int>[];
    await archivo.writeAsBytes([...bom, ...utf8.encode(contenido)]);
    if (context.mounted) aviso(context, 'Guardado en ${archivo.path}');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(archivo.path)], sharePositionOrigin: origen),
    );
  } catch (e) {
    if (context.mounted) aviso(context, 'No se pudo exportar: $e');
  }
}

Future<void> exportarHistorial(BuildContext context) async {
  final app = Alcance.of(context).app;
  if (app.historial.isEmpty) return aviso(context, 'No hay registros para exportar.');
  await _guardarYCompartir(context, '', 'csv', app.exportarCsv());
}

Future<void> exportarCargas(BuildContext context) async {
  final app = Alcance.of(context).app;
  if (app.cargas.isEmpty) return aviso(context, 'No hay cargas registradas.');
  await _guardarYCompartir(context, 'cargas_', 'csv', app.exportarCargasCsv());
}

Future<void> exportarBackup(BuildContext context) =>
    _guardarYCompartir(context, 'backup_', 'json', Alcance.of(context).app.exportarJson());

Future<void> restaurarBackup(BuildContext context) async {
  final app = Alcance.of(context).app;
  try {
    final elegidos = await FilePicker.pickFiles(type: FileType.any);
    if (elegidos.isEmpty || !context.mounted) return;
    final json = utf8.decode(await elegidos.first.readAsBytes(), allowMalformed: true);
    if (!context.mounted) return;
    final ok = await confirmar(
      context,
      '¿Restaurar "${elegidos.first.name}"?\n\nSe reemplazarán TODOS los datos actuales '
      '(historial, cargas y configuración).',
      accion: 'Restaurar',
    );
    if (!ok) return;
    // Quita el BOM si el archivo lo trae.
    await app.restaurar(json.replaceFirst('﻿', ''));
    if (context.mounted) aviso(context, 'Backup restaurado.');
  } on FormatException catch (e) {
    if (context.mounted) aviso(context, e.message);
  } catch (e) {
    if (context.mounted) aviso(context, 'No se pudo leer el archivo: $e');
  }
}

class PantallaExportar extends StatelessWidget {
  const PantallaExportar({super.key});

  @override
  Widget build(BuildContext context) {
    const separador = SizedBox(height: 12);
    return Pagina(
      titulo: 'Exportar / Backup',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Tarjeta(
                titulo: 'Exportar a CSV',
                icono: Icons.table_chart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TextoTenue('Para abrir en Excel o Google Sheets.'),
                    separador,
                    // Builder: cada botón es el origen de su diálogo de compartir.
                    Builder(
                      builder: (context) => FilledButton.icon(
                        onPressed: () => exportarHistorial(context),
                        icon: const Icon(Icons.history),
                        label: const Text('Historial de servicios'),
                      ),
                    ),
                    separador,
                    Builder(
                      builder: (context) => OutlinedButton.icon(
                        onPressed: () => exportarCargas(context),
                        icon: const Icon(Icons.local_gas_station),
                        label: const Text('Cargas de combustible'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Tarjeta(
                titulo: 'Copia de seguridad',
                icono: Icons.save,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TextoTenue(
                        'Un archivo JSON con todos tus datos. También se pueden restaurar '
                        'los backups hechos con la versión web.'),
                    separador,
                    Builder(
                      builder: (context) => OutlinedButton.icon(
                        onPressed: () => exportarBackup(context),
                        icon: const Icon(Icons.download),
                        label: const Text('Crear backup completo'),
                      ),
                    ),
                    separador,
                    OutlinedButton.icon(
                      onPressed: () => restaurarBackup(context),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Restaurar backup'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
