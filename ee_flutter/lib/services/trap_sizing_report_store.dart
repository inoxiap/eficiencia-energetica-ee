import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/trap_sizing_report.dart';
import 'operator_session.dart';

class TrapSizingSaveReceipt {
  const TrapSizingSaveReceipt({required this.id});

  final String id;
}

class TrapSizingStoreException implements Exception {
  const TrapSizingStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class TrapSizingReportStore {
  Future<TrapSizingSaveReceipt> saveReport(TrapSizingReportDraft report);
}

class DisabledTrapSizingReportStore implements TrapSizingReportStore {
  const DisabledTrapSizingReportStore();

  @override
  Future<TrapSizingSaveReceipt> saveReport(TrapSizingReportDraft report) async {
    throw const TrapSizingStoreException(
      'El guardado en nube no esta disponible en este entorno.',
    );
  }
}

class FirebaseTrapSizingReportStore implements TrapSizingReportStore {
  FirebaseTrapSizingReportStore({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 20),
  }) : _firebaseReady = firebaseReady,
       _firestore = firestore,
       _operatorSession = operatorSession;

  final Future<FirebaseApp> _firebaseReady;
  final FirebaseFirestore? _firestore;
  final OperatorSession _operatorSession;
  final Duration timeout;

  Future<void> _ensureFirebase() => _firebaseReady.timeout(timeout);

  FirebaseFirestore get _database => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<TrapSizingSaveReceipt> saveReport(TrapSizingReportDraft report) async {
    await _ensureFirebase();
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const TrapSizingStoreException(
        'Inicia sesion como usuario antes de guardar en la nube.',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final document = _database
        .collection('steam_trap_sizing_reports')
        .doc(report.id);
    final data = <String, dynamic>{
      'id': report.id,
      'sectionId': report.sectionId,
      'sectionNameSnapshot': report.sectionNameSnapshot,
      'equipmentName': report.equipmentName,
      'equipmentNameNormalized': report.equipmentNameNormalized,
      'applicationTypeId': report.applicationTypeId,
      'applicationTypeNameSnapshot': report.applicationTypeNameSnapshot,
      'calculationMethod': report.calculationMethod,
      'inputs': report.structuredInputs(),
      'results': report.result.toMap(),
      'condensateLoadKgH': report.result.condensateLoadKgH,
      'requiredCapacityKgH': report.result.requiredCapacityKgH,
      'recommendedTrapType': report.result.recommendedTrapType,
      'recommendedConnectionDiameter':
          report.result.recommendedConnectionDiameter,
      'safetyFactor': report.safetyFactor,
      'formulaVersion': trapSizingFormulaVersion,
      'assumptions': report.assumptions,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': operator.uid,
      'createdByNameSnapshot': operator.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': operator.uid,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'platform': kIsWeb ? 'web' : 'android',
      'schemaVersion': trapSizingSchemaVersion,
      'status': 'synced',
      'source': 'manual',
      'notes': report.notes.isEmpty ? null : report.notes,
    };

    try {
      await document.set(data).timeout(timeout);
      final confirmation = await document
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      if (!confirmation.exists) {
        throw const TrapSizingStoreException('La nube no confirmo el reporte.');
      }
      return TrapSizingSaveReceipt(id: report.id);
    } on TrapSizingStoreException {
      rethrow;
    } on FirebaseException catch (error) {
      throw TrapSizingStoreException(
        error.code == 'permission-denied'
            ? 'Firebase rechazo el guardado. Verifica la sesion y las reglas.'
            : 'No se pudo confirmar el reporte en la nube (${error.code}).',
      );
    } on TimeoutException {
      throw const TrapSizingStoreException(
        'No se confirmo el guardado en la nube. Puedes reintentar sin duplicar.',
      );
    }
  }
}
