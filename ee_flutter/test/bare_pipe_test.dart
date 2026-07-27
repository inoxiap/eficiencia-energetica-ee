import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eficiencia_energetica_ee/domain/bare_pipe.dart';

void main() {
  test('bare pipe calculation keeps its baseline result', () {
    final result = BarePipeCalculator.calculate(
      diameterLabel: '2"',
      pressureBarG: 7,
      lengthMeters: 10,
    );

    expect(result.isCalculated, isTrue);
    expect(result.surfaceTemperatureC, closeTo(170.4, 0.000000001));
    expect(result.heatLossWPerM, closeTo(440.9332978835856, 0.000000001));
    expect(result.heatLossKw, closeTo(4.409332978835856, 0.000000001));
    expect(result.energyKwhMonth, closeTo(3174.7197447618164, 0.000000001));
    expect(result.monthlyGallons, closeTo(102.5382787687175, 0.000000001));
    expect(result.monthlyUsd, closeTo(96.38598204259445, 0.000000001));
  });

  test('historical ISO dates and new Firestore timestamps are readable', () {
    final historical = BarePipeReport.fromJson({
      'id': 'old',
      'createdAt': '2026-05-30T10:00:00-05:00',
      'section': 'Refineria',
      'calculation': BarePipeCalculation.pending.toJson(),
    });
    final timestampDate = DateTime.utc(2026, 7, 11, 15);
    final current = BarePipeReport.fromJson({
      'id': 'new',
      'createdAt': Timestamp.fromDate(timestampDate),
      'sectionId': 'refineria',
      'sectionNameSnapshot': 'Refineria',
      'calculation': BarePipeCalculation.pending.toJson(),
    });

    expect(historical.createdAt.toUtc(), DateTime.utc(2026, 5, 30, 15));
    expect(current.createdAt.toUtc(), timestampDate);
  });

  test('pending sync state preserves report data', () {
    final report = BarePipeReport(
      id: 'pipe-1',
      createdAt: DateTime.utc(2026, 7, 11),
      section: 'Refineria',
      diameterLabel: '2"',
      pressureBarG: 7,
      lengthMeters: 10,
      photoUrl: 'https://example.test/photo.jpg',
      photoPublicId: 'ee/pipe-1',
      calculation: BarePipeCalculator.calculate(
        diameterLabel: '2"',
        pressureBarG: 7,
        lengthMeters: 10,
      ),
      sectionId: 'refineria',
      sectionNameSnapshot: 'Refineria',
      equipmentName: 'Cabezal 1',
      equipmentNameNormalized: 'cabezal 1',
      photoProvider: 'cloudinary',
    );

    final pending = report.copyWith(
      status: 'pending_sync',
      syncError: 'Sin confirmacion',
    );

    expect(pending.id, report.id);
    expect(pending.calculation.heatLossKw, report.calculation.heatLossKw);
    expect(pending.status, 'pending_sync');
    expect(pending.syncError, 'Sin confirmacion');
  });
}
