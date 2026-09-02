import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/boiler_consumption.dart';
import 'package:eficiencia_energetica_ee/domain/steam_pressure_reading.dart';
import 'package:eficiencia_energetica_ee/main.dart';
import 'package:eficiencia_energetica_ee/services/consumption_store.dart';
import 'package:eficiencia_energetica_ee/services/operator_session.dart';
import 'package:eficiencia_energetica_ee/services/pressure_reading_store.dart';

class _TestOperatorSession implements OperatorSession {
  @override
  Future<AuthenticatedOperator?> currentOperator() async {
    return const AuthenticatedOperator(
      uid: 'operator-1',
      displayName: 'Operador de prueba',
      role: 'operator',
    );
  }
}

class _RecordingPressureStore implements PressureReadingStore {
  SteamPressureReading? savedReading;

  @override
  Future<void> saveReading(SteamPressureReading reading) async {
    savedReading = reading;
  }
}

class _PreviousConsumptionStore implements ConsumptionStore {
  BoilerReading? savedReading;

  @override
  Future<List<BoilerReading>> loadReadings() async {
    final now = DateTime.utc(2026, 7, 26, 12);
    return [
      BoilerReading(
        id: 'alfa-previous',
        recordedAt: now,
        createdAt: now,
        boilerName: alfaLavalBoiler,
        boilerId: boilerDefinitions.first.id,
        fuelTotal: 1000,
        waterTotal: 2112,
        steamTotal: 3000,
        boilerPressurePsi: 151,
        originalInputs: const {
          'bunker': {'value': 3790, 'unit': 'L'},
          'water': {'value': 800, 'unit': 'counter_x10_L'},
        },
        fuelConsumption: null,
        waterConsumption: null,
        steamConsumption: null,
      ),
      BoilerReading(
        id: 'cleaver-previous',
        recordedAt: now.subtract(const Duration(minutes: 10)),
        createdAt: now.subtract(const Duration(minutes: 10)),
        boilerName: 'Nombre historico Cleaver',
        boilerId: 'cleaver_brooks_1200',
        fuelTotal: 4200,
        waterTotal: 5100,
        steamTotal: null,
        boilerPressurePsi: 116,
        fuelConsumption: null,
        waterConsumption: null,
        steamConsumption: null,
      ),
    ];
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    savedReading = reading;
  }
}

void main() {
  testWidgets('consumption entry exposes consumption and pressure tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pressureStore = _RecordingPressureStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ConsumptionEntryScreen(
          consumptionStore: _PreviousConsumptionStore(),
          pressureReadingStore: pressureStore,
          operatorSession: _TestOperatorSession(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Consumos'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Presiones'), findsOneWidget);
    expect(find.text('Lectura acumulada'), findsOneWidget);
    expect(find.text('Presion'), findsOneWidget);
    expect(find.text('151'), findsOneWidget);
    expect(find.text('Consumo del intervalo'), findsNothing);
    expect(find.text('0000001000 gal'), findsOneWidget);
    expect(find.text('0000000800 x10 L'), findsOneWidget);
    expect(find.text('0000003000 kg'), findsOneWidget);

    final boilerPicker = tester.widget<EmbeddedWheelPicker<String>>(
      find.byType(EmbeddedWheelPicker<String>).first,
    );
    boilerPicker.onSelected('Caldera Cleaver Brooks 1200');
    await tester.pumpAndSettle();
    expect(find.text('0000004200 gal'), findsOneWidget);
    expect(find.text('0000005100 gal'), findsOneWidget);
    expect(find.text('Lectura acumulada de vapor'), findsNothing);

    boilerPicker.onSelected(alfaLavalBoiler);
    await tester.pumpAndSettle();

    await tester.tap(find.text('bar'));
    await tester.pumpAndSettle();
    expect(find.text('10.4'), findsOneWidget);

    await tester.tap(find.text('Presiones'));
    await tester.pumpAndSettle();

    expect(find.text('Presiones distribuidor Cleaver'), findsOneWidget);
    expect(find.text('Presiones distribuidor 900'), findsOneWidget);
    expect(find.text('Presion Omega'), findsOneWidget);
    expect(find.text('Presion Tanque Agua 4'), findsOneWidget);

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(14));
    for (var index = 0; index < 14; index++) {
      await tester.enterText(fields.at(index), '${70 + index}');
    }

    final review = find.text('Revisar presiones');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    expect(find.text('Confirmar presiones'), findsOneWidget);
    expect(find.textContaining('Presion Omega: 70,00 PSI'), findsOneWidget);
    expect(
      find.textContaining('Presion Tanque Agua 4: 83,00 PSI'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();

    expect(pressureStore.savedReading, isNotNull);
    expect(pressureStore.savedReading!.cleaverDistributorPsi['omega'], 70);
    expect(
      pressureStore.savedReading!.distral900DistributorPsi['waterTank4'],
      83,
    );
    expect(find.text('Presiones guardadas correctamente.'), findsOneWidget);
  });

  testWidgets('Alfa review uses direct bunker gallons and converts water', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final consumptionStore = _PreviousConsumptionStore();

    await tester.pumpWidget(
      MaterialApp(
        home: ConsumptionEntryScreen(
          consumptionStore: consumptionStore,
          pressureReadingStore: _RecordingPressureStore(),
          operatorSession: _TestOperatorSession(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final review = find.text('Revisar lectura');
    await tester.ensureVisible(review);
    await tester.tap(review);
    await tester.pumpAndSettle();

    expect(find.textContaining('Bunker: 1.000 (gal)'), findsOneWidget);
    expect(
      find.textContaining('Agua: 8.000,00 L = 2.112,00 gal'),
      findsOneWidget,
    );

    await tester.tap(find.text('Confirmar y guardar'));
    await tester.pumpAndSettle();

    expect(consumptionStore.savedReading, isNotNull);
    expect(consumptionStore.savedReading!.fuelTotal, closeTo(1000, 0.0001));
    expect(consumptionStore.savedReading!.waterTotal, closeTo(2112, 0.0001));
    expect(consumptionStore.savedReading!.steamUnit, 'kg');
    expect(
      consumptionStore.savedReading!.originalInputs['bunker']['unit'],
      'gal',
    );
    expect(
      consumptionStore.savedReading!.originalInputs['water']['unit'],
      'counter_x10_L',
    );
    expect(
      consumptionStore.savedReading!.originalInputs['steam']['unit'],
      'kg',
    );
  });
}
