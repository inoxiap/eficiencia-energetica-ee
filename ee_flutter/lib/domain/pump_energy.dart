import 'dart:math' as math;

const pumpSurveySchemaVersion = 1;
const pumpFormulaVersion = 'pump-energy-v1';
const standardMotorHp = <double>[
  0.25,
  0.33,
  0.5,
  0.75,
  1,
  1.5,
  2,
  3,
  5,
  7.5,
  10,
  15,
  20,
  25,
  30,
  40,
  50,
  60,
  75,
  100,
];

class MotorReferenceValue {
  const MotorReferenceValue({required this.value, required this.source});

  final double value;
  final String source;
}

class MotorReferenceDefaults {
  const MotorReferenceDefaults._();

  static MotorReferenceValue efficiency(double hp) {
    if (hp <= 1) {
      return const MotorReferenceValue(
        value: 0.72,
        source: 'internal_table_v1_hp_le_1_default_4_pole',
      );
    }
    if (hp <= 5) {
      return const MotorReferenceValue(
        value: 0.82,
        source: 'internal_table_v1_hp_1_5_default_4_pole',
      );
    }
    if (hp <= 20) {
      return const MotorReferenceValue(
        value: 0.88,
        source: 'internal_table_v1_hp_5_20_default_4_pole',
      );
    }
    if (hp <= 50) {
      return const MotorReferenceValue(
        value: 0.92,
        source: 'internal_table_v1_hp_20_50_default_4_pole',
      );
    }
    return const MotorReferenceValue(
      value: 0.94,
      source: 'internal_table_v1_hp_gt_50_default_4_pole',
    );
  }

  static MotorReferenceValue powerFactor(double hp) {
    if (hp <= 1) {
      return const MotorReferenceValue(
        value: 0.72,
        source: 'internal_table_v1_pf_hp_le_1',
      );
    }
    if (hp <= 5) {
      return const MotorReferenceValue(
        value: 0.78,
        source: 'internal_table_v1_pf_hp_1_5',
      );
    }
    if (hp <= 20) {
      return const MotorReferenceValue(
        value: 0.84,
        source: 'internal_table_v1_pf_hp_5_20',
      );
    }
    if (hp <= 50) {
      return const MotorReferenceValue(
        value: 0.87,
        source: 'internal_table_v1_pf_hp_20_50',
      );
    }
    return const MotorReferenceValue(
      value: 0.90,
      source: 'internal_table_v1_pf_hp_gt_50',
    );
  }
}

class PumpEnergyInput {
  const PumpEnergyInput({
    required this.nominalPowerHp,
    required this.phaseCount,
    required this.measuredVoltagesV,
    required this.measuredCurrentsA,
    this.measuredPowerFactor,
    this.measuredActivePowerKw,
    this.nameplateEfficiency,
    this.hoursPerDay,
    this.daysPerYear,
    this.assumedLoadFactor = 0.75,
    this.powerFactorReference,
    this.efficiencyReference,
  });

  final double nominalPowerHp;
  final int phaseCount;
  final List<double> measuredVoltagesV;
  final List<double> measuredCurrentsA;
  final double? measuredPowerFactor;
  final double? measuredActivePowerKw;
  final double? nameplateEfficiency;
  final double? hoursPerDay;
  final double? daysPerYear;
  final double assumedLoadFactor;
  final MotorReferenceValue? powerFactorReference;
  final MotorReferenceValue? efficiencyReference;
}

class PumpEnergyResult {
  const PumpEnergyResult({
    required this.inputPowerKw,
    required this.measuredInputPowerKw,
    required this.estimatedInputPowerKw,
    required this.shaftPowerKw,
    required this.dailyEnergyKwh,
    required this.annualEnergyKwh,
    required this.estimatedLoadFactor,
    required this.voltageUnbalancePercent,
    required this.currentUnbalancePercent,
    required this.confidenceLevel,
    required this.powerSource,
    required this.powerFactorUsed,
    required this.powerFactorSource,
    required this.efficiencyUsed,
    required this.efficiencySource,
    required this.candidateForHydraulicReview,
    required this.warnings,
  });

  final double inputPowerKw;
  final double? measuredInputPowerKw;
  final double? estimatedInputPowerKw;
  final double? shaftPowerKw;
  final double? dailyEnergyKwh;
  final double? annualEnergyKwh;
  final double? estimatedLoadFactor;
  final double? voltageUnbalancePercent;
  final double? currentUnbalancePercent;
  final String confidenceLevel;
  final String powerSource;
  final double? powerFactorUsed;
  final String powerFactorSource;
  final double? efficiencyUsed;
  final String efficiencySource;
  final bool candidateForHydraulicReview;
  final List<String> warnings;

