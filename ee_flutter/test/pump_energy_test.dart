import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/pump_energy.dart';

void main() {
  test('measured active power has highest priority and high confidence', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 20,
        phaseCount: 3,
        measuredVoltagesV: [440, 438, 442],
        measuredCurrentsA: [20, 21, 19],
        measuredPowerFactor: 0.86,
        measuredActivePowerKw: 12.5,
        nameplateEfficiency: 0.91,
        hoursPerDay: 20,
        daysPerYear: 300,
      ),
    );

    expect(result.inputPowerKw, 12.5);
    expect(result.measuredInputPowerKw, 12.5);
    expect(result.estimatedInputPowerKw, isNull);
    expect(result.shaftPowerKw, closeTo(11.375, 0.000001));
    expect(result.dailyEnergyKwh, 250);
    expect(result.annualEnergyKwh, 75000);
    expect(result.confidenceLevel, 'high');
  });

  test('three phase V I and measured PF use sqrt(3)', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 20,
        phaseCount: 3,
        measuredVoltagesV: [440, 440, 440],
        measuredCurrentsA: [20, 20, 20],
        measuredPowerFactor: 0.85,
      ),
    );

    expect(
      result.inputPowerKw,
      closeTo(math.sqrt(3) * 440 * 20 * 0.85 / 1000, 0.000001),
    );
    expect(result.confidenceLevel, 'medium');
    expect(result.powerFactorSource, 'measured');
  });

  test('single phase formula does not apply sqrt(3)', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 3,
        phaseCount: 1,
        measuredVoltagesV: [220],
        measuredCurrentsA: [10],
        measuredPowerFactor: 0.8,
      ),
    );

    expect(result.inputPowerKw, closeTo(1.76, 0.000001));
  });

  test('missing PF is explicit and lowers confidence', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 10,
        phaseCount: 3,
        measuredVoltagesV: [440],
        measuredCurrentsA: [10],
      ),
    );

    expect(result.confidenceLevel, 'low');
    expect(result.powerFactorSource, contains('internal_table'));
    expect(result.warnings, contains('power_factor_assumed'));
    expect(result.warnings, contains('average_current_only_lower_confidence'));
  });

  test('HP fallback applies load factor and efficiency', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 10,
        phaseCount: 3,
        measuredVoltagesV: [],
        measuredCurrentsA: [],
        nameplateEfficiency: 0.90,
        assumedLoadFactor: 0.75,
      ),
    );

    expect(result.inputPowerKw, closeTo(10 * 0.746 * 0.75 / 0.90, 0.000001));
    expect(result.powerSource, 'nominal_hp_load_factor_efficiency');
    expect(result.confidenceLevel, 'low');
  });

  test('phase unbalance is calculated without a diagnosis', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 20,
        phaseCount: 3,
        measuredVoltagesV: [440, 430, 450],
        measuredCurrentsA: [20, 18, 22],
        measuredPowerFactor: 0.85,
      ),
    );

    expect(result.voltageUnbalancePercent, closeTo(2.272727, 0.000001));
    expect(result.currentUnbalancePercent, closeTo(10, 0.000001));
    expect(result.warnings, contains('voltage_unbalance_calculated'));
    expect(result.warnings, contains('current_unbalance_calculated'));
  });

  test('low electrical load only marks hydraulic review candidate', () {
    final result = PumpEnergyCalculator.calculate(
      const PumpEnergyInput(
        nominalPowerHp: 100,
        phaseCount: 3,
        measuredVoltagesV: [],
        measuredCurrentsA: [],
        nameplateEfficiency: 0.94,
        assumedLoadFactor: 0.3,
      ),
    );

    expect(result.candidateForHydraulicReview, isTrue);
    expect(
      result.warnings,
      contains('candidate_for_hydraulic_review_not_diagnosis'),
    );
  });
}
