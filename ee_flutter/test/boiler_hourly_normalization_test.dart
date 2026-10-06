import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/boiler_consumption.dart';
import 'package:eficiencia_energetica_ee/domain/boiler_hourly_normalization.dart';

BoilerReading _reading({
  required String id,
  required DateTime at,
  required double bunker,
  required double water,
  double? steam,
  int revision = 1,
  String? rootRecordId,
  Map<String, dynamic> originalInputs = const {},
  double? pressurePsi,
  String operatorName = '',
}) => BoilerReading(
  id: id,
  recordedAt: at,
  createdAt: at,
  boilerName: alfaLavalBoiler,
  boilerId: 'alfa_laval_1200',
  fuelTotal: bunker,
  waterTotal: water,
  steamTotal: steam,
  fuelConsumption: null,
  waterConsumption: null,
  steamConsumption: null,
  revision: revision,
  rootRecordId: rootRecordId,
  boilerPressurePsi: pressurePsi,
  createdByNameSnapshot: operatorName,
  originalInputs: originalInputs,
);

void main() {
  test('uniformly allocates deltas and combines portions across readings', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '08:00',
        at: DateTime.utc(2026, 10, 5, 13),
        bunker: 84,
        water: 80,
        steam: 160,
      ),
      _reading(
        id: '08:48',
        at: DateTime.utc(2026, 10, 5, 13, 48),
        bunker: 90,
        water: 100,
        steam: 200,
      ),
      _reading(
        id: '09:12',
        at: DateTime.utc(2026, 10, 5, 14, 12),
        bunker: 96,
        water: 124,
        steam: 248,
      ),
      _reading(
        id: '11:34',
        at: DateTime.utc(2026, 10, 5, 16, 34),
        bunker: 133,
        water: 268,
        steam: 536,
      ),
    ]);

    expect(result, hasLength(3));
    expect(result.map((hour) => hour.hourEnd), [
      DateTime.utc(2026, 10, 5, 16),
      DateTime.utc(2026, 10, 5, 15),
      DateTime.utc(2026, 10, 5, 14),
    ]);
    expect(result[0].bunkerGallons, closeTo(37 * 60 / 142, 0.0001));
    expect(result[1].bunkerGallons, closeTo(3 + 37 * 48 / 142, 0.0001));
    expect(result[1].waterGallons, closeTo(12 + 144 * 48 / 142, 0.0001));
    expect(
      result[1].steamKg,
      closeTo((24 + 288 * 48 / 142) * alfaSteamNormalizedMultiplier, 0.0001),
    );
    expect(result[2].bunkerGallons, closeTo(9, 0.0001));
  });

  test('carries pressure and latest operator into normalized hours', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: 'first',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 100,
        water: 20,
        pressurePsi: 110,
        operatorName: 'Ana',
      ),
      _reading(
        id: 'second',
        at: DateTime.utc(2026, 10, 5, 15),
        bunker: 120,
        water: 30,
        pressurePsi: 155,
        operatorName: 'Luis',
      ),
    ]);

    expect(result.single.boilerPressurePsi, 155);
    expect(result.single.operatorName, 'Luis');
  });

  test(
    'includes the hour ending exactly at the latest closed-hour reading',
    () {
      final result = BoilerHourlyNormalizer.normalize([
        _reading(
          id: '09:00',
          at: DateTime.utc(2026, 10, 5, 14),
          bunker: 10,
          water: 20,
        ),
        _reading(
          id: '11:00',
          at: DateTime.utc(2026, 10, 5, 16),
          bunker: 30,
          water: 60,
        ),
      ]);

      expect(result, hasLength(2));
      expect(result.first.hourEnd, DateTime.utc(2026, 10, 5, 16));
      expect(result.first.bunkerGallons, 10);
      expect(result.last.hourEnd, DateTime.utc(2026, 10, 5, 15));
      expect(result.last.waterGallons, 20);
    },
  );

  test('estimates incomplete meter coverage and keeps meter resets blank', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '09:00',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 100,
        water: 20,
      ),
      _reading(
        id: '10:20',
        at: DateTime.utc(2026, 10, 5, 15, 20),
        bunker: 90,
        water: 40,
      ),
      _reading(
        id: '11:10',
        at: DateTime.utc(2026, 10, 5, 16, 10),
        bunker: 95,
        water: 50,
      ),
    ]);

    expect(result, hasLength(2));
    expect(result.first.hourEnd, DateTime.utc(2026, 10, 5, 16));
    expect(result.first.bunkerGallons, 6);
    expect(result.first.waterGallons, 13);
    expect(result.last.hourEnd, DateTime.utc(2026, 10, 5, 15));
    expect(result.last.waterGallons, 15);
  });

  test('bridges a snapshot with missing meter values', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '09:00',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 100,
        water: 200,
        steam: 300,
      ),
      _reading(
        id: '10:00-missing',
        at: DateTime.utc(2026, 10, 5, 15),
        bunker: 110,
        water: 220,
        steam: null,
      ),
      _reading(
        id: '11:00',
        at: DateTime.utc(2026, 10, 5, 16),
        bunker: 120,
        water: 240,
        steam: 340,
      ),
    ]);

    expect(result, hasLength(2));
    for (final hour in result) {
      expect(hour.bunkerGallons, 10);
      expect(hour.waterGallons, 20);
      expect(hour.steamKg, 20000);
    }
  });

  test(
    'normalizes from the visible raw meter values when canonical fields differ',
    () {
      final result = BoilerHourlyNormalizer.normalize([
        _reading(
          id: '09:00',
          at: DateTime.utc(2026, 10, 5, 14),
          bunker: 100,
          water: 10,
          steam: 20,
          originalInputs: {
            'bunker': {'value': 100, 'unit': 'gal', 'gallons': 100000},
            'water': {'value': 10, 'unit': 'L', 'gallons': 2740},
            'steam': {'value': 20, 'unit': 'kg', 'kilograms': 20000},
          },
        ),
        _reading(
          id: '10:00',
          at: DateTime.utc(2026, 10, 5, 15),
          bunker: 110,
          water: 11,
          steam: 30,
          originalInputs: {
            'bunker': {'value': 110, 'unit': 'gal', 'gallons': 110000},
            'water': {'value': 11, 'unit': 'L', 'gallons': 3014},
            'steam': {'value': 30, 'unit': 'kg', 'kilograms': 30000},
          },
        ),
      ]);

      expect(result, hasLength(1));
      expect(result.single.bunkerGallons, 10);
      expect(result.single.waterGallons, closeTo(274, 0.00001));
      expect(result.single.steamKg, 10000);
    },
  );

  test('keeps visible an hour even when it lacks complete meter coverage', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '08:10',
        at: DateTime.utc(2026, 10, 5, 13, 10),
        bunker: 100,
        water: 200,
      ),
      _reading(
        id: '09:40',
        at: DateTime.utc(2026, 10, 5, 16, 40),
        bunker: 110,
        water: 220,
      ),
    ]);

    expect(result, hasLength(3));
    expect(result.map((hour) => hour.hourEnd), [
      DateTime.utc(2026, 10, 5, 16),
      DateTime.utc(2026, 10, 5, 15),
      DateTime.utc(2026, 10, 5, 14),
    ]);
    final hourlyEstimate = 10 * 60 / 210;
    expect(
      result.map((hour) => hour.bunkerGallons),
      everyElement(closeTo(hourlyEstimate, 0.00001)),
    );
    expect(
      result.map((hour) => hour.waterGallons),
      everyElement(closeTo(20 * 60 / 210, 0.00001)),
    );
  });

  test('keeps closed-hour rows visible when all meters reset', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '09:00',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 200,
        water: 300,
        steam: 400,
      ),
      _reading(
        id: '11:00',
        at: DateTime.utc(2026, 10, 5, 16),
        bunker: 100,
        water: 150,
        steam: 200,
      ),
    ]);

    expect(result, hasLength(2));
    expect(result.every((hour) => hour.bunkerGallons == null), isTrue);
    expect(result.every((hour) => hour.waterGallons == null), isTrue);
    expect(result.every((hour) => hour.steamKg == null), isTrue);
  });

  test('fills intermediate hours across the sparse October 5 sample', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '08:06',
        at: DateTime.utc(2026, 10, 5, 13, 6),
        bunker: 246.606,
        water: 22.221,
        steam: 41.287,
      ),
      _reading(
        id: '10:02',
        at: DateTime.utc(2026, 10, 5, 15, 2),
        bunker: 247.094,
        water: 22.252,
        steam: 41.311,
      ),
      _reading(
        id: '11:02',
        at: DateTime.utc(2026, 10, 5, 16, 2),
        bunker: 247.394,
        water: 22.271,
        steam: 41.325,
      ),
      _reading(
        id: '12:01',
        at: DateTime.utc(2026, 10, 5, 17, 1),
        bunker: 247.676,
        water: 22.289,
        steam: 41.339,
      ),
      _reading(
        id: '14:05',
        at: DateTime.utc(2026, 10, 5, 19, 5),
        bunker: 248.225,
        water: 22.324,
        steam: 41.367,
      ),
    ]);

    expect(result, hasLength(6));
    expect(result.map((hour) => hour.hourEnd), [
      DateTime.utc(2026, 10, 5, 19),
      DateTime.utc(2026, 10, 5, 18),
      DateTime.utc(2026, 10, 5, 17),
      DateTime.utc(2026, 10, 5, 16),
      DateTime.utc(2026, 10, 5, 15),
      DateTime.utc(2026, 10, 5, 14),
    ]);
    expect(result.take(5).map((hour) => hour.bunkerGallons), [
      closeTo(0.265645, 0.00001),
      closeTo(0.265997, 0.0001),
      closeTo(0.287220, 0.00001),
      closeTo(0.298414, 0.00001),
      closeTo(0.252414, 0.00001),
    ]);
    expect(result.take(5).map((hour) => hour.waterGallons), [
      closeTo(0.016935, 0.00001),
      closeTo(0.016958, 0.00001),
      closeTo(0.018328, 0.00001),
      closeTo(0.018901, 0.00001),
      closeTo(0.016034, 0.00001),
    ]);
    expect(result.take(5).map((hour) => hour.steamKg), [
      closeTo(13.548, 0.001),
      closeTo(13.560, 0.001),
      closeTo(14.229, 0.001),
      closeTo(13.947, 0.001),
      closeTo(12.414, 0.001),
    ]);
    expect(result.last.bunkerGallons, closeTo(0.252414, 0.00001));
    expect(result.last.waterGallons, closeTo(0.016034, 0.00001));
    expect(result.last.steamKg, closeTo(12.414, 0.001));
  });

  test('normalizes canonical units stored with original meter inputs', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: '09:00',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 1000,
        water: 2000,
        steam: 3000,
        originalInputs: {
          'bunker': {'gallons': 100},
          'water': {'gallons': 40},
          'steam': {'kilograms': 60},
        },
      ),
      _reading(
        id: '11:00',
        at: DateTime.utc(2026, 10, 5, 16),
        bunker: 1500,
        water: 2800,
        steam: 3500,
        originalInputs: {
          'bunker': {'gallons': 120},
          'water': {'gallons': 80},
          'steam': {'kilograms': 100},
        },
      ),
    ]);

    expect(result, hasLength(2));
    for (final hour in result) {
      expect(hour.bunkerGallons, 10);
      expect(hour.waterGallons, 20);
      expect(hour.steamKg, 20000);
    }
  });

  test('uses the highest revision for readings in the same hour', () {
    final result = BoilerHourlyNormalizer.normalize([
      _reading(
        id: 'first',
        at: DateTime.utc(2026, 10, 5, 14),
        bunker: 10,
        water: 10,
      ),
      _reading(
        id: 'rev1',
        at: DateTime.utc(2026, 10, 5, 15),
        bunker: 20,
        water: 20,
        revision: 1,
        rootRecordId: 'revisable-hour',
      ),
      _reading(
        id: 'rev2',
        at: DateTime.utc(2026, 10, 5, 15, 30),
        bunker: 25,
        water: 30,
        revision: 2,
        rootRecordId: 'revisable-hour',
      ),
      _reading(
        id: 'last',
        at: DateTime.utc(2026, 10, 5, 16),
        bunker: 35,
        water: 50,
      ),
    ]);

    expect(result, hasLength(2));
    expect(result.first.bunkerGallons, 15);
    expect(result.last.bunkerGallons, 10);
  });
}
