import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'estado_app.dart';
import 'main.dart';
import 'obd/obd_controller.dart';
import 'tema.dart';

const anchoDosColumnas = 760.0;

final soloDigitos = [FilteringTextInputFormatter.digitsOnly];

void aviso(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}

Future<bool> confirmar(BuildContext context, String pregunta, {String accion = 'Aceptar'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(pregunta, style: const TextStyle(fontSize: 18)),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(accion)),
      ],
    ),
  );
  return r ?? false;
}

/// Pide el kilometraje actual y lo guarda.
Future<void> pedirKilometraje(BuildContext context) async {
  final app = Alcance.of(context).app;
  final campo = TextEditingController(text: app.kmActual == 0 ? '' : '${app.kmActual}');
  final km = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Kilometraje actual'),
      content: TextField(
        controller: campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: soloDigitos,
        style: const TextStyle(fontSize: 24),
        decoration: const InputDecoration(suffixText: 'km'),
        onSubmitted: (v) => Navigator.pop(context, int.tryParse(v)),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(campo.text)),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  if (km != null) await app.actualizarKm(km);
}

/// Estructura común: barra con estado OBD y kilometraje, contenido con scroll.
class Pagina extends StatelessWidget {
  const Pagina({super.key, required this.titulo, required this.child, this.scroll = true});

  final String titulo;
  final Widget child;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final alcance = Alcance.of(context);
    const margen = EdgeInsets.all(16);
    return Scaffold(
      appBar: AppBar(
        title: Text(titulo),
        actions: [
          ListenableBuilder(
            listenable: Listenable.merge([alcance.app, alcance.obd]),
            builder: (context, _) => Row(
              children: [
                LedObd(alcance.obd),
                const SizedBox(width: 12),
                ActionChip(
                  label: Text('${formatoKm(alcance.app.kmActual)} km',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onPressed: () => pedirKilometraje(context),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: scroll
            ? SingleChildScrollView(padding: margen, child: child)
            : Padding(padding: margen, child: child),
      ),
    );
  }
}

class LedObd extends StatelessWidget {
  const LedObd(this.obd, {super.key, this.tamano = 14});

  final ObdController obd;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final color = switch (obd.estado) {
      EstadoObd.conectado => colorOk,
      EstadoObd.conectando => colorAviso,
      EstadoObd.desconectado => obd.error ? colorPeligro : colorTenue,
    };
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (obd.estado != EstadoObd.desconectado)
            BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
        ],
      ),
    );
  }
}

class Tarjeta extends StatelessWidget {
  const Tarjeta({super.key, this.titulo, this.icono, required this.child, this.borde});

  final String? titulo;
  final IconData? icono;
  final Widget child;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: borde == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borde!, width: 2),
            ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (titulo != null) ...[
              Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, color: colorPrimario, size: 26),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(titulo!,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class Etiqueta extends StatelessWidget {
  const Etiqueta(this.texto, {super.key, this.color = colorPrimario});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(texto,
          style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}

/// Dos columnas en pantallas anchas (estéreo en horizontal), apiladas en angostas.
class DosColumnas extends StatelessWidget {
  const DosColumnas({super.key, required this.izquierda, required this.derecha});

  final Widget izquierda;
  final Widget derecha;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => c.maxWidth >= anchoDosColumnas
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: izquierda),
                const SizedBox(width: 16),
                Expanded(child: derecha),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [izquierda, const SizedBox(height: 16), derecha],
            ),
    );
  }
}

class TextoTenue extends StatelessWidget {
  const TextoTenue(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: const TextStyle(color: colorTenue, fontSize: 15));
}
