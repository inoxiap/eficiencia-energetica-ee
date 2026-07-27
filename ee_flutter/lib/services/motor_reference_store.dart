import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../domain/pump_energy.dart';

class MotorReferencePair {
  const MotorReferencePair({
    required this.efficiency,
    required this.powerFactor,
  });

  final MotorReferenceValue efficiency;
  final MotorReferenceValue powerFactor;
}

abstract class MotorReferenceStore {
  Future<MotorReferencePair?> lookup({
    required double powerHp,
    required int poles,
    required String ieClass,
  });
}

class DisabledMotorReferenceStore implements MotorReferenceStore {
  const DisabledMotorReferenceStore();

  @override
  Future<MotorReferencePair?> lookup({
    required double powerHp,
    required int poles,
    required String ieClass,
  }) async => null;
}

class FirebaseMotorReferenceStore implements MotorReferenceStore {
  FirebaseMotorReferenceStore({
    required Future<FirebaseApp> firebaseReady,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady,
       _firestore = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final FirebaseFirestore? _firestore;
  final Duration timeout;

  @override
  Future<MotorReferencePair?> lookup({
    required double powerHp,
    required int poles,
    required String ieClass,
  }) async {
    try {
      await _firebaseReady.timeout(timeout);
      final snapshot = await (_firestore ?? FirebaseFirestore.instance)
          .collection('motor_reference_tables')
          .where('powerHp', isEqualTo: powerHp)
          .where('active', isEqualTo: true)
          .limit(20)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      for (final document in snapshot.docs) {
        final data = document.data();
        if (data['poles'] != poles || data['ieClass'] != ieClass) {
          continue;
        }
        final efficiency = (data['efficiency'] as num?)?.toDouble();
        final powerFactor = (data['typicalPowerFactor'] as num?)?.toDouble();
        if (efficiency == null || powerFactor == null) {
          continue;
        }
        final version = (data['version'] as String? ?? 'unversioned').trim();
        final source = (data['source'] as String? ?? 'firestore').trim();
        return MotorReferencePair(
          efficiency: MotorReferenceValue(
            value: efficiency,
            source: 'motor_reference_tables:$source:$version',
          ),
          powerFactor: MotorReferenceValue(
            value: powerFactor,
            source: 'motor_reference_tables:$source:$version',
          ),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
