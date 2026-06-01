import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/boiler_consumption.dart';

abstract class ConsumptionStore {
  Future<List<BoilerReading>> loadReadings();
  Future<void> saveReading(BoilerReading reading);
}

class ConsumptionSyncException implements Exception {
  const ConsumptionSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HybridConsumptionStore implements ConsumptionStore {
  const HybridConsumptionStore({
    required this.localStore,
    required this.remoteStore,
    this.remoteTimeout = const Duration(seconds: 10),
  });

  final ConsumptionStore localStore;
  final ConsumptionStore remoteStore;
  final Duration remoteTimeout;

  @override
  Future<List<BoilerReading>> loadReadings() async {
    final localReadings = await localStore.loadReadings();
    try {
      final remoteReadings = await remoteStore.loadReadings().timeout(
        remoteTimeout,
      );
      return _mergeReadings(remoteReadings, localReadings);
    } catch (_) {
      return localReadings;
    }
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    await localStore.saveReading(reading);
    try {
      await remoteStore.saveReading(reading).timeout(remoteTimeout);
    } on TimeoutException {
      throw const ConsumptionSyncException(
        'Lectura guardada en este telefono. Firebase no respondio a tiempo; revisa Cloud Firestore.',
      );
    } catch (_) {
      throw const ConsumptionSyncException(
        'Lectura guardada en este telefono. Firebase no sincronizo; revisa Cloud Firestore.',
      );
    }
  }

  List<BoilerReading> _mergeReadings(
    List<BoilerReading> primary,
    List<BoilerReading> secondary,
  ) {
    final byId = <String, BoilerReading>{};
    for (final reading in [...primary, ...secondary]) {
      byId[reading.id] = reading;
    }
    final readings = byId.values.toList();
    readings.sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    return readings;
  }
}

class LocalConsumptionStore implements ConsumptionStore {
  static const _key = 'eeBoilerConsumptionReadings';

  @override
  Future<List<BoilerReading>> loadReadings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return [];
      }
      final readings = decoded
          .whereType<Map<String, dynamic>>()
          .map(BoilerReading.fromJson)
          .where((reading) => reading.id.isNotEmpty)
          .toList();
      readings.sort(
        (left, right) => right.recordedAt.compareTo(left.recordedAt),
      );
      return readings;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveReading(BoilerReading reading) async {
    final prefs = await SharedPreferences.getInstance();
    final readings = await loadReadings();
    final deduped = readings.where((item) => item.id != reading.id).toList();
    deduped.insert(0, reading);
    final capped = deduped.take(2000).map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(capped));
  }
}
