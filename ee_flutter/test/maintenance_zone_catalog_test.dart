import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/maintenance_zone_catalog.dart';

void main() {
  test('carga las 83 zonas de la matriz y conserva sus responsables', () {
    expect(maintenanceZones, hasLength(83));
    expect(maintenanceZones.map((zone) => zone.number).toSet(), hasLength(83));

    final zone26 = maintenanceZoneByNumber(26);
    expect(zone26?.section, 'Hidrogenación');
    expect(zone26?.responsibles, hasLength(3));
  });

  test('la zona muestra una etiqueta navegable con sección y proceso', () {
    expect(
      maintenanceZoneByNumber(1)?.label,
      'Zona 1 - Refinería - Almacenamiento RB',
    );
  });
}
