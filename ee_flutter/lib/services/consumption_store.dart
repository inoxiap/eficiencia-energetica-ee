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

class DuplicateBoilerReadingException implements Exception {
  const DuplicateBoilerReadingException(this.message);

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
    var localReadings = await localStore.loadReadings();
    await _retryPendingReadings(localReadings);
    localReadings = await localStore.loadReadings();
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
    try {
      await remoteStore.saveReading(reading).timeout(remoteTimeout);
      await localStore.saveReading(reading.copyWith(status: 'synced'));
    } on DuplicateBoilerReadingException {
      rethrow;
    } on TimeoutException {
      await localStore.saveReading(reading.copyWith(status: 'pending_sync'));
      throw const ConsumptionSyncException(
        'La nube no confirmo la lectura. Quedo pendiente de sincronizacion.',
      );
    } catch (_) {
      await localStore.saveReading(reading.copyWith(status: 'pending_sync'));
      throw const ConsumptionSyncException(
        'La nube no confirmo la lectura. Quedo pendiente de sincronizacion.',
      );
    }
  }

  Future<void> _retryPendingReadings(List<BoilerReading> readings) async {
    final pending =
        readings.where((reading) => reading.status == 'pending_sync').toList()
          ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    for (final reading in pending) {
      try {
        await remoteStore.saveReading(reading).timeout(remoteTimeout);
        await localStore.saveReading(reading.copyWith(status: 'synced'));
      } on DuplicateBoilerReadingException {
        await localStore.saveReading(reading.copyWith(status: 'synced'));
      } catch (_) {
        // Pending data remains local and will be retried on the next load.
      }
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
  static const _syncedReadingLimit = 500;

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
      var readings = decoded
          .whereType<Map<String, dynamic>>()
          .map(BoilerReading.fromJson)
          .where((reading) => reading.id.isNotEmpty)
          .toList();
      if (readings.any((reading) => reading.operatorPin.isNotEmpty)) {
        readings = readings
            .map((reading) => reading.copyWith(clearOperatorPin: true))
            .toList();
        await prefs.setString(
          _key,
          jsonEncode(readings.map((reading) => reading.toJson()).toList()),
        );
      }
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
    final pending = deduped
        .where((item) => item.status == 'pending_sync')
        .toList();
    final synced = deduped
        .where((item) => item.status != 'pending_sync')
        .take(_syncedReadingLimit);
    final retained = <BoilerReading>[...pending, ...synced];
    retained.sort((left, right) => right.recordedAt.compareTo(left.recordedAt));
    final capped = retained.map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(capped));
  }
}
