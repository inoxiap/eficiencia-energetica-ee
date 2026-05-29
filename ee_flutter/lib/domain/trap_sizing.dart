import 'dart:math' as math;

class TrapConstants {
  static const palmOilSpecificHeatKjKgC = 2.0;
  static const palmOilDensityKgL = 0.89;
  static const condensateDensityKgL = 1.0;
  static const defaultSafetyFactor = 1.2;
  static const ambientTemperatureC = 30.0;
  static const freeConvectionUWm2C = 11.36;
  static const boilerHeaderCondensatePercent = 12.0;
  static const secondaryDistributorDrainagePercent = 1.0;
  static const distributorDesignVelocityMS = 10.0;
  static const atmosphericPressureBar = 1.01325;
  static const steamGasConstantJKgK = 461.5;
  static const steamPressureBarG = <double>[
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
  ];
  static const steamTemperatureC = <double>[
    120.2,
    133.5,
    143.6,
    151.8,
    158.8,
    165.0,
    170.4,
    175.4,
    179.9,
    184.1,
    188.0,
    191.6,
    195.0,
    198.3,
    201.4,
  ];
  static const steamLatentHeatKjKg = <double>[
    2201.6,
    2163.2,
    2133.4,
    2108.0,
    2085.8,
    2066.3,
    2048.8,
    2032.9,
    2014.6,
    2000.0,
    1984.3,
    1970.7,
    1957.7,
    1945.2,
    1933.6,
  ];
}

class FieldSpec {
  const FieldSpec({
    required this.key,
    required this.label,
    required this.unit,
    required this.values,
    required this.defaultValue,
    this.labels,
  });

  factory FieldSpec.ranged(
    String key,
    String label,
    String unit,
    double min,
    double max,
    double step,
    double defaultValue,
  ) {
    return FieldSpec(
      key: key,
      label: label,
      unit: unit,
      values: _range(min, max, step),
      defaultValue: defaultValue,
    );
  }

  final String key;
  final String label;
  final String unit;
  final List<double> values;
  final List<String>? labels;
  final double defaultValue;

  String labelFor(double value) {
    final index = values.indexWhere((candidate) => candidate == value);
    if (index >= 0 && labels != null && index < labels!.length) {
      return labels![index];
    }
    return _formatPickerValue(value);
  }
}

class TrapCalculation {
  const TrapCalculation({
    required this.condensateKgH,
    required this.explanation,
  });

  final double condensateKgH;
  final String explanation;
}

class TrapRule {
  const TrapRule({
    required this.name,
    required this.condition,
    required this.trapType,
    required this.observations,
    required this.requiresSizing,
    required this.safetyFactor,
    required this.fields,
    required this.calculate,
  });

  final String name;
  final String condition;
  final String trapType;
  final String observations;
  final bool requiresSizing;
  final double safetyFactor;
  final List<FieldSpec> fields;
  final TrapCalculation Function(Map<String, double> values) calculate;
}