  Map<String, dynamic> toMap() => {
    'inputPowerKw': inputPowerKw,
    'measuredInputPowerKw': measuredInputPowerKw,
    'estimatedInputPowerKw': estimatedInputPowerKw,
    'estimatedShaftPowerKw': shaftPowerKw,
    'dailyEnergyKwh': dailyEnergyKwh,
    'annualEnergyKwh': annualEnergyKwh,
    'estimatedLoadFactor': estimatedLoadFactor,
    'voltageUnbalancePercent': voltageUnbalancePercent,
    'currentUnbalancePercent': currentUnbalancePercent,
    'confidenceLevel': confidenceLevel,
    'powerSource': powerSource,
    'powerFactorUsed': powerFactorUsed,
    'powerFactorSource': powerFactorSource,
    'efficiencyUsed': efficiencyUsed,
    'efficiencySource': efficiencySource,
    'candidateForHydraulicReview': candidateForHydraulicReview,
    'warnings': warnings,
  };
}

class PumpEnergyCalculator {
  const PumpEnergyCalculator._();

  static PumpEnergyResult calculate(PumpEnergyInput input) {
    if (input.nominalPowerHp <= 0) {
      throw ArgumentError('La potencia nominal HP debe ser mayor a cero.');
    }
    if (input.phaseCount != 1 && input.phaseCount != 3) {
      throw ArgumentError('El numero de fases debe ser 1 o 3.');
    }

    final warnings = <String>[];
    final efficiencyReference =
        input.efficiencyReference ??
        MotorReferenceDefaults.efficiency(input.nominalPowerHp);
    final efficiency = input.nameplateEfficiency ?? efficiencyReference.value;
    final efficiencySource = input.nameplateEfficiency != null
        ? 'nameplate'
        : efficiencyReference.source;

    double inputPowerKw;
    double? measuredInputPowerKw;
    double? estimatedInputPowerKw;
    double? powerFactorUsed;
    String powerFactorSource;
    String powerSource;
    String confidence;

    if (input.measuredActivePowerKw != null &&
        input.measuredActivePowerKw! > 0) {
      inputPowerKw = input.measuredActivePowerKw!;
      measuredInputPowerKw = inputPowerKw;
      powerSource = 'measured_active_power_kw';
      powerFactorUsed = input.measuredPowerFactor;
      powerFactorSource = input.measuredPowerFactor == null
          ? 'not_required_for_measured_kw'
          : 'measured';
      confidence = 'high';
    } else {
      final voltage = _averagePositive(input.measuredVoltagesV);
      final current = _averagePositive(input.measuredCurrentsA);
      if (voltage != null && current != null) {
        final powerFactorReference =
            input.powerFactorReference ??
            MotorReferenceDefaults.powerFactor(input.nominalPowerHp);
        powerFactorUsed =
            input.measuredPowerFactor ?? powerFactorReference.value;
        powerFactorSource = input.measuredPowerFactor != null
            ? 'measured'
            : powerFactorReference.source;
        inputPowerKw = input.phaseCount == 3
            ? math.sqrt(3) * voltage * current * powerFactorUsed / 1000
            : voltage * current * powerFactorUsed / 1000;
        estimatedInputPowerKw = inputPowerKw;
        powerSource = input.phaseCount == 3
            ? 'three_phase_voltage_current_pf'
            : 'single_phase_voltage_current_pf';
        confidence = input.measuredPowerFactor == null ? 'low' : 'medium';
        if (input.measuredPowerFactor == null) {
          warnings.add('power_factor_assumed');
        }
        if (input.phaseCount == 3 && input.measuredVoltagesV.length < 3) {
          warnings.add('average_voltage_only_lower_confidence');
        }
        if (input.phaseCount == 3 && input.measuredCurrentsA.length < 3) {
          warnings.add('average_current_only_lower_confidence');
        }
      } else {
        inputPowerKw =
            input.nominalPowerHp * 0.746 * input.assumedLoadFactor / efficiency;
        estimatedInputPowerKw = inputPowerKw;
        powerSource = 'nominal_hp_load_factor_efficiency';
        powerFactorUsed = null;
        powerFactorSource = 'not_used_for_hp_estimate';
        confidence = 'low';
        warnings.add('electrical_measurements_missing');
        warnings.add('load_factor_assumed');
      }
    }

    final shaftPowerKw = inputPowerKw * efficiency;
    final nominalShaftKw = input.nominalPowerHp * 0.746;
    final estimatedLoadFactor = nominalShaftKw <= 0
        ? null
        : shaftPowerKw / nominalShaftKw;
    final voltageUnbalance = input.phaseCount == 3
        ? _unbalance(input.measuredVoltagesV)
        : null;
    final currentUnbalance = input.phaseCount == 3
        ? _unbalance(input.measuredCurrentsA)
        : null;
    if (voltageUnbalance != null) warnings.add('voltage_unbalance_calculated');
    if (currentUnbalance != null) warnings.add('current_unbalance_calculated');
    if (estimatedLoadFactor != null && estimatedLoadFactor > 1.05) {
      warnings.add('estimated_load_above_nameplate');
    }

    final dailyEnergy = input.hoursPerDay != null && input.hoursPerDay! > 0
        ? inputPowerKw * input.hoursPerDay!
        : null;
    final annualEnergy =
        dailyEnergy != null &&
            input.daysPerYear != null &&
            input.daysPerYear! > 0
        ? dailyEnergy * input.daysPerYear!
        : null;
    final candidate = estimatedLoadFactor != null && estimatedLoadFactor < 0.50;
    if (candidate) {
      warnings.add('candidate_for_hydraulic_review_not_diagnosis');
    }

    return PumpEnergyResult(
      inputPowerKw: inputPowerKw,
      measuredInputPowerKw: measuredInputPowerKw,
      estimatedInputPowerKw: estimatedInputPowerKw,
      shaftPowerKw: shaftPowerKw,
      dailyEnergyKwh: dailyEnergy,
      annualEnergyKwh: annualEnergy,
      estimatedLoadFactor: estimatedLoadFactor,
      voltageUnbalancePercent: voltageUnbalance,
      currentUnbalancePercent: currentUnbalance,
      confidenceLevel: confidence,
      powerSource: powerSource,
      powerFactorUsed: powerFactorUsed,
      powerFactorSource: powerFactorSource,
      efficiencyUsed: efficiency,
      efficiencySource: efficiencySource,
      candidateForHydraulicReview: candidate,
      warnings: warnings,
    );
  }

