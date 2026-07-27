import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/section_catalog.dart';

void main() {
  test('section catalog has stable unique IDs', () {
    expect(plantSections, hasLength(12));
    expect(plantSections.map((section) => section.id).toSet(), hasLength(12));
    expect(
      plantSectionById('servicios_industriales')?.displayName,
      'Servicios Industriales',
    );
  });

  test('equipment normalization is consistent', () {
    expect(normalizeEquipmentName('  Bomba   Principal  '), 'bomba principal');
  });
}
