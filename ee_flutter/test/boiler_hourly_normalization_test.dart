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
    expect(result[1].steamKg, closeTo(24 + 288 * 48 / 142, 0.0001));
    expect(result[2].bunkerGallons, closeTo(9, 0.0001));
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

  test('does not expose an incomplete latest hour or hide a meter reset', () {
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
    expect(result.first.bunkerGallons, isNull);
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
      expect(hour.steamKg, 20);
    }
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

    expect(result, hasLength(5));
    expect(result.map((hour) => hour.hourEnd), [
      DateTime.utc(2026, 10, 5, 19),
      DateTime.utc(2026, 10, 5, 18),
      DateTime.utc(2026, 10, 5, 17),
      DateTime.utc(2026, 10, 5, 16),
      DateTime.utc(2026, 10, 5, 15),
    ]);
    expect(result.map((hour) => hour.bunkerGallons), [
      closeTo(0.265645, 0.00001),
      closeTo(0.265997, 0.0001),
      closeTo(0.287220, 0.00001),
      closeTo(0.298414, 0.00001),
      closeTo(0.252414, 0.00001),
    ]);
    expect(result.map((hour) => hour.waterGallons), [
      closeTo(0.016935, 0.00001),
      closeTo(0.016958, 0.00001),
      closeTo(0.018328, 0.00001),
      closeTo(0.018901, 0.00001),
      closeTo(0.016034, 0.00001),
    ]);
    expect(result.map((hour) => hour.steamKg), [
      closeTo(0.013548, 0.00001),
      closeTo(0.013560, 0.00001),
      closeTo(0.014229, 0.00001),
      closeTo(0.013947, 0.00001),
      closeTo(0.012414, 0.00001),
    ]);
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
      expect(hour.steamKg, 20);
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
