import 'package:eficiencia_energetica_ee/domain/destination_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalogJson = '''
{
  "schemaVersion": "2.0.0",
  "sections": [
    {
      "code": "15",
      "name": "MARGARINA",
      "processes": [
        {
          "code": "1",
          "name": "ALMACENAMIENTO MRG",
          "equipment": [
            {
              "code": "TACL01",
              "name": "TANQUE (MG-RBD1)",
              "destinationId": "",
              "systems": [
                {
                  "code": "MTK01",
                  "name": "Tanque de almacenamiento",
                  "destinationId": "SISMAC:15:1:TACL01:MTK01"
                }
              ]
            }
          ]
        }
      ]
    },
    {
      "code": "NOOP",
      "name": "NO OPERATIVOS",
      "processes": [
        {
          "code": "14",
          "name": "LINEA G3",
          "equipment": [
            {
              "code": "BUPT01",
              "name": "BOMBA ALTA PRESION K1",
              "destinationId": "SISMAC:NOOP:LINEA_G3:BUPT01:AF_1717",
              "systems": []
            }
          ]
        }
      ]
    }
  ]
}
''';

void main() {
  final catalog = DestinationCatalog.fromJsonString(_catalogJson);

  test('keeps lower levels empty when only Margarina is selected', () {
    final selection = catalog.selection(sectionCode: '15');

    expect(selection.toCodeJson(), {
      'sectionCode': '15',
      'processCode': '',
      'equipmentCode': '',
      'systemCode': '',
      'destinationId': '',
      'selectionDepth': 'section',
    });
  });

  test('does not assign a destination before a system is selected', () {
    final equipment = catalog.selection(
      sectionCode: '15',
      processCode: '1',
      equipmentCode: 'TACL01',
    );
    final system = catalog.selection(
      sectionCode: '15',
      processCode: '1',
      equipmentCode: 'TACL01',
      systemCode: 'MTK01',
    );

    expect(equipment.selectionDepth, 'equipment');
    expect(equipment.destinationId, '');
    expect(system.selectionDepth, 'system');
    expect(system.destinationId, 'SISMAC:15:1:TACL01:MTK01');
  });

  test('assigns the destination to terminal equipment without systems', () {
    final selection = catalog.selection(
      sectionCode: 'NOOP',
      processCode: '14',
      equipmentCode: 'BUPT01',
    );

    expect(selection.selectionDepth, 'equipment');
    expect(selection.destinationId, 'SISMAC:NOOP:LINEA_G3:BUPT01:AF_1717');
  });

  test('rejects child codes when a parent is empty', () {
    expect(
      () => catalog.selection(processCode: '1'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => catalog.selection(sectionCode: '15', equipmentCode: 'TACL01'),
      throwsA(isA<FormatException>()),
    );
  });
}
