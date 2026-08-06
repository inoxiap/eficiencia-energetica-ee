import 'destination_catalog.dart';

const leakReportSchemaVersion = 2;

enum LeakType { steam, condensate, oil, water, air }

extension LeakTypeDetails on LeakType {
  String get id => switch (this) {
    LeakType.steam => 'steam',
    LeakType.condensate => 'condensate',
    LeakType.oil => 'oil',
    LeakType.water => 'water',
    LeakType.air => 'air',
  };

  String get displayName => switch (this) {
    LeakType.steam => 'Vapor',
    LeakType.condensate => 'Condensado',
    LeakType.oil => 'Aceite',
    LeakType.water => 'Agua',
    LeakType.air => 'Aire',
  };
}

LeakType? leakTypeById(String id) {
  for (final type in LeakType.values) {
    if (type.id == id) return type;
  }
  return null;
}

class LeakReport {
  const LeakReport({
    required this.id,
    required this.createdAt,
    required this.destination,
    required this.leakType,
    required this.photoUrl,
    required this.photoPublicId,
    this.photoProvider = 'cloudinary',
    this.locationReference = '',
    this.notes = '',
    this.status = 'open',
    this.workOrderCreated = false,
    this.workCompleted = false,
  });

  final String id;
  final DateTime createdAt;
  final DestinationSelection destination;
  final LeakType leakType;
  final String photoUrl;
  final String photoPublicId;
  final String photoProvider;
  final String locationReference;
  final String notes;
  final String status;
  final bool workOrderCreated;
  final bool workCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'capturedAtLocal': createdAt.toUtc().toIso8601String(),
    'sectionId': destination.sectionCode,
    'sectionCode': destination.sectionCode,
    'sectionNameSnapshot': destination.sectionName,
    'processCode': destination.processCode,
    'processNameSnapshot': destination.processName,
    'equipmentCode': destination.equipmentCode,
    'equipmentName': destination.equipmentName,
    'equipmentNameNormalized': _normalize(destination.equipmentName),
    'systemCode': destination.systemCode,
    'systemNameSnapshot': destination.systemName,
    'destinationId': destination.destinationId,
    'selectionDepth': destination.selectionDepth,
    'destinationCatalogVersion': '2.0.0',
    'locationReference': locationReference,
    'leakType': leakType.id,
    'leakTypeNameSnapshot': leakType.displayName,
    'photoUrl': photoUrl,
    'photoPublicId': photoPublicId,
    'photoProvider': photoProvider,
    'notes': notes,
    'status': status,
    'workOrderCreated': workOrderCreated,
    'workCompleted': workCompleted,
    'schemaVersion': leakReportSchemaVersion,
  };
}

String _normalize(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
