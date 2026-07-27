import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/pump_energy.dart';
import 'operator_session.dart';

class PumpSurveyStoreException implements Exception {
  const PumpSurveyStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PumpSurveyStore {
  Future<List<PumpBaselineOption>> loadBaselines();

  Future<void> saveSurvey(
    PumpSurveyDraft survey, {
    String? photoUrl,
    String? photoPublicId,
  });
}

class DisabledPumpSurveyStore implements PumpSurveyStore {
  const DisabledPumpSurveyStore();

  @override
  Future<List<PumpBaselineOption>> loadBaselines() async => const [];

  @override
  Future<void> saveSurvey(
    PumpSurveyDraft survey, {
    String? photoUrl,
    String? photoPublicId,
  }) {
    throw const PumpSurveyStoreException(
      'El guardado de bombas no esta disponible en este entorno.',
    );
  }
}

class FirebasePumpSurveyStore implements PumpSurveyStore {
  FirebasePumpSurveyStore({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 20),
  }) : _firebaseReady = firebaseReady,
       _operatorSession = operatorSession,
       _firestore = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final OperatorSession _operatorSession;
  final FirebaseFirestore? _firestore;
  final Duration timeout;

  @override
  Future<List<PumpBaselineOption>> loadBaselines() async {
    await _firebaseReady.timeout(timeout);
    final user = await _operatorSession.currentOperator();
    if (user == null) {
      return const [];
    }

    try {
      final snapshot = await (_firestore ?? FirebaseFirestore.instance)
          .collection('pump_energy_surveys')
          .where('surveyType', isEqualTo: 'baseline')
          .limit(250)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      final baselines = <PumpBaselineOption>[];
      for (final document in snapshot.docs) {
        final data = document.data();
        final sectionId = (data['sectionId'] as String? ?? '').trim();
        final sectionName = (data['sectionNameSnapshot'] as String? ?? '')
            .trim();
        final equipmentName = (data['equipmentName'] as String? ?? '').trim();
        final equipmentNameNormalized =
            (data['equipmentNameNormalized'] as String? ?? '').trim();
        final assetId = (data['assetId'] as String? ?? '').trim();
        final pumpTag = (data['pumpTag'] as String? ?? '').trim();
        final serviceDescription = (data['serviceDescription'] as String? ?? '')
            .trim();
        final nominalPowerHp = (data['nominalPowerHp'] as num?)?.toDouble();
        if (sectionId.isEmpty ||
            sectionName.isEmpty ||
            equipmentName.isEmpty ||
            assetId.isEmpty ||
            pumpTag.isEmpty ||
            nominalPowerHp == null ||
            nominalPowerHp <= 0) {
          continue;
        }
        baselines.add(
          PumpBaselineOption(
            surveyId: document.id,
            sectionId: sectionId,
            sectionName: sectionName,
            equipmentName: equipmentName,
            equipmentNameNormalized: equipmentNameNormalized.isEmpty
                ? equipmentName.toLowerCase()
                : equipmentNameNormalized,
            assetId: assetId,
            pumpTag: pumpTag,
            serviceDescription: serviceDescription,
            nominalPowerHp: nominalPowerHp,
          ),
        );
      }
      baselines.sort((left, right) {
        final bySection = left.sectionName.compareTo(right.sectionName);
        if (bySection != 0) return bySection;
        final byEquipment = left.equipmentName.compareTo(right.equipmentName);
        if (byEquipment != 0) return byEquipment;
        return left.pumpTag.compareTo(right.pumpTag);
      });
      return baselines;
    } on FirebaseException catch (error) {
      throw PumpSurveyStoreException(
        error.code == 'permission-denied'
            ? 'Firebase no permitio consultar las lineas base.'
            : 'No se pudieron consultar las lineas base (${error.code}).',
      );
    } on TimeoutException {
      throw const PumpSurveyStoreException(
        'La consulta de lineas base tardo demasiado. Intenta nuevamente.',
      );
    }
  }

  @override
  Future<void> saveSurvey(
    PumpSurveyDraft survey, {
    String? photoUrl,
    String? photoPublicId,
  }) async {
    await _firebaseReady.timeout(timeout);
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const PumpSurveyStoreException(
        'Inicia sesion como usuario antes de guardar.',
      );
    }
    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final result = survey.result;
    final data = <String, dynamic>{
      'id': survey.id,
      'sectionId': survey.sectionId,
      'sectionNameSnapshot': survey.sectionNameSnapshot,
      'equipmentName': survey.equipmentName,
      'equipmentNameNormalized': survey.equipmentNameNormalized,
      'assetId': survey.assetId,
      'pumpTag': survey.pumpTag,
      'serviceDescription': survey.serviceDescription,
      'surveyType': survey.surveyType,
      'interventionId': survey.interventionId,
      'baselineSurveyId': survey.baselineSurveyId,
      'nominalPowerHp': survey.nominalPowerHp,
      'identification': survey.identification,
      'electricalInputs': survey.electricalInputs,
      'operatingInputs': survey.operatingInputs,
      'results': result.toMap(),
      'estimatedInputPowerKw': result.estimatedInputPowerKw,
      'measuredInputPowerKw': result.measuredInputPowerKw,
      'estimatedShaftPowerKw': result.shaftPowerKw,
      'dailyEnergyKwh': result.dailyEnergyKwh,
      'annualEnergyKwh': result.annualEnergyKwh,
      'confidenceLevel': result.confidenceLevel,
      'candidateForHydraulicReview': result.candidateForHydraulicReview,
      'assumptions': survey.assumptions,
      'warnings': result.warnings,
      'photo': photoUrl == null
          ? null
          : {
              'provider': 'cloudinary',
              'url': photoUrl,
              'publicId': photoPublicId,
            },
      'formulaVersion': pumpFormulaVersion,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': operator.uid,
      'createdByNameSnapshot': operator.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': operator.uid,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'platform': kIsWeb ? 'web' : 'android',
      'schemaVersion': pumpSurveySchemaVersion,
      'status': 'synced',
      'source': 'manual',
      'notes': survey.notes.isEmpty ? null : survey.notes,
    };

    final document = (_firestore ?? FirebaseFirestore.instance)
        .collection('pump_energy_surveys')
        .doc(survey.id);
    try {
      await document.set(data).timeout(timeout);
      final confirmation = await document
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      if (!confirmation.exists) {
        throw const PumpSurveyStoreException(
          'La nube no confirmo el levantamiento.',
        );
      }
    } on PumpSurveyStoreException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PumpSurveyStoreException(
        error.code == 'permission-denied'
            ? 'Firebase rechazo el guardado. Verifica sesion y reglas.'
            : 'No se confirmo el levantamiento (${error.code}).',
      );
    } on TimeoutException {
      throw const PumpSurveyStoreException(
        'No se confirmo el levantamiento. Puedes reintentar con el mismo ID.',
      );
    }
  }
}
