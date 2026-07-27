import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/bare_pipe.dart';

abstract class ReportStore {
  Future<List<BarePipeReport>> loadReports();
  Future<void> saveReport(BarePipeReport report);
}

class ReportSyncException implements Exception {
  const ReportSyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HybridReportStore implements ReportStore {
  const HybridReportStore({
    required this.localStore,
    required this.remoteStore,
    this.remoteTimeout = const Duration(seconds: 10),
  });

  final ReportStore localStore;
  final ReportStore remoteStore;
  final Duration remoteTimeout;

  @override
  Future<List<BarePipeReport>> loadReports() async {
    final localReports = await localStore.loadReports();
    try {
      final remoteReports = await remoteStore.loadReports().timeout(
        remoteTimeout,
      );
      return _mergeReports(remoteReports, localReports);
    } catch (_) {
      return localReports;
    }
  }

  @override
  Future<void> saveReport(BarePipeReport report) async {
    try {
      await remoteStore.saveReport(report).timeout(remoteTimeout);
      await localStore.saveReport(report.copyWith(status: 'synced'));
    } on TimeoutException {
      await localStore.saveReport(
        report.copyWith(
          status: 'pending_sync',
          syncError: 'Firebase no respondio a tiempo.',
        ),
      );
      throw const ReportSyncException(
        'La evidencia se subio, pero la nube no confirmo el reporte. Quedo pendiente de sincronizacion y puede reintentarse.',
      );
    } catch (error) {
      await localStore.saveReport(
        report.copyWith(
          status: 'pending_sync',
          syncError: 'Firebase no confirmo el reporte.',
        ),
      );
      throw ReportSyncException(
        'La evidencia se subio, pero la nube no confirmo el reporte. Quedo pendiente de sincronizacion y puede reintentarse.',
      );
    }
  }

  List<BarePipeReport> _mergeReports(
    List<BarePipeReport> primary,
    List<BarePipeReport> secondary,
  ) {
    final byId = <String, BarePipeReport>{};
    for (final report in [...primary, ...secondary]) {
      byId[report.id] = report;
    }
    final reports = byId.values.toList();
    reports.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return reports;
  }
}

class LocalReportStore implements ReportStore {
  static const _key = 'eeBarePipeReports';

  @override
  Future<List<BarePipeReport>> loadReports() async {
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
      final reports = decoded
          .whereType<Map<String, dynamic>>()
          .map(BarePipeReport.fromJson)
          .where((report) => report.id.isNotEmpty)
          .toList();
      reports.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return reports;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveReport(BarePipeReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final reports = await loadReports();
    final deduped = reports.where((item) => item.id != report.id).toList();
    deduped.insert(0, report);
    final capped = deduped.take(500).map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(capped));
  }
}
