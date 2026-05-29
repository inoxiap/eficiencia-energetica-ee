import 'dart:math' as math;

const barePipeSections = <String>[
  'Jaboneria',
  'Margarina',
  'Calderas',
  'Refineria',
  'Hidrogenacion',
  'Envase',
  'Confiteria',
];

const barePipeDiameters = <PipeDiameter>[
  PipeDiameter('1/2"', 21.3),
  PipeDiameter('3/4"', 26.7),
  PipeDiameter('1"', 33.4),
  PipeDiameter('1 1/4"', 42.2),
  PipeDiameter('1 1/2"', 48.3),
  PipeDiameter('2"', 60.3),
  PipeDiameter('3"', 88.9),
  PipeDiameter('4"', 114.3),
  PipeDiameter('6"', 168.3),
];

const saturationTemperatureByPressure = <(double, double)>[
  (0, 100),
  (1, 120.2),
  (2, 133.5),
  (3, 143.6),
  (4, 152),
  (5, 158.9),
  (6, 164.9),
  (7, 170.4),
  (8, 175.4),
  (9, 180),
  (10, 184.1),
  (11, 187.8),
  (12, 191.6),
  (13, 195),
  (14, 198.3),
  (15, 201.4),
  (16, 204.3),
  (17, 207),
  (18, 209.6),
  (19, 212.3),
  (20, 214.9),
];

class PipeDiameter {
  const PipeDiameter(this.label, this.outsideDiameterMm);

  final String label;
  final double outsideDiameterMm;
}

class BarePipeCalculation {
  const BarePipeCalculation({
    required this.status,
    required this.heatLossWPerM,
    required this.heatLossKw,
    required this.energyKwhMonth,
    required this.monthlyGallons,
    required this.monthlyUsd,
    this.surfaceTemperatureC,
  });

  final String status;
  final double? surfaceTemperatureC;
  final double heatLossWPerM;
  final double heatLossKw;
  final double energyKwhMonth;
  final double monthlyGallons;
  final double monthlyUsd;

  bool get isCalculated => status == 'calculated';

  Map<String, dynamic> toJson() => {
    'status': status,
    'surfaceTemperatureC': surfaceTemperatureC,
    'heatLossWPerM': heatLossWPerM,
    'heatLossKw': heatLossKw,
    'energyKwhMonth': energyKwhMonth,
    'monthlyGallons': monthlyGallons,
    'monthlyUsd': monthlyUsd,
  };

  factory BarePipeCalculation.fromJson(Map<String, dynamic> json) {
    return BarePipeCalculation(
      status: json['status'] as String? ?? 'pending',
      surfaceTemperatureC: _toDoubleOrNull(json['surfaceTemperatureC']),
      heatLossWPerM: _toDouble(json['heatLossWPerM']),
      heatLossKw: _toDouble(json['heatLossKw']),
      energyKwhMonth: _toDouble(json['energyKwhMonth']),
      monthlyGallons: _toDouble(json['monthlyGallons']),
      monthlyUsd: _toDouble(json['monthlyUsd']),
    );
  }

  static const pending = BarePipeCalculation(
    status: 'pending',
    heatLossWPerM: 0,
    heatLossKw: 0,
    energyKwhMonth: 0,
    monthlyGallons: 0,
    monthlyUsd: 0,
  );
}

class BarePipeReport {
  const BarePipeReport({
    required this.id,
    required this.createdAt,
    required this.section,
    required this.diameterLabel,
    required this.pressureBarG,
    required this.lengthMeters,
    required this.photoUrl,
    required this.photoPublicId,
    required this.calculation,
  });

  final String id;
  final DateTime createdAt;
  final String section;
  final String diameterLabel;
  final double? pressureBarG;
  final double? lengthMeters;
  final String photoUrl;
  final String photoPublicId;
  final BarePipeCalculation calculation;

