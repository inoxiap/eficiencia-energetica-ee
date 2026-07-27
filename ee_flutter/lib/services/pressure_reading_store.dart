import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/steam_pressure_reading.dart';
import 'operator_session.dart';

abstract class PressureReadingStore {
  Future<void> saveReading(SteamPressureReading reading);
}

class PressureReadingStoreException implements Exception {
  const PressureReadingStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DisabledPressureReadingStore implements PressureReadingStore {
  const DisabledPressureReadingStore();

  @override
  Future<void> saveReading(SteamPressureReading reading) {
    throw const PressureReadingStoreException(
      'El almacenamiento de presiones no esta disponible.',
    );
  }
}

class FirebasePressureReadingStore implements PressureReadingStore {
  FirebasePressureReadingStore({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 25),
  }) : _firebaseReady = firebaseReady,
       _operatorSession = operatorSession,
       _firestore = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final OperatorSession _operatorSession;
  final FirebaseFirestore? _firestore;
  final Duration timeout;

  @override
  Future<void> saveReading(SteamPressureReading reading) async {
    await _firebaseReady.timeout(timeout);
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const PressureReadingStoreException(
        'Inicia sesion como usuario antes de guardar presiones.',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final firestore = _firestore ?? FirebaseFirestore.instance;
    final document = firestore
        .collection('steam_pressure_readings')
        .doc(reading.id);
    final data = reading.toJson();
    data['recordedAt'] = Timestamp.fromDate(reading.recordedAt.toUtc());
    data['capturedAtLocal'] = reading.recordedAt.toUtc().toIso8601String();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['createdByUid'] = operator.uid;
    data['createdByNameSnapshot'] = operator.displayName;
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedByUid'] = operator.uid;
    data['appVersion'] = '${packageInfo.version}+${packageInfo.buildNumber}';
    data['platform'] = kIsWeb ? 'web' : 'android';

    await firestore
        .runTransaction((transaction) async {
          final existing = await transaction.get(document);
          if (existing.exists) {
            throw const PressureReadingStoreException(
              'Esta lectura de presiones ya fue guardada.',
            );
          }
          transaction.set(document, data);
        })
        .timeout(timeout);

    final confirmation = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!confirmation.exists) {
      throw const PressureReadingStoreException(
        'La nube no confirmo la lectura de presiones.',
      );
    }
  }
}
