const boilerConsumptionSchemaVersion = 3;
const defaultBoilerPressureUnit = 'psi';
const pendingUnit = 'pending_confirmation';
const alfaBunkerLitersPerGallon = 3.79;
const alfaWaterLitersPerCounterUnit = 10.0;
const alfaWaterGallonsPerCounterUnit = 2.64;
const boilerSafetyReferenceVersion = 'regist_inform_p99_2026_07_23_v1';

double alfaBunkerGallonsFromLiters(double liters) =>
    liters / alfaBunkerLitersPerGallon;

double alfaWaterGallonsFromCounter(double counterUnits) =>
    counterUnits * alfaWaterGallonsPerCounterUnit;

double alfaWaterLitersFromCounter(double counterUnits) =>
    counterUnits * alfaWaterLitersPerCounterUnit;

class BoilerSafetyLimits {
  const BoilerSafetyLimits({
    required this.bunkerGallonsPerHour,
    required this.waterGallonsPerHour,
  });

  final double bunkerGallonsPerHour;
  final double waterGallonsPerHour;
}

const boilerSafetyLimits = <String, BoilerSafetyLimits>{
  'alfa_laval_1200': BoilerSafetyLimits(
    bunkerGallonsPerHour: 380,
    waterGallonsPerHour: 6600,
  ),
  'cleaver_brooks_1200': BoilerSafetyLimits(
    bunkerGallonsPerHour: 415,
    waterGallonsPerHour: 5750,
  ),
  'distral_900': BoilerSafetyLimits(
    bunkerGallonsPerHour: 345,
    waterGallonsPerHour: 4700,
  ),
};

class BoilerDefinition {
  const BoilerDefinition({
    required this.id,
    required this.displayName,
    required this.readsSteam,
    this.waterUnit = 'gal',
    this.bunkerUnit = 'gal',
    this.steamUnit = 'gal',
  });

  final String id;
  final String displayName;
  final bool readsSteam;
  final String waterUnit;
  final String bunkerUnit;
  final String steamUnit;
}

const boilerDefinitions = <BoilerDefinition>[
  BoilerDefinition(
    id: 'alfa_laval_1200',
    displayName: 'Caldera Alfa Laval 1200',
    readsSteam: true,
    steamUnit: 'kg',
  ),
  BoilerDefinition(
    id: 'distral_900',
    displayName: 'Caldera Distral 900',
    readsSteam: false,
  ),
  BoilerDefinition(
    id: 'cleaver_brooks_1200',
    displayName: 'Caldera Cleaver Brooks 1200',
    readsSteam: false,
  ),
];

const boilerNames = <String>[
  'Caldera Alfa Laval 1200',
  'Caldera Distral 900',
  'Caldera Cleaver Brooks 1200',
];

const alfaLavalBoiler = 'Caldera Alfa Laval 1200';

BoilerDefinition? boilerByName(String name) {
  for (final boiler in boilerDefinitions) {
    if (boiler.displayName == name) {
      return boiler;
    }
  }
  return null;
}

BoilerDefinition? boilerById(String id) {
  for (final boiler in boilerDefinitions) {
    if (boiler.id == id) {
      return boiler;
    }
  }
  return null;
}

class BoilerReading {
  const BoilerReading({
    required this.id,
    required this.recordedAt,
    required this.createdAt,
    required this.boilerName,
    required this.fuelTotal,
    required this.waterTotal,
    required this.steamTotal,
    required this.fuelConsumption,
    required this.waterConsumption,
    required this.steamConsumption,
    this.operatorPin = '',
    this.boilerId = '',
    this.readingMode = 'cumulative_meter',
    this.waterUnit = pendingUnit,
    this.bunkerUnit = pendingUnit,
    this.steamUnit = pendingUnit,
    this.boilerPressurePsi,
    this.boilerPressureUnit = defaultBoilerPressureUnit,
    this.intervalStart,
    this.intervalEnd,
    this.revision = 1,
    this.replacesRecordId,
    this.rootRecordId,
    this.validationWarnings = const [],
    this.notes = '',
    this.status = 'synced',
    this.createdByUid = '',
    this.createdByNameSnapshot = '',
    this.originalInputs = const {},
    this.validationReferenceVersion = '',
  });

  final String id;
  final DateTime recordedAt;
  final DateTime createdAt;
  final String boilerName;
  final String boilerId;
  final String readingMode;
  final double fuelTotal;
  final double waterTotal;
  final double? steamTotal;
  final String operatorPin;
  final String waterUnit;
  final String bunkerUnit;
  final String steamUnit;
  final double? boilerPressurePsi;
  final String boilerPressureUnit;
  final DateTime? intervalStart;
  final DateTime? intervalEnd;
  final int revision;
  final String? replacesRecordId;
  final String? rootRecordId;
  final List<String> validationWarnings;
  final String notes;
  final String status;
  final String createdByUid;
  final String createdByNameSnapshot;
  final Map<String, dynamic> originalInputs;
  final String validationReferenceVersion;
  final double? fuelConsumption;
  final double? waterConsumption;
  final double? steamConsumption;

