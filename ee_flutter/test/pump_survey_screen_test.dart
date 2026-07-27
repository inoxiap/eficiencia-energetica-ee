import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/pump_energy.dart';
import 'package:eficiencia_energetica_ee/screens/pump_survey_screen.dart';
import 'package:eficiencia_energetica_ee/services/cloudinary_service.dart';
import 'package:eficiencia_energetica_ee/services/operator_session.dart';
import 'package:eficiencia_energetica_ee/services/pump_survey_store.dart';

void main() {
  testWidgets('pump survey keeps technical inputs simple', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PumpSurveyScreen(
          store: const DisabledPumpSurveyStore(),
          operatorSession: const DisabledOperatorSession(),
          cloudinaryService: CloudinaryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tipo de levantamiento'), findsOneWidget);
    expect(find.text('Potencia nominal del motor'), findsOneWidget);
    expect(find.text('Selector rapido HP'), findsNothing);
    expect(find.text('Corriente medida'), findsWidgets);
    expect(find.text('2 A'), findsOneWidget);
    expect(find.text('Horas de trabajo diario'), findsOneWidget);
    expect(find.text('Operacion'), findsNothing);
    expect(find.text('Mediciones avanzadas (opcional)'), findsNothing);
    expect(find.text('Tension promedio medida'), findsNothing);

    final voltageExpansion = find.byKey(
      const Key('measured-voltage-expansion'),
    );
    await tester.ensureVisible(voltageExpansion);
    await tester.tap(voltageExpansion);
    await tester.pumpAndSettle();

    expect(find.text('Tension promedio medida'), findsOneWidget);
    expect(find.text('Vab'), findsNothing);
    expect(find.text('Ia'), findsNothing);
  });

  testWidgets('post improvement selects a previously saved baseline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: PumpSurveyScreen(
          store: _BaselinePumpSurveyStore(),
          operatorSession: const DisabledOperatorSession(),
          cloudinaryService: CloudinaryService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final typeWheel = find.byType(ListWheelScrollView).first;
    await tester.drag(typeWheel, const Offset(0, -55));
    await tester.pumpAndSettle();

    expect(find.text('Seccion de la linea base'), findsOneWidget);
    expect(find.text('Equipo al que pertenece la bomba'), findsOneWidget);
    expect(find.text('Bomba registrada'), findsOneWidget);
    expect(find.text('Linea base seleccionada'), findsOneWidget);
    expect(find.text('Equipo: Bomba refinacion'), findsOneWidget);
    expect(find.text('Bomba: P-101'), findsOneWidget);
  });
}

class _BaselinePumpSurveyStore implements PumpSurveyStore {
  @override
  Future<List<PumpBaselineOption>> loadBaselines() async => const [
    PumpBaselineOption(
      surveyId: 'baseline-1',
      sectionId: 'refineria',
      sectionName: 'Refineria',
      equipmentName: 'Bomba refinacion',
      equipmentNameNormalized: 'bomba refinacion',
      assetId: 'refineria_p_101',
      pumpTag: 'P-101',
      serviceDescription: 'Transferencia de aceite',
      nominalPowerHp: 10,
    ),
  ];

  @override
  Future<void> saveSurvey(
    PumpSurveyDraft survey, {
    String? photoUrl,
    String? photoPublicId,
  }) async {}
}
