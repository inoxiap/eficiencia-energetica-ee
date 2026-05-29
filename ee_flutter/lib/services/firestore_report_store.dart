import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/bare_pipe.dart';
import 'report_store.dart';

class FirestoreReportStore implements ReportStore {
  FirestoreReportStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
    await _reports.doc(report.id).set(report.toJson());
  }
}
