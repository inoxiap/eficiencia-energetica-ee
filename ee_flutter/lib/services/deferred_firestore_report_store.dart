import 'package:firebase_core/firebase_core.dart';

import '../domain/bare_pipe.dart';
import 'firestore_report_store.dart';
import 'operator_session.dart';
import 'report_store.dart';

class DeferredFirestoreReportStore implements ReportStore {
  DeferredFirestoreReportStore({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady,
       _operatorSession = operatorSession;

  final Future<FirebaseApp> _firebaseReady;
  final Duration timeout;
  final OperatorSession _operatorSession;
  FirestoreReportStore? _remoteStore;

  Future<FirestoreReportStore> get _remote async {
    await _firebaseReady.timeout(timeout);
    return _remoteStore ??= FirestoreReportStore(
      operatorSession: _operatorSession,
    );
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
