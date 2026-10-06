import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'operator_session.dart';

class PushNotificationService {
  PushNotificationService({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _firebaseReady = firebaseReady,
       _operatorSession = operatorSession,
       _messagingOverride = messaging,
       _authOverride = auth,
       _firestoreOverride = firestore;

  final Future<FirebaseApp> _firebaseReady;
  final OperatorSession _operatorSession;
  final FirebaseMessaging? _messagingOverride;
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> initialize() async {
    if (kIsWeb) return;
    await _firebaseReady;
    _messaging.onTokenRefresh.listen(_syncCurrentToken);
    Future<void> registerAuthenticatedDevice(User? user) async {
      if (user == null) return;
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await _syncCurrentToken(await _messaging.getToken());
    }

    _auth.userChanges().listen(registerAuthenticatedDevice);
    await registerAuthenticatedDevice(_auth.currentUser);
  }

  Future<void> _syncCurrentToken(String? token) async {
    if (token == null || token.trim().isEmpty) return;
    final operator = await _operatorSession.currentOperator();
    if (operator == null) return;
    final packageInfo = await PackageInfo.fromPlatform();
    final tokenId = base64Url
        .encode(utf8.encode(token))
        .replaceAll('=', '')
        .replaceAll('/', '_');
    await _firestore.collection('notification_tokens').doc(tokenId).set({
      'id': tokenId,
      'uid': operator.uid,
      'token': token,
      'platform': 'android',
      'active': true,
      'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
