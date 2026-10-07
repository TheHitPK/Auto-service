import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stereo_app/datos/catalogo.dart';
import 'package:stereo_app/datos/dtc_catalogo.dart';
import 'package:stereo_app/estado_app.dart';
import 'package:stereo_app/main.dart';
import 'package:stereo_app/obd/elm327.dart';
import 'package:stereo_app/obd/obd_controller.dart';

void main() {
  group('parsearDtc', () {
    test('protocolo antiguo: 3 códigos por línea, relleno con 0000', () {
      expect(
        parsearDtc('43 01 33 00 00 00 00\r\r>', modo: 3, can: false),
        ['P0133'],
      );
      expect(
        parsearDtc('43 03 00 01 71 04 20\r43 05 00 00 00 00 00\r', modo: 3, can: false),
        ['P0300', 'P0171', 'P0420', 'P0500'],
      );
    });

    test('CAN: el primer byte es la cantidad de códigos', () {
      expect(parsearDtc('43 02 01 33 01 71\r', modo: 3, can: true), ['P0133', 'P0171']);
      expect(parsearDtc('4300\r', modo: 3, can: true), isEmpty);
    });

    test('CAN multitrama: une las tramas e ignora el relleno', () {
      const crudo = '00A\r0: 43 04 01 33 01 71\r1: 03 00 04 20 AA AA AA\r';
      expect(parsearDtc(crudo, modo: 3, can: true), ['P0133', 'P0171', 'P0300', 'P0420']);
    });

    test('letras C, B y U, y códigos pendientes (modo 07)', () {
      expect(
        parsearDtc('47 03 41 23 81 23 C1 00\r', modo: 7, can: true),
        ['C0123', 'B0123', 'U0100'],
      );
    });

    test('sin datos o respuesta de otro modo', () {
      expect(parsearDtc('NO DATA\r', modo: 3, can: false), isEmpty);
      expect(parsearDtc('SEARCHING...\rUNABLE TO CONNECT\r', modo: 3, can: true), isEmpty);
      expect(parsearDtc('43 01 33 00 00 00 00\r', modo: 7, can: false), isEmpty);
    });
  });

  test('parsearPid extrae los bytes de datos', () {
    expect(parsearPid('41 0C 1A F8\r\r', 0x0C), [0x1A, 0xF8]);
    expect(parsearPid('410C1AF8', 0x0C), [0x1A, 0xF8]);
    expect(parsearPid('SEARCHING...\r41 00 BE 3E B8 11\r', 0x00), [0xBE, 0x3E, 0xB8, 0x11]);
    expect(parsearPid('NO DATA', 0x0C), isNull);
    expect(parsearPid('41 05 7B', 0x0C), isNull);
  });

  test('descripcionDtc: tabla y respaldo por subsistema', () {
    expect(descripcionDtc('P0300'), contains('Fallo de encendido'));
    expect(descripcionDtc('P0399'), contains('encendido'));
    expect(descripcionDtc('P1399'), contains('fabricante'));
    expect(descripcionDtc('U0999'), contains('comunicación'));
  });

  group('AppState', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Registro preventivo(String id, int km, {int? intervalo, DateTime? fecha}) => Registro(
          tipo: Registro.preventivo,
          servicioId: id,
          km: km,
          fecha: fecha ?? DateTime.now(),
          intervalo: intervalo,
        );

    test('próximos servicios: vencidos primero y aceite con su intervalo', () async {
      final app = AppState();
      await app.actualizarKm(50000);
      await app.registrar(preventivo(idAceite, 45000, intervalo: 10000));
      await app.registrar(preventivo('frenos', 30000));

      final proximos = app.proximos();
      final aceite = proximos.firstWhere((p) => p.servicio.id == idAceite);
      final frenos = proximos.firstWhere((p) => p.servicio.id == 'frenos');
      expect(aceite.kmProximo, 55000);
      expect(aceite.kmFaltan, 5000);
      expect(frenos.vencido, isTrue);
      expect(frenos.kmFaltan, -10000);
      expect(proximos.first.kmFaltan, lessThanOrEqualTo(proximos.last.kmFaltan));
    });

    test('estado del aceite por kilómetros y por días', () async {
      final app = AppState();
      await app.registrar(preventivo(idAceite, 40000, intervalo: 5000));
      expect(app.aceite!.nivel, Nivel.ok);
      await app.actualizarKm(44200);
      expect(app.aceite!.nivel, Nivel.proximo);
      await app.actualizarKm(45000);
      expect(app.aceite!.nivel, Nivel.urgente);

      final viejo = AppState();
      await viejo.registrar(preventivo(idAceite, 40000,
          fecha: DateTime.now().subtract(const Duration(days: 200))));
      expect(viejo.aceite!.nivel, Nivel.urgente);
    });

    test('registrar sube el kilometraje y el estado sobrevive al reinicio', () async {
      final app = AppState();
      await app.guardarConfig(modelo: 'ADVANCE', placa: ' ab-123 ', motor: 'F18D3', kmActual: 1000);
      await app.registrar(Registro(
        tipo: Registro.correctivo,
        servicioId: Registro.correctivo,
        descripcion: 'Cambio de "bobina"',
        costo: '45',
        km: 1200,
        fecha: DateTime(2026, 10, 6, 9, 5),
      ));

      final otra = AppState();
      await otra.cargar();
      expect(otra.placa, 'AB-123');
      expect(otra.modelo, 'ADVANCE');
      expect(otra.kmActual, 1200);
      expect(otra.historial.single.descripcion, 'Cambio de "bobina"');
      expect(
        otra.exportarCsv(),
        'Fecha,Kilometraje,Tipo,Servicio/Reparación,Costo\n'
        '"06/10/2026 09:05","1200","Correctivo","Cambio de ""bobina""","45"\n',
      );
    });
  });

  testWidgets('la pantalla de inicio cabe en un estéreo de 1024x600', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(StereoApp(app: AppState(), obd: ObdController()));
    expect(find.text('Mantenimientos'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mantenimientos'));
    await tester.pumpAndSettle();
    expect(find.text('Correa de distribución'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
