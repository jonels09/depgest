import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/predictive_models.dart';

class PredictiveNotification {
  final String title;
  final String message;
  final String severity;
  final DateTime createdAt;

  const PredictiveNotification({
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
  });
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final ValueNotifier<List<PredictiveNotification>> notifications =
      ValueNotifier(const <PredictiveNotification>[]);

  Future<void> setAnomalyAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_anomalyAlertsKey, enabled);
  }

  Future<void> setDeficitAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deficitAlertsKey, enabled);
  }

  Future<bool> anomalyAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_anomalyAlertsKey) ?? true;
  }

  Future<bool> deficitAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deficitAlertsKey) ?? true;
  }

  Future<void> notifyAnomalies(List<AnomalyAlert> anomalies) async {
    if (!await anomalyAlertsEnabled()) return;

    final serious = anomalies.where((item) => item.isMediumOrHigh).toList();
    if (serious.isEmpty) return;

    _push(
      PredictiveNotification(
        title: 'Alerte depense',
        message: serious.length == 1
            ? serious.first.description
            : '${serious.length} depenses inhabituelles detectees',
        severity: serious.any((item) => item.isHighSeverity)
            ? 'HIGH'
            : 'MEDIUM',
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> notifyDeficitRisk(XGBoostForecast? forecast) async {
    if (forecast == null || !await deficitAlertsEnabled()) return;

    final risk = forecast.deficitRiskPercent;
    if (risk == null || risk < 60) return;

    _push(
      PredictiveNotification(
        title: 'Risque de deficit',
        message: 'Risque estime a ${risk.toStringAsFixed(0)}% ce mois-ci',
        severity: risk >= 80 ? 'HIGH' : 'MEDIUM',
        createdAt: DateTime.now(),
      ),
    );
  }

  void _push(PredictiveNotification notification) {
    final next = [notification, ...notifications.value].take(20).toList();
    notifications.value = List.unmodifiable(next);
    debugPrint(
      '[NotificationService] ${notification.title}: ${notification.message}',
    );
  }
}

const _anomalyAlertsKey = 'predictive.notifications.anomalies';
const _deficitAlertsKey = 'predictive.notifications.deficit';
