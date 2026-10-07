import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stereo_app/datos/catalogo.dart';
import 'package:stereo_app/datos/dtc_catalogo.dart';
import 'package:stereo_app/estado_app.dart';
import 'package:stereo_app/main.dart';
import 'package:stereo_app/obd/elm327.dart';
import 'package:stereo_app/obd/obd_controller.dart';
import 'package:stereo_app/servicios/trip_gps.dart';

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
      await app.guardarConfig(
          modelo: 'ADVANCE', placa: ' ab-123 ', motor: 'F18D3', kmActual: 1000, kmInicial: 500);
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

  group('v2', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Registro preventivo(String id, int km) =>
        Registro(tipo: Registro.preventivo, servicioId: id, km: km, fecha: DateTime.now());

    test('servicios sin registro: se cuentan desde el km inicial y piden revisar', () async {
      final app = AppState();
      await app.guardarConfig(
          modelo: 'DESIGN', placa: '', motor: 'T18SED', kmActual: 52000, kmInicial: 40000);
      await app.registrar(preventivo('bujias', 20000));
      await app.registrar(preventivo('filtroCombustible', 10000 + 1000));

      Proximo de(String id) => app.proximos().firstWhere((p) => p.servicio.id == id);
      // Sin registro: 40.000 + 10.000 ya pasó, pero no se sabe si se hizo.
      expect(de('frenos').estado, EstadoServicio.revisar);
      expect(de('filtroAire').kmProximo, 70000);
      expect(de('filtroAire').estado, EstadoServicio.ok);
      // Con registro: 20.000 + 30.000 = 50.000, ya pasó.
      expect(de('bujias').estado, EstadoServicio.vencido);
      // 11.000 + 45.000 = 56.000: faltan 4.000, menos del 15 % del intervalo.
      expect(de('filtroCombustible').estado, EstadoServicio.proximo);
      expect(app.proximos().first.servicio.id, 'bujias');
      expect(app.alertas, 3); // bujías vencidas; frenos y aceite por revisar
    });

    test('registrar aceite al mismo km corrige el registro en vez de duplicarlo', () async {
      final app = AppState();
      Registro aceite(String marca) => Registro(
          tipo: Registro.preventivo,
          servicioId: idAceite,
          km: 45000,
          fecha: DateTime.now(),
          marca: marca);
      await app.registrar(aceite('Shell'));
      await app.registrar(aceite('Motul'));
      expect(app.historial.single.marca, 'Motul');
    });

    test('el trip integra la velocidad del OBD e ignora huecos largos', () {
      final app = AppState();
      final t0 = DateTime(2026, 1, 1, 8);
      app.acumularVelocidad(60, t0);
      app.acumularVelocidad(60, t0.add(const Duration(seconds: 6)));
      expect(app.tripKm, closeTo(0.1, 1e-9));
      app.acumularVelocidad(60, t0.add(const Duration(minutes: 10)));
      expect(app.tripKm, closeTo(0.1, 1e-9));
      app.acumularVelocidad(null);
      app.acumularVelocidad(100, t0.add(const Duration(minutes: 10, seconds: 2)));
      expect(app.tripKm, closeTo(0.1, 1e-9));
    });

    test('cargas: km por odómetro o por trip, rendimiento y diagnóstico', () async {
      final app = AppState();
      expect(() => app.nuevaCarga(litros: 40), throwsFormatException);
      expect(() => app.nuevaCarga(litros: 0, odometro: 1000), throwsFormatException);

      await app.registrarCarga(app.nuevaCarga(litros: 40, odometro: 50000));
      expect(app.kmActual, 50000);
      expect(app.tramos, isEmpty);
      expect(() => app.nuevaCarga(litros: 40, odometro: 49000), throwsFormatException);

      // Por odómetro: 400 km con 40 L = 10 km/L.
      final segunda = app.nuevaCarga(litros: 40, odometro: 50400, precioL: 0.5);
      expect(segunda.kmRecorridos, 400);
      await app.registrarCarga(segunda);
      expect(app.tramos.single.kmL, closeTo(10, 1e-9));
      expect(app.tramos.single.l100, closeTo(10, 1e-9));
      expect(app.tramos.single.costoKm, closeTo(0.05, 1e-9));
      expect(app.diagnosticoConsumo.nivel, NivelConsumo.sinDatos);

      // Por trip: 300 km acumulados, sin escribir el odómetro.
      for (var i = 0; i < 100; i++) {
        app.acumularDistancia(3);
      }
      final tercera = app.nuevaCarga(litros: 30);
      expect(tercera.fuenteKm, Carga.fuenteTrip);
      expect(tercera.odometro, 50700);
      await app.registrarCarga(tercera);
      expect(app.tripKm, 0);
      expect(app.kmActual, 50700);
      expect(app.diagnosticoConsumo.nivel, NivelConsumo.normal);
      expect(app.diagnosticoConsumo.kmL, closeTo(10, 1e-9));

      // Una carga parcial no entra en el promedio.
      await app.registrarCarga(app.nuevaCarga(litros: 50, odometro: 50800, tanqueLleno: false));
      expect(app.tramos.length, 2);

      // Tramos de 4 km/L bajan el promedio de un 1.8 (8-12 km/L) a "alto".
      await app.registrarCarga(app.nuevaCarga(litros: 50, odometro: 51000));
      await app.registrarCarga(app.nuevaCarga(litros: 50, odometro: 51200));
      await app.registrarCarga(app.nuevaCarga(litros: 50, odometro: 51400));
      expect(app.diagnosticoConsumo.nivel, NivelConsumo.alto);
      expect(app.exportarCargasCsv().trim().split('\n').length, 8);
    });

    test('el trip discrepa del odómetro', () async {
      final app = AppState();
      await app.registrarCarga(app.nuevaCarga(litros: 40, odometro: 1000));
      for (var i = 0; i < 20; i++) {
        app.acumularDistancia(4);
      }
      expect(app.discrepaConTrip(app.nuevaCarga(litros: 10, odometro: 1085)), isFalse);
      expect(app.discrepaConTrip(app.nuevaCarga(litros: 10, odometro: 1200)), isTrue);
    });

    test('backup: ida y vuelta, y rechazo de archivos ajenos', () async {
      final app = AppState();
      await app.guardarConfig(
          modelo: 'LIMITED',
          placa: 'xy-9',
          motor: 'F16D3',
          kmActual: 9000,
          kmInicial: 8000,
          consumoMin: 9,
          consumoMax: 13);
      await app.registrar(preventivo('frenos', 9000));
      await app.registrarCarga(app.nuevaCarga(litros: 35.5, odometro: 9100, precioL: 0.5));
      final backup = app.exportarJson();

      final otra = AppState();
      await otra.restaurar(backup);
      expect(otra.placa, 'XY-9');
      expect(otra.motor, 'F16D3');
      expect(otra.kmInicial, 8000);
      expect(otra.rangoConsumo.min, 9);
      expect(otra.historial.single.servicioId, 'frenos');
      expect(otra.cargas.single.litros, 35.5);

      await expectLater(otra.restaurar('no es json'), throwsFormatException);
      await expectLater(otra.restaurar('{"hola": 1}'), throwsFormatException);
      expect(otra.placa, 'XY-9');
    });

    test('restaura un backup con el formato de la versión web', () async {
      const web = '''
      {"version":3,"motor":"T18SED","modelo":"DESIGN","placa":"AB123CD","kmActual":45300,
       "kmInicial":40000,
       "historial":[{"_id":"a1","tipo":"preventivo","servicioId":"aceite","km":45000,
         "fecha":"05/10/2026, 14:30","costo":"","tipoAceite":"sintetico","viscosidad":"15W-40",
         "marca":"Ultralub","intervalo":10000}],
       "cargas":[{"_id":"c1","fecha":"06/10/2026, 09:00","odometro":45300,"litros":42.5,
         "precioL":null,"tanqueLleno":true,"kmRecorridos":0,"fuenteKm":"odómetro (primera carga)"}],
       "trip":{"kmAcumulado":12.4,"desde":"06/10/2026, 09:05","activo":true},
       "eficienciaEstandar":{"min":8,"max":12,"label":"1.8 L (T18SED / F18D3)"},
       "notificados":{"frenos":true}}''';
      final app = AppState();
      await app.restaurar(web);
      expect(app.kmActual, 45300);
      expect(app.historial.single.fecha, DateTime(2026, 10, 5, 14, 30));
      expect(app.historial.single.intervalo, 10000);
      expect(app.cargas.single.litros, 42.5);
      expect(app.tripKm, 12.4);
      expect(app.consumoMin, isNull);
    });
  });

  testWidgets('la pantalla de inicio cabe en un estéreo de 1024x600', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1024, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final app = AppState();
    await tester.pumpWidget(StereoApp(app: app, obd: ObdController(), gps: TripGps(app)));
    expect(find.text('Mantenimientos'), findsOneWidget);
    expect(find.text('Combustible'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mantenimientos'));
    await tester.pumpAndSettle();
    expect(find.text('Correa de distribución'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final tamano in const [Size(1024, 600), Size(400, 800)]) {
    testWidgets('las pantallas nuevas no se desbordan en $tamano', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = tamano;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final app = AppState();
      await tester.runAsync(() async {
        await app.registrarCarga(app.nuevaCarga(litros: 40, odometro: 50000));
        await app.registrarCarga(app.nuevaCarga(litros: 40, odometro: 50400, precioL: 0.5));
        await app.registrarCarga(app.nuevaCarga(litros: 38, odometro: 50800, tanqueLleno: false));
        await app.registrarCarga(app.nuevaCarga(litros: 41, odometro: 51200, precioL: 0.5));
      });
      await tester.pumpWidget(StereoApp(app: app, obd: ObdController(), gps: TripGps(app)));

      const pantallas = [
        'Combustible', 'Aceite', 'Mantenimientos', 'OBD-II', 'Diagnóstico',
        'Registrar', 'Historial', 'Configuración', 'Exportar',
      ];
      await tester.runAsync(() => app.registrar(Registro(
          tipo: Registro.correctivo,
          servicioId: Registro.correctivo,
          descripcion: 'Cambio de bobina de encendido del cilindro 3',
          costo: '45',
          km: 51000,
          fecha: DateTime.now())));
      await tester.runAsync(() => app.registrar(Registro(
          tipo: Registro.preventivo, servicioId: 'correaDistribucion', km: 1000, fecha: DateTime.now())));
      await tester.pump();
      for (final pantalla in pantallas) {
        await tester.ensureVisible(find.text(pantalla));
        await tester.tap(find.text(pantalla));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: pantalla);
        if (pantalla == 'Combustible') {
          expect(find.text('CONSUMO NORMAL'), findsOneWidget);
          await tester.tap(find.text('Registrar carga'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'diálogo de carga');
          await tester.tap(find.text('Cancelar'));
          await tester.pumpAndSettle();
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });
  }
}
