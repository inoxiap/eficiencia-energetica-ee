import 'package:eficiencia_energetica_ee/domain/leak_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes a new leak report with explicit workflow state', () {
    final report = LeakReport(
      id: 'leak-1',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      sectionId: 'refineria',
      sectionNameSnapshot: 'Refineria',
      equipmentName: 'Linea 4',
      equipmentNameNormalized: 'linea 4',
      leakType: LeakType.steam,
      tagNumber: '25',
      photoUrl: 'https://example.test/photo.jpg',
      photoPublicId: 'ee/leak-1',
    );

    final data = report.toJson();

    expect(data['leakType'], 'steam');
    expect(data['tagNumber'], '25');
    expect(data['photoProvider'], 'cloudinary');
    expect(data['workOrderCreated'], isFalse);
    expect(data['workCompleted'], isFalse);
    expect(data['schemaVersion'], leakReportSchemaVersion);
  });
}
