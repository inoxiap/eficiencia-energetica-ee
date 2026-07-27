import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/trap_sizing.dart';
import 'package:eficiencia_energetica_ee/domain/trap_sizing_report.dart';

void main() {
  group('trap sizing regression', () {
    final expectedByRuleId = <String, double>{
      'tracing': 0,
      'tank_coil': 14.357385987837,
      'kettle_jacket': 9.475874751972,
      'heavy_duty_jacket': 24.326434986333,
      'main_boiler_header': 2280,
      'steam_header': 8,
      'heat_exchanger': 473.793737598606,
      'steam_main_drain_leg': 26.835717403235,
    };

    for (final rule in createTrapRules()) {
      test('${rule.id} keeps its baseline result', () {
        final values = <String, double>{
          for (final field in rule.fields) field.key: field.defaultValue,
        };

        final result = rule.calculate(values);

        expect(
          result.condensateKgH,
          closeTo(expectedByRuleId[rule.id]!, 0.000000001),
        );
      });
    }

    test('direct condensate keeps L/min to kg/h conversion', () {
      final result = calculateDirectCondensate(10);

      expect(result.condensateKgH, 600);
      expect(result.explanation, contains('10.0 L/min'));
    });

    test('safety factor remains 1.2 for every rule', () {
      for (final rule in createTrapRules()) {
        expect(rule.safetyFactor, TrapConstants.defaultSafetyFactor);
        expect(rule.safetyFactor, 1.2);
      }
    });

    test('preliminary connection diameter bands remain stable', () {
      expect(recommendTrapConnectionDiameter(200), contains('1/2'));
      expect(recommendTrapConnectionDiameter(500), contains('3/4'));
      expect(recommendTrapConnectionDiameter(1000), contains('1 pulg'));
      expect(recommendTrapConnectionDiameter(2000), contains('1-1/4'));
      expect(recommendTrapConnectionDiameter(3000), contains('1-1/2'));
      expect(recommendTrapConnectionDiameter(5000), contains('2 pulg'));
      expect(recommendTrapConnectionDiameter(5001), contains('paralelo'));
    });
  });

  test('report draft preserves original values and units', () {
    const input = TrapReportInput(
      value: 7.5,
      unit: 'L/min',
      labelSnapshot: 'Caudal de condensado a desalojar',
    );
    const result = TrapSizingReportResult(
      condensateLoadKgH: 450,
      condensateEquivalentLH: 450,
      requiredCapacityKgH: 540,
      recommendedTrapType: 'Balde invertido',
      recommendedConnectionDiameter: '1 pulg (25 mm)',
      explanation: 'Resultado de prueba',
    );
    final draft = TrapSizingReportDraft(
      id: 'report-1',
      sectionId: 'refineria',
      sectionNameSnapshot: 'Refineria',
      equipmentName: 'Linea 1',
      equipmentNameNormalized: 'linea 1',
      notes: '',
      applicationTypeId: 'steam_main_drain_leg',
      applicationTypeNameSnapshot: 'Linea principal',
      calculationMethod: 'direct',
      inputs: const {'directCondensate': input},
      result: result,
      safetyFactor: 1.2,
      assumptions: TrapSizingReportDraft.currentAssumptions(),
    );

    final structured = draft.structuredInputs();
    final values = structured['values']! as Map<String, dynamic>;
    final direct = values['directCondensate']! as Map<String, dynamic>;

    expect(structured['directCondensateLMin'], 7.5);
    expect(direct['value'], 7.5);
    expect(direct['unit'], 'L/min');
    expect(direct['labelSnapshot'], input.labelSnapshot);
  });
}
