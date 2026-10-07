class Servicio {
  const Servicio(this.id, this.nombre, this.intervaloKm);

  final String id;
  final String nombre;
  final int intervaloKm;

  bool get esSensor => id.startsWith('sensor');
  bool get esCritico => id == 'correaDistribucion';
}

const idAceite = 'aceite';

/// Plan de mantenimiento del Optra 1.8 (F18D3 / T18SED).
const servicios = <Servicio>[
  Servicio(idAceite, 'Cambio de aceite y filtro', 5000),
  Servicio('filtroAire', 'Filtro de aire', 30000),
  Servicio('filtroCombustible', 'Filtro de combustible', 45000),
  Servicio('refrigerante', 'Cambio de refrigerante', 45000),
  Servicio('correaDistribucion', 'Correa de distribución', 55000),
  Servicio('bujias', 'Bujías', 30000),
  Servicio('correaAccesorios', 'Correa de accesorios', 60000),
  Servicio('aceiteTransmision', 'Aceite de transmisión', 80000),
  Servicio('frenos', 'Inspección de frenos', 10000),
  Servicio('sensorO2', 'Sensor de Oxígeno (Lambda)', 100000),
  Servicio('sensorCkp', 'Sensor Cigüeñal (CKP)', 120000),
  Servicio('sensorCmp', 'Sensor Levas (CMP)', 120000),
  Servicio('sensorMaf', 'Sensor MAF (Flujo de aire)', 100000),
  Servicio('sensorEct', 'Sensor Temp. Refrigerante (ECT)', 100000),
  Servicio('sensorKnock', 'Sensor de Detonación (Knock)', 120000),
];

Servicio? servicioPorId(String id) {
  for (final s in servicios) {
    if (s.id == id) return s;
  }
  return null;
}

const modelos = ['LIMITED', 'DESIGN', 'ADVANCE'];

const motores = {
  'F16D3': 'F16D3 (1.6 L)',
  'F18D3': 'F18D3 (1.8 L)',
  'T18SED': 'T18SED (1.8 L) - Design / Advance',
};

class RangoConsumo {
  const RangoConsumo(this.min, this.max, this.nombre);

  /// En km/L.
  final double min;
  final double max;
  final String nombre;
}

/// Rango normal de consumo por motor: valores orientativos del fabricante
/// y de reportes reales, que el usuario puede cambiar en Configuración.
RangoConsumo consumoEstandar(String motor) => motor.contains('16')
    ? const RangoConsumo(7, 11, '1.6 L (F16D3)')
    : const RangoConsumo(8, 12, '1.8 L (T18SED / F18D3)');

const tiposAceite = {
  'mineral': 'Mineral',
  'semisintetico': 'Semisintético',
  'sintetico': 'Sintético',
};

const intervaloPorTipoAceite = {
  'mineral': 5000,
  'semisintetico': 7000,
  'sintetico': 10000,
};

const viscosidades = {
  '15W-40': '15W-40 (recomendado para Optra en Venezuela)',
  '10W-30': '10W-30',
  '5W-30': '5W-30',
  '20W-50': '20W-50',
};

const marcaOtra = 'otra';

const marcasAceite = {
  'Ultralub': 'Ultralub (Venezuela) ⭐ Recomendado',
  'Shell': 'Shell (Internacional)',
  'Motul': 'Motul (Internacional)',
  'Inca': 'Inca (Venezuela)',
  'Castrol': 'Castrol (Internacional)',
  'Mobil': 'Mobil (Internacional)',
  'Valvoline': 'Valvoline (Internacional)',
  'PDV': 'PDV (Venezuela)',
  'Gulf': 'Gulf (Internacional)',
  'KRS': 'KRS (Venezuela)',
  'LMV': 'LMV (Venezuela)',
  'Sky': 'Sky (Venezuela)',
  'Vtech': 'Vtech (Internacional)',
  marcaOtra: 'Otra...',
};

/// Síntoma -> posibles causas.
const sintomas = <String, (String, List<String>)>{
  'ralenti': (
    'Ralentí inestable',
    ['Cuerpo de aceleración sucio', 'Bujías viejas', 'MAF sucio', 'Fuga de vacío', 'CKP degradado'],
  ),
  'consumo': (
    'Alto consumo',
    [
      'Sensor O2 desgastado',
      'MAF sucio',
      'Filtro de aire obstruido',
      'Inyectores sucios',
      'Presión de neumáticos',
    ],
  ),
  'check': (
    'Check Engine',
    [
      'Sensor O2 fallando',
      'MAF/MAP erróneo',
      'Bobina de encendido',
      'Sensor ECT',
      'Tapa de combustible floja',
    ],
  ),
  'arranque': (
    'Dificultad arranque',
    [
      'Sensor CKP defectuoso',
      'Sensor CMP fallando',
      'Bomba de combustible',
      'Batería baja',
      'Inmovilizador',
    ],
  ),
  'potencia': (
    'Pérdida potencia',
    [
      'MAF sucio',
      'Filtro de combustible',
      'Sensor O2 lento',
      'Catalizador obstruido',
      'Correa de distribución',
    ],
  ),
  'tirones': (
    'Tirones',
    ['Bujías viejas', 'Bobina defectuosa', 'Inyectores sucios', 'TPS sucio', 'Cables de bujía'],
  ),
  'calor': (
    'Sobrecalentamiento',
    ['Sensor ECT', 'Termostato', 'Ventilador no funciona', 'Refrigerante bajo', 'Radiador obstruido'],
  ),
  'humo': (
    'Humo negro',
    ['MAF sucio', 'Inyectores con fuga', 'Regulador de presión', 'Sensor O2 en corto'],
  ),
  'olfato': (
    'Olor a gasolina',
    ['Fuga de combustible', 'Sello de inyector', 'Canister saturado', 'Tapa de tanque'],
  ),
  'ventilador': (
    'Ventilador no enciende',
    ['Sensor ECT', 'Relay del ventilador', 'Motor del ventilador', 'Fusible'],
  ),
};
