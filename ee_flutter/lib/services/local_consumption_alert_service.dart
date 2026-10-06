import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/boiler_consumption.dart';
import '../domain/boiler_hourly_normalization.dart';
import 'consumption_store.dart';

class LocalConsumptionAlertService with WidgetsBindingObserver {
  LocalConsumptionAlertService({required this.consumptionStore});

  static const _channelId = 'boiler_consumption_alerts';
  static const _lastCheckKey = 'boilerConsumptionAlertLastCheck';
  static const _sentPrefix = 'boilerConsumptionAlertSent_';

  final ConsumptionStore consumptionStore;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _checking = false;

  Future<void> initialize() async {
    if (kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
    _ready = true;
    WidgetsBinding.instance.addObserver(this);
    await checkNow();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkNow());
    }
  }

  Future<void> checkNow() async {
    if (!_ready || _checking) return;
    _checking = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      final lastCheck =
          DateTime.tryParse(prefs.getString(_lastCheckKey) ?? '') ??
          now.subtract(const Duration(hours: 2));
      final pagedStore = consumptionStore is PagedConsumptionStore
          ? consumptionStore as PagedConsumptionStore
          : null;
      final readings = pagedStore == null
          ? await consumptionStore.loadReadings()
          : (await pagedStore.loadFirstPage(limit: 100)).readings;
      for (final boiler in boilerDefinitions) {
        final normalized = BoilerHourlyNormalizer.normalize(
          readings.where((item) => item.effectiveBoilerId == boiler.id),
        );
        for (final hour in normalized) {
          if (!hour.hourEnd.isAfter(lastCheck) || hour.hourEnd.isAfter(now)) {
            continue;
          }
          final threshold = _thresholdFor(boiler.id, hour.boilerPressurePsi);
          if (threshold == null ||
              hour.bunkerGallons == null ||
              hour.bunkerGallons! <= threshold) {
            continue;
          }
          final hourKey = '${boiler.id}_${hour.hourEnd.toIso8601String()}';
          if (prefs.getBool('$_sentPrefix$hourKey') == true) continue;
          await _notifications.show(
            id: hourKey.hashCode & 0x7fffffff,
            title: 'Alerta de consumo de bunker',
            body:
                '${boiler.displayName}: ${hour.bunkerGallons!.round()} gal/h '
                '(limite ${threshold.round()} gal/h)',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Alertas de consumo',
                channelDescription:
                    'Avisos locales de consumo normalizado de calderas',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
          await prefs.setBool('$_sentPrefix$hourKey', true);
        }
      }
      await prefs.setString(_lastCheckKey, now.toIso8601String());
    } catch (_) {
      // A local alert must never interrupt the operator workflow.
    } finally {
      _checking = false;
    }
  }

  double? _thresholdFor(String boilerId, double? pressurePsi) {
    switch (boilerId) {
      case 'alfa_laval_1200':
        return 300;
      case 'distral_900':
        return 190;
      case 'cleaver_brooks_1200':
        if (pressurePsi == null) return null;
        if (pressurePsi >= 100 && pressurePsi <= 123) return 190;
        if (pressurePsi >= 150 && pressurePsi <= 161) return 300;
        return null;
      default:
        return null;
    }
  }
}
