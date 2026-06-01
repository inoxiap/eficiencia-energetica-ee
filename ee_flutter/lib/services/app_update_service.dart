import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateNotice {
  const AppUpdateNotice({
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.message,
    required this.updateUrl,
    required this.forceUpdate,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final String latestVersion;
  final int latestBuildNumber;
  final String message;
  final String updateUrl;
  final bool forceUpdate;
}

class AppUpdateService {
  AppUpdateService({
    required Future<FirebaseApp> firebaseReady,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady,
       _firestore = firestore,
       _disabled = false;

  const AppUpdateService.disabled()
    : _firebaseReady = null,
      _firestore = null,
      timeout = Duration.zero,
      _disabled = true;

  final Future<FirebaseApp>? _firebaseReady;
  final FirebaseFirestore? _firestore;
  final Duration timeout;
  final bool _disabled;

  bool get isDisabled => _disabled;

  Future<AppUpdateNotice?> checkForUpdate() async {
    if (_disabled) {
      return null;
    }

    final firebaseReady = _firebaseReady;
    if (firebaseReady == null) {
      return null;
    }

    try {
      await firebaseReady.timeout(timeout);
      final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
      final snapshot = await (_firestore ?? FirebaseFirestore.instance)
          .collection('app_config')
          .doc('mobile_app')
          .get()
          .timeout(timeout);

      final data = snapshot.data();
      if (data == null || data['enabled'] == false) {
        return null;
      }

      final latestBuildNumber =
          _toInt(data['latestBuildNumber']) ?? currentBuildNumber;
      if (latestBuildNumber <= currentBuildNumber) {
        return null;
      }

      final minSupportedBuildNumber = _toInt(data['minSupportedBuildNumber']);
      final updateUrl = (data['updateUrl'] as String? ?? '').trim();
      return AppUpdateNotice(
        currentVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
        currentBuildNumber: currentBuildNumber,
        latestVersion:
            (data['latestVersion'] as String? ?? latestBuildNumber.toString())
                .trim(),
        latestBuildNumber: latestBuildNumber,
        message:
            (data['message'] as String? ??
                    'Hay una nueva version disponible de Eficiencia Energetica EE.')
                .trim(),
        updateUrl: updateUrl,
        forceUpdate:
            data['forceUpdate'] == true ||
            (minSupportedBuildNumber != null &&
                currentBuildNumber < minSupportedBuildNumber),
      );
    } catch (_) {
      return null;
    }
  }

  static int? _toInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
