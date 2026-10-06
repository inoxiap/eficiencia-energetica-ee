import 'boiler_consumption.dart';

class NormalizedBoilerHour {
  const NormalizedBoilerHour({
    required this.hourEnd,
    required this.bunkerGallons,
    required this.waterGallons,
    required this.steamKg,
    required this.boilerPressurePsi,
    required this.operatorName,
  });

  /// UTC instant marking the end of this complete Guayaquil hour.
  final DateTime hourEnd;
  final double? bunkerGallons;
  final double? waterGallons;
  final double? steamKg;
  final double? boilerPressurePsi;
  final String operatorName;
}

class BoilerHourlyNormalizer {
  const BoilerHourlyNormalizer._();

  static List<NormalizedBoilerHour> normalize(Iterable<BoilerReading> source) {
    final latestByRecord = <String, BoilerReading>{};
    for (final reading in source.where(
      (item) => item.readingMode == 'cumulative_meter',
    )) {
      final recordKey = reading.rootRecordId ?? reading.id;
      final previous = latestByRecord[recordKey];
      if (previous == null ||
          reading.revision > previous.revision ||
          (reading.revision == previous.revision &&
              reading.recordedAt.isAfter(previous.recordedAt))) {
        latestByRecord[recordKey] = reading;
      }
    }

    final readings = latestByRecord.values.toList()
      ..sort((left, right) => left.recordedAt.compareTo(right.recordedAt));
    if (readings.length < 2) return const [];

    final firstAt = readings.first.recordedAt.toUtc();
    final lastAt = readings.last.recordedAt.toUtc();
    final buckets = <_HourAccumulator>[];
    final bucketsByEnd = <DateTime, _HourAccumulator>{};
    var hourEnd = guayaquilHourStart(lastAt);
    final firstHourEnd = guayaquilHourStart(
      firstAt,
    ).add(const Duration(hours: 1));
    while (!hourEnd.isBefore(firstHourEnd)) {
      final bucket = _HourAccumulator(hourEnd);
      buckets.add(bucket);
      bucketsByEnd[hourEnd] = bucket;
      hourEnd = hourEnd.subtract(const Duration(hours: 1));
    }
    if (buckets.isEmpty) return const [];

    for (final metric in _Metric.values) {
      final metricReadings = readings
          .map((reading) => _MetricReading(reading, metric.valueOf(reading)))
          .where((point) => point.value != null)
          .toList(growable: false);

      // A missing value in one snapshot must not break interpolation for that
      // meter. Bridge only null samples; decreasing cumulative values still
      // invalidate the affected interval in _HourAccumulator.add.
      for (var index = 1; index < metricReadings.length; index++) {
        final previous = metricReadings[index - 1];
        final current = metricReadings[index];
        final intervalStart = previous.reading.recordedAt.toUtc();
        final intervalEnd = current.reading.recordedAt.toUtc();
        final intervalMs = intervalEnd.difference(intervalStart).inMilliseconds;
        if (intervalMs <= 0) continue;

        var bucketEnd = guayaquilHourStart(intervalEnd);
        if (intervalEnd.isAfter(bucketEnd)) {
          bucketEnd = bucketEnd.add(const Duration(hours: 1));
        }
        while (bucketEnd.isAfter(intervalStart)) {
          final bucket = bucketsByEnd[bucketEnd];
          if (bucket != null) {
            final bucketStart = bucketEnd.subtract(const Duration(hours: 1));
            final overlapStart = intervalStart.isAfter(bucketStart)
                ? intervalStart
                : bucketStart;
            final overlapEnd = intervalEnd.isBefore(bucketEnd)
                ? intervalEnd
                : bucketEnd;
            final overlapMs = overlapEnd
                .difference(overlapStart)
                .inMilliseconds;
            if (overlapMs > 0) {
              bucket.add(
                metric,
                previous.value,
                current.value,
                overlapMs,
                intervalMs,
                currentReading: current.reading,
              );
            }
          }
          bucketEnd = bucketEnd.subtract(const Duration(hours: 1));
        }
      }
    }

    return buckets.map((bucket) => bucket.toReading()).toList(growable: false);
  }
}

enum _Metric { bunker, water, steam }

extension on _Metric {
  double? valueOf(BoilerReading reading) {
    final (inputName, canonicalName, fallback) = switch (this) {
      _Metric.bunker => ('bunker', 'gallons', reading.fuelTotal),
      _Metric.water => ('water', 'gallons', reading.waterTotal),
      _Metric.steam => ('steam', 'kilograms', reading.steamTotal),
    };
    final input = reading.originalInputs[inputName];
    if (input is Map) {
      final raw = input['value'];
      final rawValue = raw is num ? raw.toDouble() : double.tryParse('$raw');
      final unit = input['unit']?.toString();
      if (rawValue != null) {
        final enteredValue = switch ((this, unit)) {
          (_Metric.bunker, 'gal') => rawValue,
          (_Metric.bunker, 'L') => rawValue / alfaBunkerLitersPerGallon,
          (_Metric.water, 'gal') => rawValue,
          (_Metric.water, 'counter_x10_L') =>
            rawValue * alfaWaterGallonsPerLiter,
          (_Metric.water, 'L') => rawValue * alfaWaterGallonsPerLiter,
          (_Metric.steam, 'kg') => rawValue,
          _ => null,
        };
        if (enteredValue != null) return enteredValue;
      }
      final canonical = input[canonicalName];
      if (canonical is num) return canonical.toDouble();
      final parsed = double.tryParse('$canonical');
      if (parsed != null) return parsed;
    }
    return fallback;
  }
}

class _MetricReading {
  const _MetricReading(this.reading, this.value);

  final BoilerReading reading;
  final double? value;
}

class _HourAccumulator {
  _HourAccumulator(this.hourEnd);

  static const _hourMs = Duration.millisecondsPerHour;

  final DateTime hourEnd;
  final Map<_Metric, double> _values = {};
  final Map<_Metric, int> _coverageMs = {};
  BoilerReading? _referenceReading;

  void add(
    _Metric metric,
    double? previous,
    double? current,
    int overlapMs,
    int intervalMs, {
    required BoilerReading currentReading,
  }) {
    if (previous == null || current == null || current < previous) return;
    _referenceReading =
        _referenceReading == null ||
            currentReading.recordedAt.isAfter(_referenceReading!.recordedAt)
        ? currentReading
        : _referenceReading;
    _values[metric] =
        (_values[metric] ?? 0) + (current - previous) * overlapMs / intervalMs;
    _coverageMs[metric] = (_coverageMs[metric] ?? 0) + overlapMs;
  }

  double? _hourlyEstimate(_Metric metric) {
    final coverage = _coverageMs[metric];
    final observedConsumption = _values[metric];
    if (coverage == null || coverage <= 0 || observedConsumption == null) {
      return null;
    }
    return observedConsumption * _hourMs / coverage;
  }

  NormalizedBoilerHour toReading() => NormalizedBoilerHour(
    hourEnd: hourEnd,
    bunkerGallons: _hourlyEstimate(_Metric.bunker),
    waterGallons: _hourlyEstimate(_Metric.water),
    steamKg: _hourlyEstimate(_Metric.steam) == null
        ? null
        : _hourlyEstimate(_Metric.steam)! * alfaSteamNormalizedMultiplier,
    boilerPressurePsi: _referenceReading?.boilerPressurePsi,
    operatorName: _referenceReading?.createdByNameSnapshot ?? '',
  );
}