  String get effectiveBoilerId {
    if (boilerId.isNotEmpty) {
      return boilerId;
    }
    return boilerByName(boilerName)?.id ?? boilerName;
  }

  BoilerReading copyWith({
    double? fuelConsumption,
    double? waterConsumption,
    double? steamConsumption,
    int? revision,
    String? id,
    String? replacesRecordId,
    String? rootRecordId,
    String? status,
    List<String>? validationWarnings,
    bool clearOperatorPin = false,
  }) {
    return BoilerReading(
      id: id ?? this.id,
      recordedAt: recordedAt,
      createdAt: createdAt,
      boilerName: boilerName,
      boilerId: boilerId,
      readingMode: readingMode,
      fuelTotal: fuelTotal,
      waterTotal: waterTotal,
      steamTotal: steamTotal,
      operatorPin: clearOperatorPin ? '' : operatorPin,
      waterUnit: waterUnit,
      bunkerUnit: bunkerUnit,
      steamUnit: steamUnit,
      boilerPressurePsi: boilerPressurePsi,
      boilerPressureUnit: boilerPressureUnit,
      intervalStart: intervalStart,
      intervalEnd: intervalEnd,
      revision: revision ?? this.revision,
      replacesRecordId: replacesRecordId ?? this.replacesRecordId,
      rootRecordId: rootRecordId ?? this.rootRecordId,
      validationWarnings: validationWarnings ?? this.validationWarnings,
      notes: notes,
      status: status ?? this.status,
      createdByUid: createdByUid,
      createdByNameSnapshot: createdByNameSnapshot,
      originalInputs: originalInputs,
      validationReferenceVersion: validationReferenceVersion,
      fuelConsumption: fuelConsumption ?? this.fuelConsumption,
      waterConsumption: waterConsumption ?? this.waterConsumption,
      steamConsumption: steamConsumption ?? this.steamConsumption,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'boilerId': effectiveBoilerId,
    'boilerName': boilerName,
    'boilerNameSnapshot': boilerName,
    'readingMode': readingMode,
    'fuelTotal': fuelTotal,
    'waterTotal': waterTotal,
    'steamTotal': steamTotal,
    'bunkerValue': fuelTotal,
    'waterValue': waterTotal,
    'steamValue': steamTotal,
    'bunkerUnit': bunkerUnit,
    'waterUnit': waterUnit,
    'steamUnit': steamUnit,
    'boilerPressurePsi': boilerPressurePsi,
    'boilerPressureUnit': boilerPressureUnit,
    'fuelConsumption': fuelConsumption,
    'waterConsumption': waterConsumption,
    'steamConsumption': steamConsumption,
    'bunkerIntervalConsumption': fuelConsumption,
    'waterIntervalConsumption': waterConsumption,
    'steamIntervalConsumption': steamConsumption,
    'intervalStart': intervalStart?.toIso8601String(),
    'intervalEnd': intervalEnd?.toIso8601String(),
    'revision': revision,
    'replacesRecordId': replacesRecordId,
    'rootRecordId': rootRecordId ?? id,
    'validationWarnings': validationWarnings,
    if (originalInputs.isNotEmpty) 'originalInputs': originalInputs,
    if (validationReferenceVersion.isNotEmpty)
      'validationReferenceVersion': validationReferenceVersion,
    'notes': notes,
    'status': status,
    'schemaVersion': boilerPressurePsi == null
        ? 1
        : originalInputs.isEmpty
        ? 2
        : boilerConsumptionSchemaVersion,
    if (createdByUid.isNotEmpty) 'createdByUid': createdByUid,
    if (createdByNameSnapshot.isNotEmpty)
      'createdByNameSnapshot': createdByNameSnapshot,
    if (operatorPin.isNotEmpty) 'operatorPin': operatorPin,
  };

  factory BoilerReading.fromJson(Map<String, dynamic> json) {
    final recorded = _toDateTime(json['recordedAt']);
    final created = _toDateTime(json['createdAt']);
    final boilerName =
        json['boilerNameSnapshot'] as String? ??
        json['boilerName'] as String? ??
        '';
    final boiler = boilerByName(boilerName);
    return BoilerReading(
      id: json['id'] as String? ?? '',
      recordedAt: recorded ?? DateTime.now(),
      createdAt: created ?? recorded ?? DateTime.now(),
      boilerName: boilerName,
      boilerId: json['boilerId'] as String? ?? boiler?.id ?? '',
      readingMode: json['readingMode'] as String? ?? 'cumulative_meter',
      fuelTotal: _toDouble(json['bunkerValue'] ?? json['fuelTotal']),
      waterTotal: _toDouble(json['waterValue'] ?? json['waterTotal']),
      steamTotal: _toDoubleOrNull(json['steamValue'] ?? json['steamTotal']),
      operatorPin: json['operatorPin'] as String? ?? '',
      waterUnit:
          json['waterUnit'] as String? ?? boiler?.waterUnit ?? pendingUnit,
      bunkerUnit:
          json['bunkerUnit'] as String? ?? boiler?.bunkerUnit ?? pendingUnit,
      steamUnit:
          json['steamUnit'] as String? ?? boiler?.steamUnit ?? pendingUnit,
      boilerPressurePsi: _toDoubleOrNull(json['boilerPressurePsi']),
      boilerPressureUnit:
          json['boilerPressureUnit'] as String? ?? defaultBoilerPressureUnit,
      intervalStart: _toDateTime(json['intervalStart']),
      intervalEnd: _toDateTime(json['intervalEnd']),
      revision: _toInt(json['revision']) ?? 1,
      replacesRecordId: json['replacesRecordId'] as String?,
      rootRecordId: json['rootRecordId'] as String?,
      validationWarnings:
          (json['validationWarnings'] as List?)?.whereType<String>().toList() ??
          const [],
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'synced',
      createdByUid: json['createdByUid'] as String? ?? '',
      createdByNameSnapshot: json['createdByNameSnapshot'] as String? ?? '',
      originalInputs: _toStringDynamicMap(json['originalInputs']),
      validationReferenceVersion:
          json['validationReferenceVersion'] as String? ?? '',
      fuelConsumption: _toDoubleOrNull(
        json['bunkerIntervalConsumption'] ?? json['fuelConsumption'],
      ),
      waterConsumption: _toDoubleOrNull(
        json['waterIntervalConsumption'] ?? json['waterConsumption'],
      ),
      steamConsumption: _toDoubleOrNull(
        json['steamIntervalConsumption'] ?? json['steamConsumption'],
      ),
    );
  }
}

class BoilerConsumptionCalculator {
  const BoilerConsumptionCalculator._();

