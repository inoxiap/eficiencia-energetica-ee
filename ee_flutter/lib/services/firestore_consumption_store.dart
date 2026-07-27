import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/boiler_consumption.dart';
import 'consumption_store.dart';
import 'operator_session.dart';

class FirestoreConsumptionStore implements ConsumptionStore {
  static const recentReadingLimit = 250;

  FirestoreConsumptionStore({
    required OperatorSession operatorSession,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 20),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _operatorSession = operatorSession;

  final FirebaseFirestore _firestore;
  final OperatorSession _operatorSession;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _readings =>
      _firestore.collection('boiler_consumption_readings');

  @override
  Future<List<BoilerReading>> loadReadings() async {
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const ConsumptionSyncException(
        'Inicia sesion como usuario antes de consultar lecturas.',
      );
    }
    Query<Map<String, dynamic>> query = _readings;
    if (operator.role != 'admin') {
      query = query.where('createdByUid', isEqualTo: operator.uid);
    }
    final snapshot = await query
        .orderBy('recordedAt', descending: true)
        .limit(recentReadingLimit)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = data['id'] ?? doc.id;
      return BoilerReading.fromJson(data);
    }).toList();
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const ConsumptionSyncException(
        'Inicia sesion como usuario antes de guardar la lectura.',
      );
    }
    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final data = reading.toJson();
    data.remove('operatorPin');
    data['recordedAt'] = Timestamp.fromDate(reading.recordedAt.toUtc());
    data['intervalStart'] = reading.intervalStart == null
        ? null
        : Timestamp.fromDate(reading.intervalStart!.toUtc());
    data['intervalEnd'] = reading.intervalEnd == null
        ? null
        : Timestamp.fromDate(reading.intervalEnd!.toUtc());
    data['capturedAtLocal'] = reading.createdAt.toUtc().toIso8601String();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['createdByUid'] = operator.uid;
    data['createdByNameSnapshot'] = operator.displayName;
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedByUid'] = operator.uid;
    data['appVersion'] = '${packageInfo.version}+${packageInfo.buildNumber}';
    data['platform'] = kIsWeb ? 'web' : 'android';
    data['source'] = 'manual';
    data['status'] = 'synced';

    final document = _readings.doc(reading.id);
    try {
      // Firestore rules reject updates, so a direct set is create-only without
      // requiring operators to read a document that does not exist yet.
      await document.set(data).timeout(timeout);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        try {
          final existing = await document
              .get(const GetOptions(source: Source.server))
              .timeout(timeout);
          if (existing.exists) {
            throw const DuplicateBoilerReadingException(
              'Ya existe una lectura con este identificador y revision.',
            );
          }
        } on DuplicateBoilerReadingException {
          rethrow;
        } catch (_) {
          // Preserve the original permission error when the document is absent
          // or cannot be read by the current operator.
        }
      }
      rethrow;
    }
    final confirmation = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!confirmation.exists) {
      throw const ConsumptionSyncException('La nube no confirmo la lectura.');
    }
  }
}
