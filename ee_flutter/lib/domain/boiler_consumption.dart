const boilerNames = <String>[
  'Caldera Alfa Laval 1200',
  'Caldera Distral 900',
  'Caldera Cleaver Brooks 1200',
];

const alfaLavalBoiler = 'Caldera Alfa Laval 1200';

class BoilerReading {
  const BoilerReading({
    required this.id,
    required this.recordedAt,
    required this.createdAt,
    required this.boilerName,
    required this.fuelTotal,
    required this.waterTotal,
    required this.steamTotal,
    required this.operatorPin,
    required this.fuelConsumption,
    required this.waterConsumption,
    required this.steamConsumption,
  });

  final String id;
  final DateTime recordedAt;
  final DateTime createdAt;
  final String boilerName;
  final double fuelTotal;
  final double waterTotal;
  final double? steamTotal;
  final String operatorPin;
  final double? fuelConsumption;
  final double? waterConsumption;
  final double? steamConsumption;

  BoilerReading copyWith({
    double? fuelConsumption,
    double? waterConsumption,
    double? steamConsumption,
  }) {
    return BoilerReading(
      id: id,
      recordedAt: recordedAt,
      createdAt: createdAt,
      boilerName: boilerName,
      fuelTotal: fuelTotal,
      waterTotal: waterTotal,
      steamTotal: steamTotal,
      operatorPin: operatorPin,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      waterConsumption: waterConsumption ?? this.waterConsumption,
      steamConsumption: steamConsumption ?? this.steamConsumption,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'boilerName': boilerName,
    'fuelTotal': fuelTotal,
    'waterTotal': waterTotal,
    'steamTotal': steamTotal,
    'operatorPin': operatorPin,
    'fuelConsumption': fuelConsumption,
    'waterConsumption': waterConsumption,
    'steamConsumption': steamConsumption,
  };

  factory BoilerReading.fromJson(Map<String, dynamic> json) {
    final recorded = DateTime.tryParse(json['recordedAt'] as String? ?? '');
    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    return BoilerReading(
      id: json['id'] as String? ?? '',
      recordedAt: recorded ?? DateTime.now(),
      createdAt: created ?? recorded ?? DateTime.now(),
      boilerName: json['boilerName'] as String? ?? '',
      fuelTotal: _toDouble(json['fuelTotal']),
      waterTotal: _toDouble(json['waterTotal']),
      steamTotal: _toDoubleOrNull(json['steamTotal']),
      operatorPin: json['operatorPin'] as String? ?? '',
      fuelConsumption: _toDoubleOrNull(json['fuelConsumption']),
      waterConsumption: _toDoubleOrNull(json['waterConsumption']),
      steamConsumption: _toDoubleOrNull(json['steamConsumption']),
    );
  }
}

class BoilerConsumptionCalculator {
  const BoilerConsumptionCalculator._();

  static BoilerReading attachDeltas(
    BoilerReading reading,
    List<BoilerReading> existingReadings,
  ) {
    final previous = _previousReading(reading, existingReadings);
    return reading.copyWith(
      fuelConsumption: _delta(reading.fuelTotal, previous?.fuelTotal),
      waterConsumption: _delta(reading.waterTotal, previous?.waterTotal),
      steamConsumption: _delta(reading.steamTotal, previous?.steamTotal),
    );
  }

  static BoilerReading? _previousReading(
    BoilerReading reading,
    List<BoilerReading> existingReadings,
  ) {
    final candidates = existingReadings
        .where(
          (item) =>
              item.id != reading.id &&
              item.boilerName == reading.boilerName &&
              item.recordedAt.isBefore(reading.recordedAt),
        )
        .toList();
    candidates.sort(
      (left, right) => right.recordedAt.compareTo(left.recordedAt),
    );
    return candidates.firstOrNull;
  }

  static double? _delta(double? current, double? previous) {
    if (current == null || previous == null) {
      return null;
    }
    final value = current - previous;
    if (value < 0) {
      return null;
    }
    return value;
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
