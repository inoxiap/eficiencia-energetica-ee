import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../domain/leak_report.dart';
import '../domain/maintenance_report.dart';
import 'operator_session.dart';

class MaintenanceReportException implements Exception {
  const MaintenanceReportException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MaintenanceReportStore {
  Future<String> saveLeakReport(LeakReport report);

  Future<List<MaintenanceReportSummary>> loadReports();

  Future<void> updateWorkflow({
    required MaintenanceReportSummary report,
    required bool workOrderCreated,
    required bool workCompleted,
  });
}

class DisabledMaintenanceReportStore implements MaintenanceReportStore {
  const DisabledMaintenanceReportStore();

  @override
  Future<List<MaintenanceReportSummary>> loadReports() async => const [];

  @override
  Future<String> saveLeakReport(LeakReport report) {
    throw const MaintenanceReportException(
      'El guardado de fugas no esta disponible.',
    );
  }

  @override
  Future<void> updateWorkflow({
    required MaintenanceReportSummary report,
    required bool workOrderCreated,
    required bool workCompleted,
  }) {
    throw const MaintenanceReportException(
      'El seguimiento no esta disponible.',
    );
  }
}

class FirebaseMaintenanceReportStore implements MaintenanceReportStore {
  FirebaseMaintenanceReportStore({
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

  FirebaseFirestore get _firebaseFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> saveLeakReport(LeakReport report) async {
    await _firebaseReady.timeout(timeout);
    final operator = await _requireOperator();
    final packageInfo = await PackageInfo.fromPlatform().timeout(timeout);
    final document = _firebaseFirestore
        .collection('leak_reports')
        .doc(report.id);
    final counter = _firebaseFirestore
        .collection('maintenance_counters')
        .doc('leak_reports');
    final tagNumber = await _firebaseFirestore
        .runTransaction<String>((transaction) async {
          final existing = await transaction.get(document);
          if (existing.exists) {
            final data = existing.data();
            if (data?['createdByUid'] != operator.uid) {
              throw const MaintenanceReportException(
                'El identificador del reporte ya esta en uso.',
              );
            }
            final existingTag = data?['tagNumber'] as String? ?? '';
            if (existingTag.isEmpty) {
              throw const MaintenanceReportException(
                'El reporte existente no tiene identificacion.',
              );
            }
            return existingTag;
          }

          final counterSnapshot = await transaction.get(counter);
          final previous = counterSnapshot.data()?['nextNumber'];
          final nextNumber = previous is int ? previous + 1 : 1;
          final nextTag = 'F-${nextNumber.toString().padLeft(6, '0')}';
          final data = report.toJson();
          data.addAll({
            'leakNumber': nextNumber,
            'tagNumber': nextTag,
            'createdAt': FieldValue.serverTimestamp(),
            'createdByUid': operator.uid,
            'createdByNameSnapshot': operator.displayName,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': operator.uid,
            'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
            'platform': kIsWeb ? 'web' : 'android',
            'source': 'manual',
          });
          transaction.set(counter, {
            'nextNumber': nextNumber,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedByUid': operator.uid,
          });
          transaction.set(document, data);
          return nextTag;
        })
        .timeout(timeout);
    final confirmation = await document
        .get(const GetOptions(source: Source.server))
        .timeout(timeout);
    if (!confirmation.exists) {
      throw const MaintenanceReportException(
        'Firebase no confirmo el reporte de fuga.',
      );
    }
    return tagNumber;
  }

  @override
  Future<List<MaintenanceReportSummary>> loadReports() async {
    await _firebaseReady.timeout(timeout);
    await _requireOperator();
    final results = await Future.wait([
      _firebaseFirestore
          .collection('leak_reports')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get(),
      _firebaseFirestore
          .collection('bare_pipe_reports')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .get(),
    ]).timeout(timeout);

    final reports = <MaintenanceReportSummary>[
      ...results[0].docs.map(
        (document) => _summaryFromLeak(document.id, document.data()),
      ),
      ...results[1].docs.map(
        (document) => _summaryFromBarePipe(document.id, document.data()),
      ),
    ];
    reports.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return reports;
  }

  @override
  Future<void> updateWorkflow({
    required MaintenanceReportSummary report,
    required bool workOrderCreated,
    required bool workCompleted,
  }) async {
    await _firebaseReady.timeout(timeout);
    final operator = await _requireOperator();
    final normalizedCompleted = workOrderCreated && workCompleted;
    final status = normalizedCompleted
        ? 'completed'
        : workOrderCreated
        ? 'work_order_created'
        : 'open';
    final collection = report.type == MaintenanceReportType.leak
        ? 'leak_reports'
        : 'bare_pipe_reports';
    await _firebaseFirestore
        .collection(collection)
        .doc(report.id)
        .update({
          'workOrderCreated': workOrderCreated,
          'workOrderCreatedAt': workOrderCreated
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
          'workOrderCreatedByUid': workOrderCreated
              ? operator.uid
              : FieldValue.delete(),
          'workOrderCreatedByNameSnapshot': workOrderCreated
              ? operator.displayName
              : FieldValue.delete(),
          'workCompleted': normalizedCompleted,
          'workCompletedAt': normalizedCompleted
              ? FieldValue.serverTimestamp()
              : FieldValue.delete(),
          'workCompletedByUid': normalizedCompleted
              ? operator.uid
              : FieldValue.delete(),
          'workCompletedByNameSnapshot': normalizedCompleted
              ? operator.displayName
              : FieldValue.delete(),
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedByUid': operator.uid,
        })
        .timeout(timeout);
  }

  Future<AuthenticatedOperator> _requireOperator() async {
    final operator = await _operatorSession.currentOperator();
    if (operator == null) {
      throw const MaintenanceReportException(
        'Inicia sesion como usuario para continuar.',
      );
    }
    return operator;
  }

  MaintenanceReportSummary _summaryFromLeak(
    String id,
    Map<String, dynamic> data,
  ) {
    final type = leakTypeById(data['leakType'] as String? ?? '');
    final tag = (data['tagNumber'] as String? ?? '').trim();
    final typeName =
        (data['leakTypeNameSnapshot'] as String? ?? '').trim().isNotEmpty
        ? data['leakTypeNameSnapshot'] as String
        : type?.displayName ?? 'Sin tipo';
    final equipmentName = (data['equipmentName'] as String? ?? '').trim();
    final locationReference = (data['locationReference'] as String? ?? '')
        .trim();
    return MaintenanceReportSummary(
      id: id,
      type: MaintenanceReportType.leak,
      createdAt: _toDateTime(data['createdAt'], data['capturedAtLocal']),
      sectionName: _sectionName(data),
      equipmentName: equipmentName.isNotEmpty
          ? equipmentName
          : locationReference,
      detail: tag.isEmpty ? 'Fuga de $typeName' : 'Fuga de $typeName - N. $tag',
      photoUrl: data['photoUrl'] as String? ?? '',
      createdByName: data['createdByNameSnapshot'] as String? ?? 'Historico',
      workOrderCreated: data['workOrderCreated'] == true,
      workCompleted: data['workCompleted'] == true,
      status: data['status'] as String? ?? 'open',
    );
  }

  MaintenanceReportSummary _summaryFromBarePipe(
    String id,
    Map<String, dynamic> data,
  ) {
    final diameter = data['diameterLabel'] as String? ?? '';
    final length = _number(data['lengthMeters'] ?? data['lengthValue']);
    final details = <String>[
      if (diameter.isNotEmpty) 'Tuberia $diameter',
      if (length != null) '${length.toStringAsFixed(2)} m',
    ];
    return MaintenanceReportSummary(
      id: id,
      type: MaintenanceReportType.barePipe,
      createdAt: _toDateTime(data['createdAt'], data['capturedAtLocal']),
      sectionName: _sectionName(data),
      equipmentName: data['equipmentName'] as String? ?? '',
      detail: details.isEmpty ? 'Tuberia desnuda' : details.join(' - '),
      photoUrl: data['photoUrl'] as String? ?? '',
      createdByName: data['createdByNameSnapshot'] as String? ?? 'Historico',
      workOrderCreated: data['workOrderCreated'] == true,
      workCompleted: data['workCompleted'] == true,
      status: data['status'] as String? ?? 'open',
    );
  }

  String _sectionName(Map<String, dynamic> data) {
    return data['sectionNameSnapshot'] as String? ??
        data['section'] as String? ??
        'Sin seccion';
  }

  DateTime _toDateTime(Object? primary, Object? fallback) {
    for (final value in [primary, fallback]) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double? _number(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
