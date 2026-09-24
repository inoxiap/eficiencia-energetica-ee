import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/section_catalog.dart';
import '../domain/steam_trap_entry.dart';
import 'operator_session.dart';

class SteamTrapStoreException implements Exception {
  const SteamTrapStoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class SteamTrapStore {
  Future<SteamTrapRecord> reserveTag({
    required String recordId,
    required PlantSection section,
  });

  Future<void> saveRecord(SteamTrapRecordInput input);

  Future<List<SteamTrapRecord>> loadRecords();

  Future<void> correctSectionAsAdmin({
    required SteamTrapRecord record,
    required PlantSection section,
    required String reason,
  });
}

class DisabledSteamTrapStore implements SteamTrapStore {
  const DisabledSteamTrapStore();

  Never _disabled() => throw const SteamTrapStoreException(
    'El inventario de trampas no esta disponible en este entorno.',
  );

  @override
  Future<List<SteamTrapRecord>> loadRecords() async => const [];

  @override
  Future<SteamTrapRecord> reserveTag({
    required String recordId,
    required PlantSection section,
  }) async => _disabled();

  @override
  Future<void> saveRecord(SteamTrapRecordInput input) async => _disabled();

  @override
  Future<void> correctSectionAsAdmin({
    required SteamTrapRecord record,
    required PlantSection section,
    required String reason,
  }) async => _disabled();
}

class FirebaseSteamTrapStore implements SteamTrapStore {
  FirebaseSteamTrapStore({
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

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  @override
  Future<SteamTrapRecord> reserveTag({
    required String recordId,
    required PlantSection section,
  }) async {
    await _firebaseReady.timeout(timeout);
    final user = await _requireUser();
    final package = await PackageInfo.fromPlatform().timeout(timeout);
    final document = _db.collection('steam_trap_records').doc(recordId);
    final counter = _db.collection('steam_trap_counters').doc(section.code);

    await _db
        .runTransaction<void>((transaction) async {
          final existing = await transaction.get(document);
          if (existing.exists) {
            final data = existing.data();
            if (data?['ownerUid'] != user.uid ||
                data?['sectionCode'] != section.code) {
              throw const SteamTrapStoreException(
                'El borrador ya existe con otro propietario o seccion.',
              );
            }
            return;
          }

          final counterSnapshot = await transaction.get(counter);
          final current = counterSnapshot.data()?['lastNumber'];
          final next = current is int ? current + 1 : 1;
          final tag = 'TV-${section.code}-${next.toString().padLeft(3, '0')}';
          transaction.set(counter, {
            'sectionCode': section.code,
            'lastNumber': next,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': user.uid,
          });
          transaction.set(document, {
            'id': recordId,
            'tag': tag,
            'tagLocked': true,
            'sectionCode': section.code,
            'sectionId': section.id,
            'sectionNameSnapshot': section.displayName,
            'zone': '',
            'equipmentName': '',
            'equipmentNameNormalized': '',
            'serviceId': '',
            'serviceNameSnapshot': '',
            'diameter': '',
            'trapTypeId': '',
            'trapTypeNameSnapshot': '',
            'condensateRecovery': '',
            'comments': '',
            'diagnosisStatus': 'pending',
            'entryMode': 'new_entry',
            'status': 'draft',
            'photoProvider': 'cloudinary',
            'ownerUid': user.uid,
            'ownerNameSnapshot': user.displayName,
            'companyId': user.companyId,
            'companyNameSnapshot': user.companyName,
            'isDemo': false,
            'sharedWithUids': <String>[],
            'createdAt': FieldValue.serverTimestamp(),
            'createdByUid': user.uid,
            'createdByNameSnapshot': user.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': user.uid,
            'appVersion': '${package.version}+${package.buildNumber}',
            'platform': kIsWeb ? 'web' : 'android',
            'schemaVersion': 1,
            'source': 'manual',
            'sectionHistory': <Map<String, Object?>>[],
          });
        })
        .timeout(timeout);

    final snapshot = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!snapshot.exists) {
      throw const SteamTrapStoreException('Firebase no confirmo el borrador.');
    }
    return _record(snapshot);
  }

  @override
  Future<void> saveRecord(SteamTrapRecordInput input) async {
    await _firebaseReady.timeout(timeout);
    final user = await _requireUser();
    final package = await PackageInfo.fromPlatform().timeout(timeout);
    final document = _db.collection('steam_trap_records').doc(input.id);
    await _db
        .runTransaction<void>((transaction) async {
          final snapshot = await transaction.get(document);
          if (!snapshot.exists) {
            throw const SteamTrapStoreException(
              'Primero selecciona la seccion para reservar el TAG.',
            );
          }
          final data = snapshot.data()!;
          final isAdmin = user.role == 'admin';
          if (!isAdmin && data['ownerUid'] != user.uid) {
            throw const SteamTrapStoreException(
              'No tienes permiso para editar este levantamiento.',
            );
          }
          transaction.update(document, {
            'zone': input.zone.trim(),
            'equipmentName': input.equipmentName.trim(),
            'equipmentNameNormalized': normalizeEquipmentName(
              input.equipmentName,
            ),
            'serviceId': input.serviceId,
            'serviceNameSnapshot': input.serviceName,
            'diameter': input.diameter,
            'trapTypeId': input.trapTypeId,
            'trapTypeNameSnapshot': input.trapTypeName,
            'condensateRecovery': input.condensateRecoveryId,
            'comments': input.comments.trim(),
            'diagnosisStatus': input.diagnosisStatus,
            'entryMode': input.mode == SteamTrapEntryMode.newEntry
                ? 'new_entry'
                : 'inventory_validation',
            'status': input.status,
            'closePhoto': input.closePhoto?.toJson(),
            'generalPhoto': input.generalPhoto?.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': user.uid,
            'appVersion': '${package.version}+${package.buildNumber}',
          });
        })
        .timeout(timeout);

    final confirmation = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!confirmation.exists ||
        confirmation.data()?['status'] != input.status) {
      throw const SteamTrapStoreException(
        'Firebase no confirmo el guardado del levantamiento.',
      );
    }
  }

