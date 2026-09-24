enum SteamTrapEntryMode { newEntry, inventoryValidation }

enum SteamTrapService {
  tracing('tracing', 'Tracing'),
  coil('coil', 'Serpentin'),
  jacket('jacket', 'Chaqueta'),
  steamDistributor('steam_distributor', 'Distribuidor de vapor'),
  condensateLine('condensate_line', 'Linea de condensado'),
  separator('separator', 'Separador'),
  heatExchanger('heat_exchanger', 'Intercambiador de calor'),
  other('other', 'Otro');

  const SteamTrapService(this.id, this.label);
  final String id;
  final String label;
}

enum SteamTrapType {
  thermodynamic('thermodynamic', 'Termodinamica'),
  invertedBucket('inverted_bucket', 'Balde invertido'),
  float('float', 'Flotador'),
  floatThermostatic('float_thermostatic', 'Flotador termostatica'),
  other('other', 'Otro');

  const SteamTrapType(this.id, this.label);
  final String id;
  final String label;
}

enum CondensateRecovery {
  yes('yes', 'Si'),
  no('no', 'No'),
  toConfirm('to_confirm', 'Por confirmar');

  const CondensateRecovery(this.id, this.label);
  final String id;
  final String label;
}

class SteamTrapPhoto {
  const SteamTrapPhoto({
    required this.type,
    required this.url,
    required this.publicId,
    required this.fileName,
    required this.uploadedAt,
    required this.ownerUid,
    required this.tag,
  });

  final String type;
  final String url;
  final String publicId;
  final String fileName;
  final DateTime uploadedAt;
  final String ownerUid;
  final String tag;

  Map<String, Object?> toJson() => {
    'type': type,
    'url': url,
    'publicId': publicId,
    'fileName': fileName,
    'uploadedAt': uploadedAt.toUtc().toIso8601String(),
    'ownerUid': ownerUid,
    'tag': tag,
    'provider': 'cloudinary',
  };

  factory SteamTrapPhoto.fromJson(Map<String, dynamic> json) => SteamTrapPhoto(
    type: json['type'] as String? ?? '',
    url: json['url'] as String? ?? '',
    publicId: json['publicId'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    uploadedAt:
        DateTime.tryParse(json['uploadedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    ownerUid: json['ownerUid'] as String? ?? '',
    tag: json['tag'] as String? ?? '',
  );
}

class SteamTrapRecord {
  const SteamTrapRecord({
    required this.id,
    required this.tag,
    required this.sectionCode,
    required this.sectionId,
    required this.sectionName,
    required this.zone,
    required this.equipmentName,
    required this.serviceId,
    required this.serviceName,
    required this.diameter,
    required this.trapTypeId,
    required this.trapTypeName,
    required this.condensateRecoveryId,
    required this.comments,
    required this.diagnosisStatus,
    required this.status,
    required this.ownerUid,
    required this.ownerName,
    this.companyId = '',
    this.companyName = '',
    this.isDemo = false,
    required this.createdAt,
    required this.updatedAt,
    this.closePhoto,
    this.generalPhoto,
    this.legacyId = '',
  });

  final String id;
  final String tag;
  final String sectionCode;
  final String sectionId;
  final String sectionName;
  final String zone;
  final String equipmentName;
  final String serviceId;
  final String serviceName;
  final String diameter;
  final String trapTypeId;
  final String trapTypeName;
  final String condensateRecoveryId;
  final String comments;
  final String diagnosisStatus;
  final String status;
  final String ownerUid;
  final String ownerName;
  final String companyId;
  final String companyName;
  final bool isDemo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SteamTrapPhoto? closePhoto;
  final SteamTrapPhoto? generalPhoto;
  final String legacyId;

  bool get isDraft => status != 'complete';

  factory SteamTrapRecord.fromJson(String id, Map<String, dynamic> json) {
    SteamTrapPhoto? photo(String key) {
      final value = json[key];
      return value is Map
          ? SteamTrapPhoto.fromJson(Map<String, dynamic>.from(value))
          : null;
    }

    DateTime date(String key) => json[key] is DateTime
        ? json[key] as DateTime
        : DateTime.tryParse(json[key] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
    return SteamTrapRecord(
      id: id,
      tag: json['tag'] as String? ?? '',
      sectionCode: json['sectionCode'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      sectionName: json['sectionNameSnapshot'] as String? ?? '',
      zone: json['zone'] as String? ?? '',
      equipmentName: json['equipmentName'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceName: json['serviceNameSnapshot'] as String? ?? '',
      diameter: json['diameter'] as String? ?? '',
      trapTypeId: json['trapTypeId'] as String? ?? '',
      trapTypeName: json['trapTypeNameSnapshot'] as String? ?? '',
      condensateRecoveryId: json['condensateRecovery'] as String? ?? '',
      comments: json['comments'] as String? ?? '',
      diagnosisStatus: json['diagnosisStatus'] as String? ?? 'pending',
      status: json['status'] as String? ?? 'draft',
      ownerUid: json['ownerUid'] as String? ?? '',
      ownerName: json['ownerNameSnapshot'] as String? ?? '',
      companyId: json['companyId'] as String? ?? '',
      companyName: json['companyNameSnapshot'] as String? ?? '',
      isDemo: json['isDemo'] as bool? ?? false,
      createdAt: date('createdAt'),
      updatedAt: date('updatedAt'),
      closePhoto: photo('closePhoto'),
      generalPhoto: photo('generalPhoto'),
      legacyId: json['legacyId'] as String? ?? '',
    );
  }
}

class SteamTrapRecordInput {
  const SteamTrapRecordInput({
    required this.id,
    required this.zone,
    required this.equipmentName,
    required this.serviceId,
    required this.serviceName,
    required this.diameter,
    required this.trapTypeId,
    required this.trapTypeName,
    required this.condensateRecoveryId,
    required this.comments,
    required this.diagnosisStatus,
    required this.status,
    required this.mode,
    this.closePhoto,
    this.generalPhoto,
  });

  final String id;
  final String zone;
  final String equipmentName;
  final String serviceId;
  final String serviceName;
  final String diameter;
  final String trapTypeId;
  final String trapTypeName;
  final String condensateRecoveryId;
  final String comments;
  final String diagnosisStatus;
  final String status;
  final SteamTrapEntryMode mode;
  final SteamTrapPhoto? closePhoto;
  final SteamTrapPhoto? generalPhoto;
}