List<TrapRule> createTrapRules() {
  return [
    TrapRule(
      name: 'Tracing',
      condition: 'Baja carga',
      trapType: 'Termodinamica bimetalica',
      observations:
          'Seleccion directa para tracing de vapor. Puede permitir subenfriamiento.',
      requiresSizing: false,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: const [],
      calculate: (_) => const TrapCalculation(
        condensateKgH: 0,
        explanation:
            'Para tracing se selecciona directamente trampa termodinamica bimetalica.',
      ),
    ),
    TrapRule(
      name: 'Serpentin de tanque',
      condition: 'Transferencia de calor',
      trapType: 'Flotador termostatica',
      observations: 'Buena para control estable.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        oilVolumeField(500),
        FieldSpec.ranged(
          'initialTemperature',
          'Temperatura inicial',
          'C',
          0,
          120,
          1,
          30,
        ),
        FieldSpec.ranged(
          'finalTemperature',
          'Temperatura final',
          'C',
          20,
          180,
          1,
          80,
        ),
        heatingTimeField(90),
        FieldSpec.ranged(
          'steamPressure',
          'Presion de vapor de ingreso',
          'bar(g)',
          1,
          15,
          0.5,
          6,
        ),
      ],
      calculate: (values) =>
          _batchHeatingCalculation(values, 'serpentin de tanque'),
    ),
    TrapRule(
      name: 'Chaqueta o Marmita',
      condition: 'Carga variable',
      trapType: 'Flotador termostatica',
      observations:
          'Importante eliminar aire y mantener control fino de temperatura.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        oilVolumeField(200),
        FieldSpec.ranged(
          'initialTemperature',
          'Temperatura inicial',
          'C',
          0,
          120,
          1,
          25,
        ),
        FieldSpec.ranged(
          'finalTemperature',
          'Temperatura final',
          'C',
          20,
          180,
          1,
          80,
        ),
        heatingTimeField(60),
        FieldSpec.ranged(
          'steamPressure',
          'Presion de vapor de ingreso',
          'bar(g)',
          1,
          15,
          0.5,
          6,
        ),
      ],
      calculate: (values) =>
          _batchHeatingCalculation(values, 'chaqueta/marmita'),
    ),
    TrapRule(
      name: 'Chaqueta trabajo pesado',
      condition: 'Drenaje',
      trapType: 'Balde invertido',
      observations: 'Ambientes sucios; priorizar confiabilidad.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        oilVolumeField(300),
        FieldSpec.ranged(
          'initialTemperature',
          'Temperatura inicial',
          'C',
          0,
          120,
          1,
          25,
        ),
        FieldSpec.ranged(
          'finalTemperature',
          'Temperatura final',
          'C',
          20,
          200,
          1,
          95,
        ),
        heatingTimeField(45),
        FieldSpec.ranged(
          'steamPressure',
          'Presion de vapor de ingreso',
          'bar(g)',
          1,
          15,
          0.5,
          7,
        ),
      ],
      calculate: (values) =>
          _batchHeatingCalculation(values, 'chaqueta de trabajo pesado'),
    ),
    TrapRule(
      name: 'Distribuidor principal de caldero',
      condition: 'Drenaje principal con posible arrastre',
      trapType: 'Balde invertido',
      observations:
          'Critico; validar carryover, instalar filtro y considerar separador si el vapor llega humedo.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        FieldSpec.ranged(
          'boilerWaterConsumption',
          'Agua consumida por caldero',
          'm3/h',
          0,
          60,
          1,
          19,
        ),
        FieldSpec.ranged(
          'headerDiameter',
          'Diametro del distribuidor',
          'pulg',
          2,
          24,
          0.5,
          6,
        ),
        FieldSpec.ranged(
          'headerLength',
          'Largo del distribuidor',
          'm',
          1,
          30,
          0.5,
          6,
        ),
        FieldSpec.ranged(
          'steamPressure',
          'Presion del distribuidor',
          'bar(g)',
          1,
          15,
          0.5,
          7,
        ),
      ],
      calculate: _boilerHeaderCalculation,
    ),
    TrapRule(
      name: 'Distribuidor de vapor',
      condition: 'Drenaje de distribucion secundaria',
      trapType: 'Balde invertido',
      observations:
          'Usar para distribuidores alejados del caldero; la produccion total del caldero no representa necesariamente este ramal.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        FieldSpec.ranged(
          'boilerPressure',
          'Presion del caldero',
          'bar(g)',
          1,
          15,
          0.5,
          8,
        ),
        FieldSpec.ranged(
          'steamPressure',
          'Presion del distribuidor',
          'bar(g)',
          1,
          15,
          0.5,
          6,
        ),
        FieldSpec.ranged(
          'headerDiameter',
          'Diametro del distribuidor',
          'pulg',
          1,
          24,
          0.5,
          4,
        ),
        FieldSpec.ranged(
          'headerLength',
          'Largo del distribuidor',
          'm',
          1,
          50,
          0.5,
          6,
        ),
      ],
      calculate: _secondaryDistributorCalculation,
    ),
    TrapRule(
      name: 'Intercambiador de calor',
      condition: 'Alta carga variable',
      trapType: 'Flotador termostatica',
      observations: 'Revisar posible bloqueo por contrapresion.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        FieldSpec.ranged(
          'processFlow',
          'Caudal de aceite o grasa',
          'm3/h',
          1,
          500,
          1,
          10,
        ),
        FieldSpec.ranged(
          'initialTemperature',
          'Temperatura de entrada',
          'C',
          0,
          140,
          1,
          30,
        ),
        FieldSpec.ranged(
          'finalTemperature',
          'Temperatura de salida',
          'C',
          20,
          180,
          1,
          85,
        ),
        FieldSpec.ranged(
          'steamPressure',
          'Presion de vapor',
          'bar(g)',
          1,
          15,
          0.5,
          6,
        ),
      ],
      calculate: _heatExchangerCalculation,
    ),
    TrapRule(
      name: 'Linea principal de vapor (Pierna de condensado)',
      condition: 'Drenaje de linea',
      trapType: 'Balde invertido',
      observations: 'Colocar pierna colectora.',
      requiresSizing: true,
      safetyFactor: TrapConstants.defaultSafetyFactor,
      fields: [
        FieldSpec.ranged(
          'mainDiameter',
          'Diametro de linea principal',
          'pulg',
          1,
          24,
          0.5,
          4,
        ),
        FieldSpec.ranged(
          'mainLength',
          'Longitud entre drenajes',
          'm',
          5,
          200,
          5,
          30,
        ),
        FieldSpec.ranged(
          'steamPressure',
          'Presion de vapor',
          'bar(g)',
          1,
          15,
          0.5,
          7,
        ),
      ],
      calculate: _steamMainCalculation,
    ),
  ];
}