  @override
  Future<List<SteamTrapRecord>> loadRecords() async {
    await _firebaseReady.timeout(timeout);
    final user = await _requireUser();
    final collection = _db.collection('steam_trap_records');
    if (user.role == 'admin') {
      final snapshot = await collection
          .orderBy('updatedAt', descending: true)
          .limit(500)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);
      return snapshot.docs.map(_record).toList(growable: false);
    }

    final queries = <Query<Map<String, dynamic>>>[
      collection.where('ownerUid', isEqualTo: user.uid),
      collection.where('isDemo', isEqualTo: true).where(
        'sharedWithUids',
        arrayContains: user.uid,
      ),
    ];
    if (user.companyId.isNotEmpty) {
      queries.add(collection.where('companyId', isEqualTo: user.companyId));
    }
    final snapshots = await Future.wait(
      queries.map(
        (query) => query
            .orderBy('updatedAt', descending: true)
            .limit(500)
            .get(const GetOptions(source: Source.server))
            .timeout(timeout),
      ),
    );
    final recordsById = <String, SteamTrapRecord>{};
    for (final snapshot in snapshots) {
      for (final document in snapshot.docs) {
        recordsById[document.id] = _record(document);
      }
    }
    final records = recordsById.values.toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  @override
  Future<void> correctSectionAsAdmin({
    required SteamTrapRecord record,
    required PlantSection section,
    required String reason,
  }) async {
    await _firebaseReady.timeout(timeout);
    final user = await _requireUser();
    if (user.role != 'admin') {
      throw const SteamTrapStoreException(
        'Solo un administrador puede corregir la seccion.',
      );
    }
    if (reason.trim().isEmpty) {
      throw const SteamTrapStoreException('Indica el motivo de la correccion.');
    }
    await _db
        .collection('steam_trap_records')
        .doc(record.id)
        .update({
          'sectionCode': section.code,
          'sectionId': section.id,
          'sectionNameSnapshot': section.displayName,
          'sectionHistory': FieldValue.arrayUnion([
            {
              'previousSectionCode': record.sectionCode,
              'newSectionCode': section.code,
              'reason': reason.trim(),
              'changedByUid': user.uid,
              'changedByNameSnapshot': user.displayName,
              'changedAt': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': user.uid,
        })
        .timeout(timeout);
  }

  Future<AuthenticatedOperator> _requireUser() async {
    final user = await _operatorSession.currentOperator();
    if (user == null) {
      throw const SteamTrapStoreException(
        'Inicia sesion como usuario para continuar.',
      );
    }
    return user;
  }

  SteamTrapRecord _record(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = Map<String, dynamic>.from(document.data()!);
    for (final key in ['createdAt', 'updatedAt']) {
      final value = data[key];
      if (value is Timestamp) data[key] = value.toDate();
    }
    for (final key in ['closePhoto', 'generalPhoto']) {
      final value = data[key];
      if (value is Map) {
        final photo = Map<String, dynamic>.from(value);
        final uploaded = photo['uploadedAt'];
        if (uploaded is Timestamp) {
          photo['uploadedAt'] = uploaded.toDate().toUtc().toIso8601String();
        }
        data[key] = photo;
      }
    }
    return SteamTrapRecord.fromJson(document.id, data);
  }
}
