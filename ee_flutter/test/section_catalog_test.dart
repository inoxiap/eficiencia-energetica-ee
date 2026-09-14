import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/section_catalog.dart';

void main() {
  test('section catalog has stable unique IDs', () {
    expect(plantSections, hasLength(15));
    expect(plantSections.map((section) => section.id).toSet(), hasLength(15));
    expect(plantSections.map((section) => section.code).toSet(), hasLength(15));
    expect(
      plantSectionById('servicios_industriales')?.displayName,
      'Servicios Industriales',
    );
    expect(plantSectionByCode('15')?.id, 'margarina');
    expect(plantSections.any((section) => section.code == '14'), isFalse);
  });

  test('equipment normalization is consistent', () {
    expect(normalizeEquipmentName('  Bomba   Principal  '), 'bomba principal');
  });
}