  String get thumbnailUrl {
    if (!photoUrl.contains('/upload/')) {
      return photoUrl;
    }
    return photoUrl.replaceFirst(
      '/upload/',
      '/upload/c_fill,w_320,h_220,q_auto,f_auto/',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'section': section,
    'diameterLabel': diameterLabel,
    'pressureBarG': pressureBarG,
    'lengthMeters': lengthMeters,
    'photoUrl': photoUrl,
    'photoPublicId': photoPublicId,
    'calculation': calculation.toJson(),
  };

  factory BarePipeReport.fromJson(Map<String, dynamic> json) {
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final calculationJson = json['calculation'];
    return BarePipeReport(
      id: json['id'] as String? ?? '',
      createdAt: created ?? DateTime.now(),
      section: json['section'] as String? ?? '',
      diameterLabel: json['diameterLabel'] as String? ?? '',
      pressureBarG: _toDoubleOrNull(json['pressureBarG']),
      lengthMeters: _toDoubleOrNull(json['lengthMeters']),
      photoUrl: json['photoUrl'] as String? ?? '',
      photoPublicId: json['photoPublicId'] as String? ?? '',
      calculation: calculationJson is Map<String, dynamic>
          ? BarePipeCalculation.fromJson(calculationJson)
          : BarePipeCalculation.pending,
    );
  }
}

class BarePipeCalculator {
  static const ambientTemperatureC = 27.0;
  static const emissivity = 0.8;
  static const stefanBoltzmann = 5.670374419e-8;
  static const airThermalConductivityWmK = 0.03;
  static const airKinematicViscosityM2S = 0.0000225;
  static const airThermalDiffusivityM2S = 0.000032;
  static const hoursPerDay = 24.0;
  static const daysPerMonth = 30.0;
  static const btuPerKwh = 3412.0;
  static const bunkerPciBtuGal = 139000.0;
  static const boilerEfficiency = 0.76;
  static const bunkerUsdGal = 0.94;

  static BarePipeCalculation calculate({
    required String diameterLabel,
    required double? pressureBarG,
    required double? lengthMeters,
  }) {
    final diameter = barePipeDiameters
        .where((candidate) => candidate.label == diameterLabel)
        .firstOrNull;

    if (diameter == null ||
        pressureBarG == null ||
        lengthMeters == null ||
        lengthMeters <= 0) {
      return BarePipeCalculation.pending;
    }

    final surfaceTemperatureC = saturationTemperature(pressureBarG);
    final diameterM = diameter.outsideDiameterMm / 1000;
    final deltaT = math.max(0.0, surfaceTemperatureC - ambientTemperatureC);
    final filmTemperatureK =
        ((surfaceTemperatureC + 273.15) + (ambientTemperatureC + 273.15)) / 2;
    final beta = 1 / filmTemperatureK;
    final rayleigh =
        9.81 *
        beta *
        deltaT *
        math.pow(diameterM, 3) /
        (airKinematicViscosityM2S * airThermalDiffusivityM2S);
    final nusselt =
        0.36 +
        (0.518 * math.pow(math.max(rayleigh, 0), 0.25)) /
            math.pow(1 + math.pow(0.559 / 0.7, 9 / 16), 4 / 9);
    final convectiveWPerM =
        nusselt *
        (airThermalConductivityWmK / diameterM) *
        math.pi *
        diameterM *
        deltaT;
    final radiativeWPerM =
        emissivity *
        stefanBoltzmann *
        math.pi *
        diameterM *
        (math.pow(surfaceTemperatureC + 273.15, 4) -
            math.pow(ambientTemperatureC + 273.15, 4));
    final heatLossWPerM = convectiveWPerM + radiativeWPerM;
    final heatLossKw = heatLossWPerM * lengthMeters / 1000;
    final hoursPerMonth = hoursPerDay * daysPerMonth;
    final energyKwhMonth = heatLossKw * hoursPerMonth;
    final monthlyGallons =
        heatLossWPerM *
        lengthMeters *
        (hoursPerMonth / 1000) *
        btuPerKwh /
        (bunkerPciBtuGal * boilerEfficiency);
    final monthlyUsd = monthlyGallons * bunkerUsdGal;

    return BarePipeCalculation(
      status: 'calculated',
      surfaceTemperatureC: surfaceTemperatureC,
      heatLossWPerM: heatLossWPerM,
      heatLossKw: heatLossKw,
      energyKwhMonth: energyKwhMonth,
      monthlyGallons: monthlyGallons,
      monthlyUsd: monthlyUsd,
    );
  }

  static double saturationTemperature(double pressureBarG) {
    final table = saturationTemperatureByPressure;
    if (pressureBarG <= table.first.$1) {
      return table.first.$2;
    }
    if (pressureBarG >= table.last.$1) {
      return table.last.$2;
    }

    for (var index = 0; index < table.length - 1; index += 1) {
      final low = table[index];
      final high = table[index + 1];
      if (pressureBarG >= low.$1 && pressureBarG <= high.$1) {
        final fraction = (pressureBarG - low.$1) / (high.$1 - low.$1);
        return low.$2 + (high.$2 - low.$2) * fraction;
      }
    }
    return table.last.$2;
  }
}

double _toDouble(Object? value) => _toDoubleOrNull(value) ?? 0;

double? _toDoubleOrNull(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}
