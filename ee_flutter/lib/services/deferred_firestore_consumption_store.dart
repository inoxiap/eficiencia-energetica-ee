import 'package:firebase_core/firebase_core.dart';

import '../domain/boiler_consumption.dart';
import 'consumption_store.dart';
import 'firestore_consumption_store.dart';
import 'operator_session.dart';

class DeferredFirestoreConsumptionStore
    implements ConsumptionStore, PagedConsumptionStore {
  DeferredFirestoreConsumptionStore({
    required Future<FirebaseApp> firebaseReady,
    required OperatorSession operatorSession,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady,
       _operatorSession = operatorSession;

  final Future<FirebaseApp> _firebaseReady;
  final Duration timeout;
  final OperatorSession _operatorSession;
  FirestoreConsumptionStore? _remoteStore;

  Future<FirestoreConsumptionStore> get _remote async {
    await _firebaseReady.timeout(timeout);
    return _remoteStore ??= FirestoreConsumptionStore(
      operatorSession: _operatorSession,
    );
  }

  @override
  Future<List<BoilerReading>> loadReadings() async {
    return (await _remote).loadReadings();
  }

  @override
  Future<ConsumptionPage> loadFirstPage({int limit = 100}) async {
    return (await _remote).loadFirstPage(limit: limit);
  }

  @override
  Future<ConsumptionPage> loadNextPage({int limit = 100}) async {
    return (await _remote).loadNextPage(limit: limit);
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    return (await _remote).saveReading(reading);
  }
}
