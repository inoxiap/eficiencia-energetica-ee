import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/steam_pressure_reading.dart';

void main() {
  test('pressure catalog contains both complete distributor groups', () {
    expect(cleaverDistributorPressurePoints, hasLength(5));
    expect(distral900DistributorPressurePoints, hasLength(9));
    expect(steamPressurePoints, hasLength(14));
    expect(steamPressurePoints.map((point) => point.id).toSet(), hasLength(14));
  });

  test('pressure reading keeps original PSI values and explicit unit', () {
    final reading = SteamPressureReading(
      id: 'pressure-1',
      recordedAt: DateTime.utc(2026, 7, 24, 15),
      cleaverDistributorPsi: {
        for (final point in cleaverDistributorPressurePoints) point.id: 80,
      },
      distral900DistributorPsi: {
        for (final point in distral900DistributorPressurePoints) point.id: 70,
      },
    );

    final json = reading.toJson();

    expect(json['pressureUnit'], steamPressureUnit);
    expect(
      json['cleaverDistributorPsi'],
      hasLength(cleaverDistributorPressurePoints.length),
    );
    expect(
      json['distral900DistributorPsi'],
      hasLength(distral900DistributorPressurePoints.length),
    );
    expect(json['sectionId'], 'servicios_industriales');
    expect(json['schemaVersion'], steamPressureSchemaVersion);
  });
}
