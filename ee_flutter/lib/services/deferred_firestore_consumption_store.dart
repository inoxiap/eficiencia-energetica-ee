import 'package:firebase_core/firebase_core.dart';

import '../domain/boiler_consumption.dart';
import 'consumption_store.dart';
import 'firestore_consumption_store.dart';

class DeferredFirestoreConsumptionStore implements ConsumptionStore {
  DeferredFirestoreConsumptionStore({
    required Future<FirebaseApp> firebaseReady,
    this.timeout = const Duration(seconds: 8),
  }) : _firebaseReady = firebaseReady;

  final Future<FirebaseApp> _firebaseReady;
  final Duration timeout;
  FirestoreConsumptionStore? _remoteStore;

  Future<FirestoreConsumptionStore> get _remote async {
    await _firebaseReady.timeout(timeout);
    return _remoteStore ??= FirestoreConsumptionStore();
  }

  @override
  Future<List<BoilerReading>> loadReadings() async {
    return (await _remote).loadReadings();
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    return (await _remote).saveReading(reading);
  }
}
