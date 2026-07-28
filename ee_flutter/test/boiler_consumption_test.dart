import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eficiencia_energetica_ee/domain/boiler_consumption.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';

class _MemoryConsumptionStore implements ConsumptionStore {
  _MemoryConsumptionStore([Iterable<BoilerReading> initial = const []])
    : readings = initial.toList();

  final List<BoilerReading> readings;
  final List<BoilerReading> saved = [];

  @override
  Future<List<BoilerReading>> loadReadings() async => List.of(readings);

  @override
  Future<void> saveReading(BoilerReading reading) async {
    saved.add(reading);
    readings.removeWhere((item) => item.id == reading.id);
    readings.add(reading);
  }
}

void main() {
  final boiler = boilerDefinitions.first;

  BoilerReading reading({
    required String id,
    required DateTime recordedAt,
    required double bunker,
    required double water,
    double? steam,
    String mode = 'cumulative_meter',
  }) {
    final intervalStart = guayaquilHourStart(recordedAt.toUtc());
    return BoilerReading(
      id: id,
      recordedAt: recordedAt,
      createdAt: recordedAt,
      boilerName: boiler.displayName,
      boilerId: boiler.id,
      readingMode: mode,
      fuelTotal: bunker,
      waterTotal: water,
      steamTotal: steam,
      boilerPressurePsi: 155,
      intervalStart: intervalStart,
      intervalEnd: intervalStart.add(const Duration(hours: 1)),
      fuelConsumption: null,
      waterConsumption: null,
      steamConsumption: null,
    );
  }

  test('cumulative readings calculate positive deltas only', () {
    final previous = reading(
      id: 'previous',
      recordedAt: DateTime.utc(2026, 7, 11, 14),
      bunker: 100,
      water: 200,
      steam: 300,
    );
    final current = reading(
      id: 'current',
      recordedAt: DateTime.utc(2026, 7, 11, 15),
      bunker: 112,
      water: 225,
      steam: 340,
    );

    final result = BoilerConsumptionCalculator.attachDeltas(current, [
      previous,
    ]);

    expect(result.fuelConsumption, 12);
    expect(result.waterConsumption, 25);
    expect(result.steamConsumption, 40);
    expect(result.validationWarnings, isEmpty);
  });

  test('Alfa Laval inputs preserve the plant conversion factors', () {
    expect(alfaBunkerGallonsFromLiters(3790), closeTo(1000, 0.0001));
    expect(alfaWaterGallonsFromCounter(100), closeTo(264, 0.0001));
    expect(alfaWaterLitersFromCounter(100), closeTo(1000, 0.0001));
  });

  test('historical safety limits flag only extraordinary hourly jumps', () {
    final previous = reading(
      id: 'previous-safe',
      recordedAt: DateTime.utc(2026, 7, 11, 14),
      bunker: 1000,
      water: 10000,
    );
    final current = reading(
      id: 'current-warning',
      recordedAt: DateTime.utc(2026, 7, 11, 15),
      bunker: 1381,
      water: 16601,
    );

    final result = BoilerConsumptionCalculator.attachDeltas(current, [
      previous,
    ]);

    expect(
      result.validationWarnings,
      contains('bunker_delta_above_historical_range'),
    );
    expect(
      result.validationWarnings,
      contains('water_delta_above_historical_range'),
    );
  });

  test('meter reset never creates a negative consumption', () {
    final previous = reading(
      id: 'previous',
      recordedAt: DateTime.utc(2026, 7, 11, 14),
      bunker: 100,
      water: 200,
    );
    final current = reading(
      id: 'current',
      recordedAt: DateTime.utc(2026, 7, 11, 15),
      bunker: 5,
      water: 10,
    );

    final result = BoilerConsumptionCalculator.attachDeltas(current, [
      previous,
    ]);

    expect(result.fuelConsumption, isNull);
    expect(result.waterConsumption, isNull);
    expect(
      result.validationWarnings,
      contains('bunker_meter_reset_or_negative_delta'),
    );
    expect(
      result.validationWarnings,
      contains('water_meter_reset_or_negative_delta'),
    );
  });

  test('interval consumption is not differenced', () {
    final current = reading(
      id: 'interval',
      recordedAt: DateTime.utc(2026, 7, 11, 15),
      bunker: 12,
      water: 25,
      steam: 40,
      mode: 'interval_consumption',
    );

    final result = BoilerConsumptionCalculator.attachDeltas(current, const []);

    expect(result.fuelConsumption, 12);
    expect(result.waterConsumption, 25);
    expect(result.steamConsumption, 40);
  });

  test('Guayaquil hour and deterministic ID are stable', () {
    final hour = guayaquilHourStart(DateTime.utc(2026, 7, 11, 18, 59));

    expect(hour, DateTime.utc(2026, 7, 11, 18));
    expect(
      deterministicBoilerReadingId('alfa_laval_1200', hour),
      'alfa_laval_1200_2026071118',
    );
  });

  test('new records omit PIN while historical PIN stays readable', () {
    final current = reading(
      id: 'new',
      recordedAt: DateTime.utc(2026, 7, 11, 15),
      bunker: 1,
      water: 2,
    );
    final historical = BoilerReading.fromJson({
      'id': 'old',
      'recordedAt': '2026-05-30T10:00:00-05:00',
      'createdAt': '2026-05-30T10:00:00-05:00',
      'boilerName': alfaLavalBoiler,
      'fuelTotal': 1,
      'waterTotal': 2,
      'operatorPin': '1234',
    });

    expect(current.toJson().containsKey('operatorPin'), isFalse);
    expect(current.toJson()['boilerPressurePsi'], 155);
    expect(current.toJson()['boilerPressureUnit'], 'psi');
    expect(current.toJson()['schemaVersion'], 2);
    expect(historical.operatorPin, '1234');
    expect(historical.boilerPressurePsi, isNull);
    expect(historical.effectiveBoilerId, 'alfa_laval_1200');
    expect(historical.bunkerUnit, 'gal');
    expect(historical.waterUnit, 'gal');
    expect(historical.toJson()['schemaVersion'], 1);
  });

  test('schema 3 preserves original readings and conversion metadata', () {
    final current = BoilerReading(
      id: 'converted',
      recordedAt: DateTime.utc(2026, 7, 27, 12),
      createdAt: DateTime.utc(2026, 7, 27, 12),
      boilerName: alfaLavalBoiler,
      boilerId: boiler.id,
      fuelTotal: alfaBunkerGallonsFromLiters(3790),
      waterTotal: alfaWaterGallonsFromCounter(100),
      steamTotal: 500,
      boilerPressurePsi: 151,
      originalInputs: const {
        'bunker': {'value': 3790, 'unit': 'L'},
        'water': {'value': 100, 'unit': 'counter_x10_L'},
      },
      validationReferenceVersion: boilerSafetyReferenceVersion,
      fuelConsumption: null,
      waterConsumption: null,
      steamConsumption: null,
    );

    final json = current.toJson();
    final restored = BoilerReading.fromJson(json);

    expect(json['schemaVersion'], boilerConsumptionSchemaVersion);
    expect(restored.originalInputs['bunker']['value'], 3790);
    expect(restored.originalInputs['water']['unit'], 'counter_x10_L');
    expect(restored.validationReferenceVersion, boilerSafetyReferenceVersion);
  });

  test('current configuration preserves steam behavior for compatibility', () {
    expect(boilerByName(alfaLavalBoiler)?.readsSteam, isTrue);
    expect(boilerByName(alfaLavalBoiler)?.steamUnit, 'kg');
    expect(
      boilerById('cleaver_brooks_1200')?.readsSteam,
      isFalse,
      reason: 'Pending plant confirmation; do not change silently.',
    );
  });

  test('historical Alfa steam readings are interpreted as kilograms', () {
    final historical = BoilerReading.fromJson({
      'id': 'alfa-steam-legacy',
      'boilerId': 'alfa_laval_1200',
      'boilerName': alfaLavalBoiler,
      'recordedAt': '2026-07-27T17:00:00-05:00',
      'createdAt': '2026-07-27T17:00:00-05:00',
      'bunkerValue': 100,
      'waterValue': 200,
      'steamValue': 300,
      'bunkerUnit': 'gal',
      'waterUnit': 'gal',
      'steamUnit': 'gal',
    });

    expect(historical.steamTotal, 300);
    expect(historical.steamUnit, 'kg');
  });

  test('local legacy PIN is removed during the first read', () async {
    SharedPreferences.setMockInitialValues({
      'eeBoilerConsumptionReadings': jsonEncode([
        {
          'id': 'legacy',
          'recordedAt': '2026-05-30T10:00:00-05:00',
          'createdAt': '2026-05-30T10:00:00-05:00',
          'boilerName': alfaLavalBoiler,
          'fuelTotal': 1,
          'waterTotal': 2,
          'operatorPin': '1234',
        },
      ]),
    });

    final readings = await LocalConsumptionStore().loadReadings();
    final preferences = await SharedPreferences.getInstance();
    final persisted = preferences.getString('eeBoilerConsumptionReadings')!;

    expect(readings.single.operatorPin, isEmpty);
    expect(persisted, isNot(contains('operatorPin')));
    expect(persisted, isNot(contains('1234')));
  });

  test('hybrid store retries pending readings and marks them synced', () async {
    final pending = reading(
      id: 'pending',
      recordedAt: DateTime.utc(2026, 7, 24, 22),
      bunker: 120,
      water: 240,
    ).copyWith(status: 'pending_sync');
    final local = _MemoryConsumptionStore([pending]);
    final remote = _MemoryConsumptionStore();
    final store = HybridConsumptionStore(
      localStore: local,
      remoteStore: remote,
    );

    final loaded = await store.loadReadings();

    expect(remote.saved.single.id, pending.id);
    expect(local.readings.single.status, 'synced');
    expect(loaded.single.status, 'synced');
  });
}
