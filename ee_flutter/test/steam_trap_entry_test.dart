import 'package:eficiencia_energetica_ee/domain/steam_trap_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('steam trap record preserves identity, ownership and both photos', () {
    final record = SteamTrapRecord.fromJson('internal-1', {
      'tag': 'TV-15-001',
      'sectionCode': '15',
      'sectionId': 'margarina',
      'sectionNameSnapshot': 'Margarina',
      'zone': 'Linea 2',
      'equipmentName': 'Tanque 4',
      'serviceId': 'jacket',
      'serviceNameSnapshot': 'Chaqueta',
      'diameter': '1/2 in',
      'trapTypeId': 'float_thermostatic',
      'trapTypeNameSnapshot': 'Flotador termostatica',
      'condensateRecovery': 'yes',
      'comments': '',
      'diagnosisStatus': 'operational',
      'status': 'complete',
      'ownerUid': 'provider-1',
      'ownerNameSnapshot': 'Proveedor Uno',
      'createdAt': DateTime.utc(2026, 9, 14),
      'updatedAt': DateTime.utc(2026, 9, 14),
      'closePhoto': {
        'type': 'close',
        'url': 'https://example.test/close.jpg',
        'publicId': 'TV-15-001_CERCA',
        'fileName': 'TV-15-001_CERCA.jpg',
        'uploadedAt': '2026-09-14T12:00:00Z',
        'ownerUid': 'provider-1',
        'tag': 'TV-15-001',
      },
      'generalPhoto': {
        'type': 'general',
        'url': 'https://example.test/general.jpg',
        'publicId': 'TV-15-001_GENERAL',
        'fileName': 'TV-15-001_GENERAL.jpg',
        'uploadedAt': '2026-09-14T12:01:00Z',
        'ownerUid': 'provider-1',
        'tag': 'TV-15-001',
      },
    });

    expect(record.id, 'internal-1');
    expect(record.tag, 'TV-15-001');
    expect(record.ownerUid, 'provider-1');
    expect(record.closePhoto?.fileName, 'TV-15-001_CERCA.jpg');
    expect(record.generalPhoto?.fileName, 'TV-15-001_GENERAL.jpg');
    expect(record.isDraft, isFalse);
  });

  test('catalog labels keep stable IDs for export and filters', () {
    expect(SteamTrapService.tracing.id, 'tracing');
    expect(SteamTrapType.invertedBucket.id, 'inverted_bucket');
    expect(CondensateRecovery.toConfirm.id, 'to_confirm');
  });
}