FieldSpec directCondensateField() {
  return FieldSpec.ranged(
    'directCondensate',
    'Caudal de condensado a desalojar',
    'L/min',
    0,
    100,
    1,
    0,
  );
}

FieldSpec oilVolumeField(double defaultValue) {
  return FieldSpec(
    key: 'processVolume',
    label: 'Volumen de aceite o grasa',
    unit: 'L',
    values: [
      ..._range(100, 1000, 100),
      ..._range(1500, 10000, 500),
      ..._range(15000, 50000, 5000),
      ..._range(60000, 1000000, 10000),
    ],
    defaultValue: defaultValue,
  );
}

FieldSpec heatingTimeField(double defaultValue) {
  final values = [
    ..._range(5, 60, 5),
    ..._range(90, 360, 30),
    ..._range(420, 2880, 60),
  ];
  return FieldSpec(
    key: 'heatingTime',
    label: 'Tiempo de calentamiento',
    unit: 'min / h',
    values: values,
    labels: values.map(_heatingTimeLabel).toList(),
    defaultValue: defaultValue,
  );
}

String recommendTrapConnectionDiameter(double requiredCapacityKgH) {
  if (requiredCapacityKgH <= 200) return '1/2 pulg (15 mm)';
  if (requiredCapacityKgH <= 500) return '3/4 pulg (20 mm)';
  if (requiredCapacityKgH <= 1000) return '1 pulg (25 mm)';
  if (requiredCapacityKgH <= 2000) return '1-1/4 pulg (32 mm)';
  if (requiredCapacityKgH <= 3000) return '1-1/2 pulg (40 mm)';
  if (requiredCapacityKgH <= 5000) return '2 pulg (50 mm)';
  return '2-1/2 a 4 pulg (65-100 mm) o trampas en paralelo';
}

TrapCalculation _batchHeatingCalculation(
  Map<String, double> values,
  String source,
) {
  final volume = _value(values, 'processVolume');
  final initial = _value(values, 'initialTemperature');
  final finalTemperature = _value(values, 'finalTemperature');
  final timeMin = _value(values, 'heatingTime');
  final pressure = _value(values, 'steamPressure');
  final deltaT = math.max(0.0, finalTemperature - initial);
  final productMassKg = volume * TrapConstants.palmOilDensityKgL;
  final heatKj =
      productMassKg * TrapConstants.palmOilSpecificHeatKjKgC * deltaT;
  final condensateKg = heatKj / _latentHeat(pressure);
  final condensateKgH = condensateKg * (60 / math.max(5, timeMin));
  return TrapCalculation(
    condensateKgH: math.max(condensateKgH, 5),
    explanation:
        'Estimacion por calentamiento de aceite de palma en $source, usando volumen, temperaturas, tiempo, calor especifico fijo de 2.0 kJ/kg C y presion.',
  );
}