  static double? _averagePositive(List<double> values) {
    final valid = values.where((value) => value > 0).toList();
    if (valid.isEmpty) return null;
    return valid.reduce((left, right) => left + right) / valid.length;
  }

  static double? _unbalance(List<double> values) {
    if (values.length < 3) return null;
    final valid = values.take(3).where((value) => value > 0).toList();
    if (valid.length < 3) return null;
    final average = valid.reduce((left, right) => left + right) / valid.length;
    if (average == 0) return null;
    final maximumDeviation = valid
        .map((value) => (value - average).abs())
        .reduce(math.max);
    return maximumDeviation / average * 100;
  }
}

class PumpBaselineOption {
  const PumpBaselineOption({
    required this.surveyId,
    required this.sectionId,
    required this.sectionName,
    required this.equipmentName,
    required this.equipmentNameNormalized,
    required this.assetId,
    required this.pumpTag,
    required this.serviceDescription,
    required this.nominalPowerHp,
  });

  final String surveyId;
  final String sectionId;
  final String sectionName;
  final String equipmentName;
  final String equipmentNameNormalized;
  final String assetId;
  final String pumpTag;
  final String serviceDescription;
  final double nominalPowerHp;
}

class PumpSurveyDraft {
  const PumpSurveyDraft({
    required this.id,
    required this.sectionId,
    required this.sectionNameSnapshot,
    required this.equipmentName,
    required this.equipmentNameNormalized,
    required this.assetId,
    required this.pumpTag,
    required this.serviceDescription,
    required this.surveyType,
    required this.interventionId,
    required this.baselineSurveyId,
    required this.nominalPowerHp,
    required this.identification,
    required this.electricalInputs,
    required this.operatingInputs,
    required this.result,
    required this.assumptions,
    required this.notes,
  });

  final String id;
  final String sectionId;
  final String sectionNameSnapshot;
  final String equipmentName;
  final String equipmentNameNormalized;
  final String assetId;
  final String pumpTag;
  final String serviceDescription;
  final String surveyType;
  final String? interventionId;
  final String? baselineSurveyId;
  final double nominalPowerHp;
  final Map<String, dynamic> identification;
  final Map<String, dynamic> electricalInputs;
  final Map<String, dynamic> operatingInputs;
  final PumpEnergyResult result;
  final Map<String, dynamic> assumptions;
  final String notes;
}
