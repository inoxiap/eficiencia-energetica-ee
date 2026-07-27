import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/boiler_consumption.dart';
import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';

class _OdometerConsumptionStore implements ConsumptionStore {
  @override
  Future<List<BoilerReading>> loadReadings() async {
    final now = DateTime.utc(2026, 7, 27, 15);
    return [
      BoilerReading(
        id: 'alfa-latest',
        recordedAt: now,
        createdAt: now,
        boilerName: boilerNames.first,
        boilerId: boilerDefinitions.first.id,
        fuelTotal: 123456,
        waterTotal: 500,
        steamTotal: 250,
        fuelConsumption: null,
        waterConsumption: null,
        steamConsumption: null,
      ),
    ];
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {}
}

void main() {
  testWidgets('shows industrial instruments and updates the reading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InputControlsPlaygroundScreen(
          consumptionStore: _OdometerConsumptionStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Banco de instrumentos'), findsOneWidget);
    expect(find.text('Manometro analogico'), findsOneWidget);
    expect(find.text('Encoder rotativo'), findsOneWidget);
    expect(find.text('Dial circular'), findsOneWidget);
    expect(find.text('Transmisor lineal'), findsOneWidget);
    expect(find.text('Odometro digital de 10 digitos'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('industrial-fine-increment')),
    );
    await tester.tap(find.byKey(const Key('industrial-fine-increment')));
    await tester.pump();

    expect(find.text('1.251  gal'), findsWidgets);

    await tester.ensureVisible(find.byKey(const Key('odometer-current-value')));
    expect(find.text('0000123456 gal'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('odometer-digit-9')),
      const Offset(0, -55),
    );
    await tester.pumpAndSettle();

    expect(find.text('0000123456 gal'), findsNothing);
  });
}
