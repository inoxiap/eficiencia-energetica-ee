import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/boiler_consumption.dart';
import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';

class _HistoryConsumptionStore implements ConsumptionStore {
  @override
  Future<List<BoilerReading>> loadReadings() async {
    return [
      for (var index = 0; index < 18; index++)
        _reading(
          id: 'cleaver-$index',
          boiler: boilerDefinitions[2],
          date: DateTime.utc(2026, 7, 28, 20).subtract(Duration(hours: index)),
          value: (5000 + index).toDouble(),
        ),
      for (var index = 0; index < 2; index++)
        _reading(
          id: 'alfa-$index',
          boiler: boilerDefinitions[0],
          date: DateTime.utc(2026, 7, 28, 20).subtract(Duration(hours: index)),
          value: (1000 + index).toDouble(),
          steam: (3000 + index).toDouble(),
        ),
    ];
  }

  BoilerReading _reading({
    required String id,
    required BoilerDefinition boiler,
    required DateTime date,
    required double value,
    double? steam,
  }) {
    return BoilerReading(
      id: id,
      recordedAt: date,
      createdAt: date,
      boilerName: boiler.displayName,
      boilerId: boiler.id,
      fuelTotal: value,
      waterTotal: value + 100,
      steamTotal: steam,
      bunkerUnit: boiler.bunkerUnit,
      waterUnit: boiler.waterUnit,
      steamUnit: boiler.steamUnit,
      originalInputs: {
        'bunker': {'value': value, 'unit': 'gal'},
        'water': {'value': value + 100, 'unit': 'gal'},
        if (steam != null) 'steam': {'value': steam, 'unit': 'kg'},
      },
      fuelConsumption: null,
      waterConsumption: null,
      steamConsumption: null,
    );
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {}
}

void main() {
  testWidgets('history separates boilers and loads readings 15 at a time', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: BoilerReadingsHistoryScreen(
          consumptionStore: _HistoryConsumptionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registros de consumos'), findsOneWidget);
    expect(find.text('Mostrando 2 de 2.'), findsOneWidget);
    expect(find.textContaining('kg'), findsWidgets);

    await tester.tap(find.text('Cleaver'));
    await tester.pumpAndSettle();

    expect(find.text('Caldera Cleaver Brooks 1200'), findsOneWidget);
    expect(find.text('Mostrando 15 de 18.'), findsOneWidget);
    expect(find.text('5.014 gal'), findsOneWidget);
    expect(find.text('5.015 gal'), findsNothing);
    expect(find.byKey(const Key('load-more-boiler-readings')), findsOneWidget);

    await tester.tap(find.byKey(const Key('load-more-boiler-readings')));
    await tester.pumpAndSettle();

    expect(find.text('Mostrando 18 de 18.'), findsOneWidget);
    expect(find.text('5.017 gal'), findsOneWidget);
    expect(find.byKey(const Key('load-more-boiler-readings')), findsNothing);
  });
}
