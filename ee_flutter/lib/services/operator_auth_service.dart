import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class OperatorAuthException implements Exception {
  const OperatorAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class OperatorAuthService {
  Future<void> register({
    required String fullName,
    required String nationalId,
    required String pin,
    required List<int> maintenanceZoneNumbers,
  });

  Future<void> signIn({required String nationalId, required String pin});

  Future<void> addMaintenanceZone({required int zoneNumber});

  Future<void> signOut();
}

class DisabledOperatorAuthService implements OperatorAuthService {
  const DisabledOperatorAuthService();

  @override
  Future<void> register({
    required String fullName,
    required String nationalId,
    required String pin,
    required List<int> maintenanceZoneNumbers,
  }) {
    throw const OperatorAuthException(
      'La autenticacion no esta disponible en este entorno.',
    );
  }

  @override
  Future<void> signIn({required String nationalId, required String pin}) {
    throw const OperatorAuthException(
      'La autenticacion no esta disponible en este entorno.',
    );
  }

  @override
  Future<void> addMaintenanceZone({required int zoneNumber}) {
    throw const OperatorAuthException(
      'La autenticacion no esta disponible en este entorno.',
    );
  }

  @override
  Future<void> signOut() async {}
}

String operatorEmailForNationalId(String nationalId) {
  return 'operator-${nationalId.trim()}@eficiencia-energetica-ee.app';
}

String firebasePasswordForPin(String pin) => 'Ee:$pin';

class FirebaseOperatorAuthService implements OperatorAuthService {
  FirebaseOperatorAuthService({
    required Future<FirebaseApp> firebaseReady,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 25),
  }) : _firebaseReady = firebaseReady,
       _auth = auth,
       _firestore = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final Duration timeout;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  FirebaseFirestore get _firebaseFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> register({
    required String fullName,
    required String nationalId,
    required String pin,
    required List<int> maintenanceZoneNumbers,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedNationalId = nationalId.trim();
    final normalizedZones = maintenanceZoneNumbers.toSet().toList()..sort();
    if (normalizedName.length < 3) {
      throw const OperatorAuthException('Ingresa tu nombre completo.');
    }
    if (!RegExp(r'^\d{10}$').hasMatch(normalizedNationalId)) {
      throw const OperatorAuthException('La cedula debe tener 10 digitos.');
    }
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const OperatorAuthException(
        'El PIN debe tener entre 4 y 6 digitos.',
      );
    }
    if (normalizedZones.isEmpty ||
        normalizedZones.any((zone) => zone < 1 || zone > 83)) {
      throw const OperatorAuthException('Selecciona al menos una zona valida.');
    }
    await _firebaseReady.timeout(timeout);
    User? createdUser;
    try {
      final credential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: operatorEmailForNationalId(normalizedNationalId),
            password: firebasePasswordForPin(pin),
          )
          .timeout(timeout);
      createdUser = credential.user;
      if (createdUser == null) {
        throw const OperatorAuthException(
          'Firebase no pudo crear la cuenta del usuario.',
        );
      }

      final cleanName = normalizedName;
      final cleanNationalId = normalizedNationalId;
      await createdUser.updateDisplayName(cleanName).timeout(timeout);
      final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
      await _firebaseFirestore
          .collection('users')
          .doc(createdUser.uid)
          .set({
            'id': createdUser.uid,
            'displayName': cleanName,
            'nationalId': cleanNationalId,
            'role': 'maintenance',
            'maintenanceZoneNumbers': normalizedZones,
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'createdByUid': createdUser.uid,
            'createdByNameSnapshot': cleanName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': createdUser.uid,
            'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
            'platform': kIsWeb ? 'web' : 'android',
            'schemaVersion': 1,
            'status': 'active',
            'source': 'self_registration',
          })
          .timeout(timeout);
    } on OperatorAuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      await _rollbackCreatedUser(createdUser);
      throw OperatorAuthException(
        _friendlyAuthMessage(error, registering: true),
      );
    } on FirebaseException catch (error) {
      await _rollbackCreatedUser(createdUser);
      throw OperatorAuthException(
        error.code == 'permission-denied'
            ? 'La cuenta se creo, pero Firebase rechazo el perfil. Las reglas de autorregistro aun no estan publicadas.'
            : 'La cuenta no pudo completar su perfil en Firebase (${error.code}).',
      );
    } catch (_) {
      await _rollbackCreatedUser(createdUser);
      throw const OperatorAuthException(
        'No fue posible conectar con Firebase. Revisa la conexion e intenta otra vez.',
      );
    }
  }

  @override
  Future<void> signIn({required String nationalId, required String pin}) async {
    await _firebaseReady.timeout(timeout);
    try {
      await _firebaseAuth
          .signInWithEmailAndPassword(
            email: operatorEmailForNationalId(nationalId),
            password: firebasePasswordForPin(pin),
          )
          .timeout(timeout);
    } on FirebaseAuthException catch (error) {
      throw OperatorAuthException(_friendlyAuthMessage(error));
    } catch (_) {
      throw const OperatorAuthException(
        'No fue posible conectar con Firebase. Revisa la conexion e intenta otra vez.',
      );
    }
  }

  @override
  Future<void> addMaintenanceZone({required int zoneNumber}) async {
    if (zoneNumber < 1 || zoneNumber > 83) {
      throw const OperatorAuthException('Selecciona una zona valida.');
    }
    await _firebaseReady.timeout(timeout);
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const OperatorAuthException(
        'Inicia sesion como usuario antes de agregar una zona.',
      );
    }
    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final profile = _firebaseFirestore.collection('users').doc(user.uid);
    try {
      await _firebaseFirestore
          .runTransaction<void>((transaction) async {
            final snapshot = await transaction.get(profile);
            final data = snapshot.data();
            if (!snapshot.exists || data?['role'] != 'maintenance') {
              throw const OperatorAuthException(
                'Solo el equipo de mantenimiento puede agregar zonas.',
              );
            }
            if (data?['active'] == false) {
              throw const OperatorAuthException(
                'Tu usuario esta inactivo y no puede agregar zonas.',
              );
            }
            final currentZones =
                (data?['maintenanceZoneNumbers'] is List
                        ? (data?['maintenanceZoneNumbers'] as List)
                              .whereType<num>()
                              .map((zone) => zone.toInt())
                        : <int>[])
                    .toSet()
                    .toList()
                  ..sort();
            if (currentZones.contains(zoneNumber)) {
              throw const OperatorAuthException(
                'Esa zona ya esta asociada a tu usuario.',
              );
            }
            if (currentZones.length >= 20) {
              throw const OperatorAuthException(
                'Tu usuario ya tiene el maximo de zonas permitido.',
              );
            }
            transaction.update(profile, {
              'maintenanceZoneNumbers': [...currentZones, zoneNumber]..sort(),
              'updatedAt': FieldValue.serverTimestamp(),
              'updatedByUid': user.uid,
              'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
              'platform': kIsWeb ? 'web' : 'android',
            });
          })
          .timeout(timeout);
    } on OperatorAuthException {
      rethrow;
    } on FirebaseException catch (error) {
      throw OperatorAuthException(
        error.code == 'permission-denied'
            ? 'Firebase rechazo el cambio de zonas. Actualiza la aplicacion e intenta nuevamente.'
            : 'No fue posible agregar la zona en Firebase (${error.code}).',
      );
    } on TimeoutException {
      throw const OperatorAuthException(
        'Firebase no respondio a tiempo. Revisa la conexion e intenta nuevamente.',
      );
    }
  }

  Future<void> _rollbackCreatedUser(User? user) async {
    if (user == null) return;
    try {
      await user.delete().timeout(timeout);
    } catch (_) {
      await _firebaseAuth.signOut();
    }
  }

  String _friendlyAuthMessage(
    FirebaseAuthException error, {
    bool registering = false,
  }) {
    return switch (error.code) {
      'email-already-in-use' =>
        'Ya existe un usuario registrado con esa cedula.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Cedula o PIN incorrectos.',
      'too-many-requests' =>
        'Demasiados intentos. Espera unos minutos antes de reintentar.',
      'network-request-failed' =>
        'No hay conexion con Firebase. Revisa internet e intenta otra vez.',
      'operation-not-allowed' =>
        'El acceso por cedula y PIN aun no esta habilitado en Firebase Auth.',
      'channel-error' =>
        'La autenticacion no se cargo correctamente. Cierra y vuelve a abrir la aplicacion.',
      'weak-password' when registering =>
        'El PIN no cumple los requisitos de Firebase.',
      _ =>
        registering
            ? 'Firebase no pudo registrar al usuario (${error.code}).'
            : 'Firebase no pudo iniciar la sesion (${error.code}).',
    };
  }

  @override
  Future<void> signOut() async {
    await _firebaseReady.timeout(timeout);
    await _firebaseAuth.signOut();
  }
}
