import 'trap_sizing.dart';

const trapSizingSchemaVersion = 1;
const trapSizingFormulaVersion = 'trap-sizing-v1';

class TrapReportInput {
  const TrapReportInput({
    required this.value,
    required this.unit,
    required this.labelSnapshot,
  });

  final double value;
  final String unit;
  final String labelSnapshot;

  Map<String, dynamic> toMap() => {
    'value': value,
    'unit': unit,
    'labelSnapshot': labelSnapshot,
  };
}

class TrapSizingReportResult {
  const TrapSizingReportResult({
    required this.condensateLoadKgH,
    required this.condensateEquivalentLH,
    required this.requiredCapacityKgH,
    required this.recommendedTrapType,
    required this.recommendedConnectionDiameter,
    required this.explanation,
  });

  final double condensateLoadKgH;
  final double condensateEquivalentLH;
  final double requiredCapacityKgH;
  final String recommendedTrapType;
  final String recommendedConnectionDiameter;
  final String explanation;

  Map<String, dynamic> toMap() => {
    'condensateLoadKgH': condensateLoadKgH,
    'condensateEquivalentLH': condensateEquivalentLH,
    'requiredCapacityKgH': requiredCapacityKgH,
    'recommendedTrapType': recommendedTrapType,
    'recommendedConnectionDiameter': recommendedConnectionDiameter,
    'explanation': explanation,
  };
}

class TrapSizingReportDraft {
  const TrapSizingReportDraft({
    required this.id,
    required this.sectionId,
    required this.sectionNameSnapshot,
    required this.equipmentName,
    required this.equipmentNameNormalized,
    required this.notes,
    required this.applicationTypeId,
    required this.applicationTypeNameSnapshot,
    required this.calculationMethod,
    required this.inputs,
    required this.result,
    required this.safetyFactor,
    required this.assumptions,
  });

  final String id;
  final String sectionId;
  final String sectionNameSnapshot;
  final String equipmentName;
  final String equipmentNameNormalized;
  final String notes;
  final String applicationTypeId;
  final String applicationTypeNameSnapshot;
  final String calculationMethod;
  final Map<String, TrapReportInput> inputs;
  final TrapSizingReportResult result;
  final double safetyFactor;
  final Map<String, Object> assumptions;

  Map<String, dynamic> structuredInputs() => {
    'values': inputs.map((key, value) => MapEntry(key, value.toMap())),
    'directCondensateLMin': inputs['directCondensate']?.value,
  };

  static Map<String, Object> currentAssumptions() => {
    'condensateDensityKgL': TrapConstants.condensateDensityKgL,
    'palmOilDensityKgL': TrapConstants.palmOilDensityKgL,
    'palmOilSpecificHeatKjKgC': TrapConstants.palmOilSpecificHeatKjKgC,
    'ambientTemperatureC': TrapConstants.ambientTemperatureC,
    'boilerHeaderCondensatePercent':
        TrapConstants.boilerHeaderCondensatePercent,
    'secondaryDistributorDrainagePercent':
        TrapConstants.secondaryDistributorDrainagePercent,
    'distributorDesignVelocityMS': TrapConstants.distributorDesignVelocityMS,
    'sourceVersion': trapSizingFormulaVersion,
  };
}
