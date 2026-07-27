import 'package:eficiencia_energetica_ee/services/operator_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps cedula and PIN to Firebase Auth credentials', () {
    expect(
      operatorEmailForNationalId('2350181687'),
      'operator-2350181687@eficiencia-energetica-ee.app',
    );
    expect(firebasePasswordForPin('1411'), 'Ee:1411');
  });
}
