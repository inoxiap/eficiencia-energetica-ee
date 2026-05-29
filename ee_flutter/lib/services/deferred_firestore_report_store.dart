import 'package:firebase_core/firebase_core.dart';

import '../domain/bare_pipe.dart';
import 'firestore_report_store.dart';
import 'report_store.dart';

class DeferredFirestoreReportStore implements ReportStore {
  DeferredFirestoreReportStore({
    required Future<FirebaseApp> firebaseReady,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady;

  final Future<FirebaseApp> _firebaseReady;
  final Duration timeout;
  FirestoreReportStore? _remoteStore;

  Future<FirestoreReportStore> get _remote async {
    await _firebaseReady.timeout(timeout);
    return _remoteStore ??= FirestoreReportStore();
  }

  @override
  Future<List<BarePipeReport>> loadReports() async {
    return (await _remote).loadReports();
  }

  @override
  Future<void> saveReport(BarePipeReport report) async {
    return (await _remote).saveReport(report);
  }
}
