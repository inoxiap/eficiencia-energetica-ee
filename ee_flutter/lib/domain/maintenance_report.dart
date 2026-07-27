enum MaintenanceReportType { leak, barePipe }

class MaintenanceReportSummary {
  const MaintenanceReportSummary({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.sectionName,
    required this.equipmentName,
    required this.detail,
    required this.photoUrl,
    required this.createdByName,
    required this.workOrderCreated,
    required this.workCompleted,
    required this.status,
  });

  final String id;
  final MaintenanceReportType type;
  final DateTime createdAt;
  final String sectionName;
  final String equipmentName;
  final String detail;
  final String photoUrl;
  final String createdByName;
  final bool workOrderCreated;
  final bool workCompleted;
  final String status;

  MaintenanceReportSummary copyWith({
    bool? workOrderCreated,
    bool? workCompleted,
    String? status,
  }) {
    return MaintenanceReportSummary(
      id: id,
      type: type,
      createdAt: createdAt,
      sectionName: sectionName,
      equipmentName: equipmentName,
      detail: detail,
      photoUrl: photoUrl,
      createdByName: createdByName,
      workOrderCreated: workOrderCreated ?? this.workOrderCreated,
      workCompleted: workCompleted ?? this.workCompleted,
      status: status ?? this.status,
    );
  }
}
