import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart';
import '../widgets.dart';

/// Guarda el historial como CSV en el almacenamiento de la app y abre el
/// diálogo de compartir (por si el estéreo tiene Drive, correo, etc.).
Future<void> exportarHistorial(BuildContext context) async {
  final app = Alcance.of(context).app;
  if (app.historial.isEmpty) {
    aviso(context, 'No hay registros para exportar.');
    return;
  }
  try {
    final carpeta = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final placa = app.placa.isEmpty ? 'sinplaca' : app.placa.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final fecha = DateTime.now().toIso8601String().substring(0, 10);
    final archivo = File('${carpeta.path}/optra_${placa}_$fecha.csv');
    // BOM para que Excel reconozca los acentos.
    await archivo.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(app.exportarCsv())]);
    if (context.mounted) aviso(context, 'Guardado en ${archivo.path}');
    await SharePlus.instance.share(
      ShareParams(files: [XFile(archivo.path, mimeType: 'text/csv')]),
    );
  } catch (e) {
    if (context.mounted) aviso(context, 'No se pudo exportar: $e');
  }
}
