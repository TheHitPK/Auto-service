import 'package:flutter/material.dart';

import 'estado_app.dart';

const colorFondo = Color(0xFF0B1220);
const colorTarjeta = Color(0xFF151F33);
const colorBorde = Color(0xFF24324D);
const colorPrimario = Color(0xFF38BDF8);
const colorOk = Color(0xFF4ADE80);
const colorAviso = Color(0xFFFBBF24);
const colorPeligro = Color(0xFFF87171);
const colorTenue = Color(0xFF94A3B8);

Color colorNivel(Nivel n) => switch (n) {
      Nivel.ok => colorOk,
      Nivel.proximo => colorAviso,
      Nivel.urgente => colorPeligro,
    };

/// Tema oscuro con controles grandes: se usa con el dedo y de reojo desde el asiento.
ThemeData temaApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: colorPrimario,
    brightness: Brightness.dark,
  ).copyWith(
    primary: colorPrimario,
    surface: colorFondo,
    error: colorPeligro,
  );
  final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const minimo = Size(64, 56);
  // Angosto para que dos botones con icono quepan lado a lado en un teléfono.
  const relleno = EdgeInsets.symmetric(horizontal: 12);
  const textoBoton = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: colorBorde),
  );

  return ThemeData(
    colorScheme: esquema,
    scaffoldBackgroundColor: colorFondo,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0E1830),
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: colorTarjeta,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: colorBorde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minimo,
        shape: forma,
        textStyle: textoBoton,
        padding: relleno,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minimo,
        padding: relleno,
        shape: forma,
        textStyle: textoBoton,
        side: const BorderSide(color: colorBorde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF0F1829),
      border: borde,
      enabledBorder: borde,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(fontSize: 17, color: Colors.white),
      backgroundColor: Color(0xFF24324D),
    ),
    dividerTheme: const DividerThemeData(color: colorBorde, space: 1),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 18),
      bodyMedium: TextStyle(fontSize: 16),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}
