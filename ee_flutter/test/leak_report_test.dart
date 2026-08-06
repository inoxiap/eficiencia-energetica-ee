import 'package:eficiencia_energetica_ee/domain/leak_report.dart';
import 'package:eficiencia_energetica_ee/domain/destination_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes a new leak report with explicit workflow state', () {
    final catalog = DestinationCatalog.fromJsonString(
      '{"schemaVersion":"2.0.0","sections":[{"code":"15","name":"MARGARINA","processes":[]}]}',
    );
    final report = LeakReport(
      id: 'leak-1',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      destination: catalog.selection(sectionCode: '15'),
      leakType: LeakType.condensate,
      photoUrl: 'https://example.test/photo.jpg',
      photoPublicId: 'ee/leak-1',
    );

    final data = report.toJson();

    expect(data['leakType'], 'condensate');
    expect(data['sectionCode'], '15');
    expect(data['processCode'], '');
    expect(data['equipmentCode'], '');
    expect(data['systemCode'], '');
    expect(data['destinationId'], '');
    expect(data['selectionDepth'], 'section');
    expect(data['photoProvider'], 'cloudinary');
    expect(data['workOrderCreated'], isFalse);
    expect(data['workCompleted'], isFalse);
    expect(data['schemaVersion'], leakReportSchemaVersion);
  });
}
