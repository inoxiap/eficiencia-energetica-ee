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
  });

  Future<void> signIn({required String nationalId, required String pin});

  Future<void> signOut();
}

class DisabledOperatorAuthService implements OperatorAuthService {
  const DisabledOperatorAuthService();

  @override
  Future<void> register({
    required String fullName,
    required String nationalId,
    required String pin,
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
  }) async {
    await _firebaseReady.timeout(timeout);
    User? createdUser;
    try {
      final credential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: operatorEmailForNationalId(nationalId),
            password: firebasePasswordForPin(pin),
          )
          .timeout(timeout);
      createdUser = credential.user;
      if (createdUser == null) {
        throw const OperatorAuthException(
          'Firebase no pudo crear la cuenta del usuario.',
        );
      }

      final cleanName = fullName.trim();
      final cleanNationalId = nationalId.trim();
      await createdUser.updateDisplayName(cleanName).timeout(timeout);
      final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
      await _firebaseFirestore
          .collection('users')
          .doc(createdUser.uid)
          .set({
            'id': createdUser.uid,
            'displayName': cleanName,
            'nationalId': cleanNationalId,
            'role': 'operator',
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
        'La cuenta no pudo completar su perfil en Firebase (${error.code}).',
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
