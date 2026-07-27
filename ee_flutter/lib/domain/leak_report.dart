const leakReportSchemaVersion = 1;

enum LeakType { steam, oil, water, air }

extension LeakTypeDetails on LeakType {
  String get id => switch (this) {
    LeakType.steam => 'steam',
    LeakType.oil => 'oil',
    LeakType.water => 'water',
    LeakType.air => 'air',
  };

  String get displayName => switch (this) {
    LeakType.steam => 'Vapor',
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
    required this.sectionId,
    required this.sectionNameSnapshot,
    required this.equipmentName,
    required this.equipmentNameNormalized,
    required this.leakType,
    required this.tagNumber,
    required this.photoUrl,
    required this.photoPublicId,
    this.photoProvider = 'cloudinary',
    this.notes = '',
    this.status = 'open',
    this.workOrderCreated = false,
    this.workCompleted = false,
  });

  final String id;
  final DateTime createdAt;
  final String sectionId;
  final String sectionNameSnapshot;
  final String equipmentName;
  final String equipmentNameNormalized;
  final LeakType leakType;
  final String tagNumber;
  final String photoUrl;
  final String photoPublicId;
  final String photoProvider;
  final String notes;
  final String status;
  final bool workOrderCreated;
  final bool workCompleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'capturedAtLocal': createdAt.toUtc().toIso8601String(),
    'sectionId': sectionId,
    'sectionNameSnapshot': sectionNameSnapshot,
    'equipmentName': equipmentName,
    'equipmentNameNormalized': equipmentNameNormalized,
    'leakType': leakType.id,
    'leakTypeNameSnapshot': leakType.displayName,
    'tagNumber': tagNumber,
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
