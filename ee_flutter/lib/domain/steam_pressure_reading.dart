const steamPressureSchemaVersion = 1;
const steamPressureUnit = 'psi';

enum PressureDistributorGroup { cleaver, distral900 }

class PressurePointDefinition {
  const PressurePointDefinition({
    required this.id,
    required this.label,
    required this.group,
  });

  final String id;
  final String label;
  final PressureDistributorGroup group;
}

const cleaverDistributorPressurePoints = <PressurePointDefinition>[
  PressurePointDefinition(
    id: 'omega',
    label: 'Presion Omega',
    group: PressureDistributorGroup.cleaver,
  ),
  PressurePointDefinition(
    id: 'lambda',
    label: 'Presion Lambda',
    group: PressureDistributorGroup.cleaver,
  ),
  PressurePointDefinition(
    id: 'omicron',
    label: 'Presion Omicron',
    group: PressureDistributorGroup.cleaver,
  ),
  PressurePointDefinition(
    id: 'beta',
    label: 'Presion Beta',
    group: PressureDistributorGroup.cleaver,
  ),
  PressurePointDefinition(
    id: 'hydrogenation',
    label: 'Presion Hidrogenacion',
    group: PressureDistributorGroup.cleaver,
  ),
];

const distral900DistributorPressurePoints = <PressurePointDefinition>[
  PressurePointDefinition(
    id: 'soapPlant',
    label: 'Presion Jaboneria',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'desmetTirtioux',
    label: 'Presion Desmet y Tirtioux',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'newLine',
    label: 'Presion Linea Nueva',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'cleaverInlet',
    label: 'Presion Ingreso Cleaver',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'bleachers',
    label: 'Presion Blanqueadores',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'marino',
    label: 'Presion Marino',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'padLoading',
    label: 'Presion Pad Loading',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'receptionTanks',
    label: 'Presion Tanques Recepcion',
    group: PressureDistributorGroup.distral900,
  ),
  PressurePointDefinition(
    id: 'waterTank4',
    label: 'Presion Tanque Agua 4',
    group: PressureDistributorGroup.distral900,
  ),
];

const steamPressurePoints = <PressurePointDefinition>[
  ...cleaverDistributorPressurePoints,
  ...distral900DistributorPressurePoints,
];

class SteamPressureReading {
  const SteamPressureReading({
    required this.id,
    required this.recordedAt,
    required this.cleaverDistributorPsi,
    required this.distral900DistributorPsi,
  });

  final String id;
  final DateTime recordedAt;
  final Map<String, double> cleaverDistributorPsi;
  final Map<String, double> distral900DistributorPsi;

  Map<String, dynamic> toJson() => {
    'id': id,
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'pressureUnit': steamPressureUnit,
    'cleaverDistributorPsi': cleaverDistributorPsi,
    'distral900DistributorPsi': distral900DistributorPsi,
    'sectionId': 'servicios_industriales',
    'sectionNameSnapshot': 'Servicios Industriales',
    'equipmentName': 'Distribuidores de vapor de calderas',
    'equipmentNameNormalized': 'distribuidores de vapor de calderas',
    'status': 'synced',
    'source': 'manual',
    'schemaVersion': steamPressureSchemaVersion,
  };
}
