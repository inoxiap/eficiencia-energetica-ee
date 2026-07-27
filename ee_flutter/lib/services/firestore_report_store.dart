import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/bare_pipe.dart';
import 'operator_session.dart';
import 'report_store.dart';

class FirestoreReportStore implements ReportStore {
  FirestoreReportStore({
    required OperatorSession operatorSession,
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 20),
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _operatorSession = operatorSession;

  final FirebaseFirestore _firestore;
  final OperatorSession _operatorSession;
  final Duration timeout;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('bare_pipe_reports');

  @override
  Future<List<BarePipeReport>> loadReports() async {
    final snapshot = await _reports
        .orderBy('createdAt', descending: true)
        .limit(500)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = data['id'] ?? doc.id;
      return BarePipeReport.fromJson(data);
    }).toList();
  }

  Stream<List<BarePipeReport>> watchReports() {
    return _reports
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = data['id'] ?? doc.id;
            return BarePipeReport.fromJson(data);
          }).toList();
        });
  }

  @override
  Future<void> saveReport(BarePipeReport report) async {
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const ReportSyncException(
        'Inicia sesion como usuario antes de guardar el reporte.',
      );
    }

    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final data = report.toJson();
    data['capturedAtLocal'] = report.createdAt.toUtc().toIso8601String();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['createdByUid'] = operator.uid;
    data['createdByNameSnapshot'] = operator.displayName;
    data['updatedAt'] = FieldValue.serverTimestamp();
    data['updatedByUid'] = operator.uid;
    data['source'] = 'manual';
    data['status'] = 'synced';
    data['workOrderCreated'] = false;
    data['workCompleted'] = false;
    data['appVersion'] = '${packageInfo.version}+${packageInfo.buildNumber}';
    data['platform'] = kIsWeb ? 'web' : 'android';
    data.remove('syncError');

    final document = _reports.doc(report.id);
    await document.set(data).timeout(timeout);
    final confirmation = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!confirmation.exists) {
      throw const ReportSyncException(
        'La nube no confirmo el reporte de tuberia.',
      );
    }
  }
}
