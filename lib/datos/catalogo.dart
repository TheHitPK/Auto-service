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
  'F18D3': 'F18D3 (1.8 L)',
  'T18SED': 'T18SED (1.8 L) - Design / Advance',
};

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
    ['Cuerpo aceleración sucio', 'Bujías viejas', 'MAF sucio', 'Fuga de vacío', 'CKP degradado'],
  ),
  'consumo': (
    'Alto consumo',
    ['Sensor O2 desgastado', 'MAF sucio', 'Filtro aire obstruido', 'Inyectores sucios'],
  ),
  'check': (
    'Check Engine',
    ['Sensor O2 fallando', 'MAF/MAP erróneo', 'Bobina encendido', 'Sensor ECT', 'Tapa combustible'],
  ),
  'arranque': (
    'Dificultad arranque',
    ['Sensor CKP defectuoso', 'Sensor CMP fallando', 'Bomba combustible', 'Batería'],
  ),
  'potencia': (
    'Pérdida potencia',
    ['MAF sucio', 'Filtro combustible', 'Sensor O2 lento', 'Catalizador', 'Correa distribución'],
  ),
  'tirones': ('Tirones', ['Bujías viejas', 'Bobina defectuosa', 'Inyectores', 'TPS sucio']),
  'calor': ('Sobrecalentamiento', ['Sensor ECT', 'Termostato', 'Ventilador', 'Refrigerante bajo']),
  'humo': (
    'Humo negro',
    ['MAF sucio', 'Inyectores fuga', 'Regulador presión', 'Sensor O2 corto'],
  ),
  'olfato': ('Olor a gasolina', ['Fuga combustible', 'Sello inyector', 'Canister saturado']),
  'ventilador': ('Ventilador no enciende', ['Sensor ECT', 'Relay', 'Motor ventilador', 'Fusible']),
};