TrapCalculation _boilerHeaderCalculation(Map<String, double> values) {
  final waterConsumptionM3H = _value(values, 'boilerWaterConsumption');
  final diameter = _value(values, 'headerDiameter');
  final length = _value(values, 'headerLength');
  final pressure = _value(values, 'steamPressure');
  final surfaceCondensate = _pipeSurfaceCondensateKgH(
    diameter,
    length,
    pressure,
  );

  if (waterConsumptionM3H > 0) {
    final carryoverCondensate =
        waterConsumptionM3H *
        1000 *
        (TrapConstants.boilerHeaderCondensatePercent / 100);
    final condensate = math.max(surfaceCondensate, carryoverCondensate);
    return TrapCalculation(
      condensateKgH: math.max(condensate, 8),
      explanation:
          'Estimacion para distribuidor principal: agua consumida por caldero x factor interno de condensado/arrastre de 12%. La perdida termica superficial se calcula como respaldo y se toma el mayor valor.',
    );
  }

  return TrapCalculation(
    condensateKgH: math.max(surfaceCondensate, 8),
    explanation:
        'Estimacion por perdida termica de superficie externa del distribuidor principal, con ambiente interno asumido de 30 C.',
  );
}

TrapCalculation _secondaryDistributorCalculation(Map<String, double> values) {
  final boilerPressure = _value(values, 'boilerPressure');
  final distributorPressure = _value(values, 'steamPressure');
  final diameter = _value(values, 'headerDiameter');
  final length = _value(values, 'headerLength');
  final surfaceCondensate = _pipeSurfaceCondensateKgH(
    diameter,
    length,
    distributorPressure,
  );
  final estimatedSteamCapacity = _estimatedDistributorSteamCapacityKgH(
    diameter,
    distributorPressure,
  );
  final fraction = _pressureFraction(boilerPressure, distributorPressure);
  final runningDrainage =
      estimatedSteamCapacity *
      (TrapConstants.secondaryDistributorDrainagePercent / 100) *
      fraction;
  final condensate = math.max(surfaceCondensate, runningDrainage);

  return TrapCalculation(
    condensateKgH: math.max(condensate, 8),
    explanation:
        'Estimacion para distribuidor secundario: se calcula una capacidad probable de vapor con diametro, presion y velocidad interna de referencia de 10 m/s; luego se toma 1% como drenaje tipico de linea y se ajusta por presion.',
  );
}

TrapCalculation _heatExchangerCalculation(Map<String, double> values) {
  final flowM3H = _value(values, 'processFlow');
  final deltaT = math.max(
    0.0,
    _value(values, 'finalTemperature') - _value(values, 'initialTemperature'),
  );
  final pressure = _value(values, 'steamPressure');
  final processKgH = flowM3H * 1000 * TrapConstants.palmOilDensityKgL;
  final dutyKw =
      processKgH * TrapConstants.palmOilSpecificHeatKjKgC * deltaT / 3600;
  final condensate = dutyKw * 3600 / _latentHeat(pressure);
  return TrapCalculation(
    condensateKgH: math.max(condensate, 5),
    explanation:
        'Estimacion por carga termica del aceite o grasa, convirtiendo caudal a masa con densidad fija de 0.89 kg/L, calor especifico fijo de 2.0 kJ/kg C y calor latente del vapor.',
  );
}

TrapCalculation _steamMainCalculation(Map<String, double> values) {
  final diameter = _value(values, 'mainDiameter');
  final length = _value(values, 'mainLength');
  final pressure = _value(values, 'steamPressure');
  final condensateKgH = _pipeSurfaceCondensateKgH(diameter, length, pressure);
  return TrapCalculation(
    condensateKgH: math.max(condensateKgH, 8),
    explanation:
        'Estimacion por perdida termica de operacion en el tramo entre drenajes, con ambiente interno asumido de 30 C.',
  );
}

