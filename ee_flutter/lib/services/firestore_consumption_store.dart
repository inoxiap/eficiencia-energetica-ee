import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/boiler_consumption.dart';
import 'consumption_store.dart';

class FirestoreConsumptionStore implements ConsumptionStore {
  FirestoreConsumptionStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _readings =>
      _firestore.collection('boiler_consumption_readings');

  @override
  Future<List<BoilerReading>> loadReadings() async {
    final snapshot = await _readings
        .orderBy('recordedAt', descending: true)
        .limit(10000)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = data['id'] ?? doc.id;
      return BoilerReading.fromJson(data);
    }).toList();
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    await _readings.doc(reading.id).set(reading.toJson());
  }
}