  static BoilerReading attachDeltas(
    BoilerReading reading,
    List<BoilerReading> existingReadings,
  ) {
    if (reading.readingMode == 'interval_consumption') {
      return reading.copyWith(
        fuelConsumption: reading.fuelTotal,
        waterConsumption: reading.waterTotal,
        steamConsumption: reading.steamTotal,
      );
    }

    final previous = _previousReading(reading, existingReadings);
    final warnings = [...reading.validationWarnings];
    final fuel = _delta(reading.fuelTotal, previous?.fuelTotal);
    final water = _delta(reading.waterTotal, previous?.waterTotal);
    final steam = _delta(reading.steamTotal, previous?.steamTotal);
    if (previous != null) {
      if (fuel == null) warnings.add('bunker_meter_reset_or_negative_delta');
      if (water == null) warnings.add('water_meter_reset_or_negative_delta');
      if (reading.steamTotal != null && steam == null) {
        warnings.add('steam_meter_reset_or_negative_delta');
      }
      _addHistoricalRangeWarnings(
        reading: reading,
        previous: previous,
        fuelDelta: fuel,
        waterDelta: water,
        warnings: warnings,
      );
    }
    return reading.copyWith(
      fuelConsumption: fuel,
      waterConsumption: water,
      steamConsumption: steam,
      validationWarnings: warnings,
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
              item.effectiveBoilerId == reading.effectiveBoilerId &&
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

  static void _addHistoricalRangeWarnings({
    required BoilerReading reading,
    required BoilerReading previous,
    required double? fuelDelta,
    required double? waterDelta,
    required List<String> warnings,
  }) {
    final limits = boilerSafetyLimits[reading.effectiveBoilerId];
    if (limits == null) return;
    final elapsedHours =
        reading.recordedAt.difference(previous.recordedAt).inMilliseconds /
        Duration.millisecondsPerHour;
    if (elapsedHours <= 0) return;
    if (fuelDelta != null &&
        fuelDelta / elapsedHours > limits.bunkerGallonsPerHour) {
      warnings.add('bunker_delta_above_historical_range');
    }
    if (waterDelta != null &&
        waterDelta / elapsedHours > limits.waterGallonsPerHour) {
      warnings.add('water_delta_above_historical_range');
    }
  }
}

DateTime guayaquilHourStart(DateTime nowUtc) {
  final local = nowUtc.toUtc().subtract(const Duration(hours: 5));
  final localHour = DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
  );
  return localHour.add(const Duration(hours: 5));
}

String deterministicBoilerReadingId(String boilerId, DateTime intervalStart) {
  final utc = intervalStart.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${boilerId}_${utc.year}${two(utc.month)}${two(utc.day)}${two(utc.hour)}';
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

int? _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic> _toStringDynamicMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), item));
}

DateTime? _toDateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  try {
    final dynamic candidate = value;
    final converted = candidate.toDate();
    return converted is DateTime ? converted : null;
  } catch (_) {
    return null;
  }
}