double _pipeSurfaceCondensateKgH(
  double diameterInches,
  double lengthMeters,
  double pressureBarG,
) {
  final area = math.pi * _inchesToMeters(diameterInches) * lengthMeters;
  final heatLossW = _radiantHeatLossW(
    area,
    pressureBarG,
    TrapConstants.ambientTemperatureC,
  );
  return heatLossW * 3.6 / _latentHeat(pressureBarG);
}

double _radiantHeatLossW(
  double areaM2,
  double steamPressureBarG,
  double ambientTemperatureC,
) {
  final deltaT = math.max(
    0.0,
    _saturationTemperature(steamPressureBarG) - ambientTemperatureC,
  );
  return areaM2 * TrapConstants.freeConvectionUWm2C * deltaT;
}

double _estimatedDistributorSteamCapacityKgH(
  double diameterInches,
  double pressureBarG,
) {
  final diameterMeters = _inchesToMeters(diameterInches);
  final flowAreaM2 = math.pi * diameterMeters * diameterMeters / 4;
  return flowAreaM2 *
      TrapConstants.distributorDesignVelocityMS *
      _saturatedSteamDensityKgM3(pressureBarG) *
      3600;
}

double _saturatedSteamDensityKgM3(double pressureBarG) {
  final absolutePressurePa =
      (pressureBarG + TrapConstants.atmosphericPressureBar) * 100000;
  final saturationTemperatureK = _saturationTemperature(pressureBarG) + 273.15;
  return absolutePressurePa /
      (TrapConstants.steamGasConstantJKgK * saturationTemperatureK);
}

double _pressureFraction(
  double boilerPressureBarG,
  double distributorPressureBarG,
) {
  final boilerAbsolute = math.max(
    TrapConstants.atmosphericPressureBar,
    boilerPressureBarG + TrapConstants.atmosphericPressureBar,
  );
  final distributorAbsolute = math.max(
    TrapConstants.atmosphericPressureBar,
    distributorPressureBarG + TrapConstants.atmosphericPressureBar,
  );
  return (distributorAbsolute / boilerAbsolute).clamp(0.25, 1.0);
}

double _saturationTemperature(double barGauge) {
  return _interpolateSteamProperty(barGauge, TrapConstants.steamTemperatureC);
}

double _latentHeat(double barGauge) {
  return _interpolateSteamProperty(barGauge, TrapConstants.steamLatentHeatKjKg);
}

double _interpolateSteamProperty(double barGauge, List<double> values) {
  final pressures = TrapConstants.steamPressureBarG;
  if (barGauge <= pressures.first) return values.first;
  if (barGauge >= pressures.last) return values.last;

  for (var index = 0; index < pressures.length - 1; index += 1) {
    final lowPressure = pressures[index];
    final highPressure = pressures[index + 1];
    if (barGauge >= lowPressure && barGauge <= highPressure) {
      final fraction = (barGauge - lowPressure) / (highPressure - lowPressure);
      return values[index] + (values[index + 1] - values[index]) * fraction;
    }
  }
  return values.last;
}

double _value(Map<String, double> values, String key) => values[key] ?? 0;

double _inchesToMeters(double inches) => inches * 0.0254;

List<double> _range(double min, double max, double step) {
  final values = <double>[];
  for (var value = min; value <= max + 0.0001; value += step) {
    values.add((value * 10).round() / 10);
  }
  return values;
}

String _formatPickerValue(double value) {
  if ((value - value.round()).abs() > 0.001) {
    return value.toStringAsFixed(1);
  }
  return value.round().toString();
}

String _heatingTimeLabel(double minutes) {
  if (minutes <= 60) {
    return '${minutes.round()} min';
  }
  final hours = minutes / 60;
  if ((hours - hours.round()).abs() < 0.001) {
    return '${hours.round()} h';
  }
  return '${hours.toStringAsFixed(1)} h';
}
