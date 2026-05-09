import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/predictive_models.dart';
import 'notification_service.dart';

class PredictiveAnalyticsService {
  static final PredictiveAnalyticsService _instance =
      PredictiveAnalyticsService._internal();

  factory PredictiveAnalyticsService() => _instance;

  PredictiveAnalyticsService._internal();

  final http.Client _httpClient = http.Client();

  Future<bool> healthCheck() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('${BackendConfig.baseUrl}/health'))
          .timeout(BackendConfig.timeout);
      return response.statusCode == 200;
    } catch (error) {
      debugPrint('[PredictiveAnalyticsService] Health check failed: $error');
      return false;
    }
  }

  Future<FinancialScores?> calculateScores(
    String userId, {
    int windowMonths = 3,
    bool includeBudgets = false,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(userId, 'scores_$windowMonths');
    if (!forceRefresh) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) return FinancialScores.fromJson(cached);
    }

    final result = await _sendMap(
      label: 'scores',
      request: () => _httpClient.post(
        Uri.parse('${BackendConfig.baseUrl}/scores/calculate'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'window_months': windowMonths,
          'include_budgets': includeBudgets,
        }),
      ),
    );

    if (result != null) {
      await _writeCache(cacheKey, result);
      return FinancialScores.fromJson(result);
    }

    final stale = await _readCachedMap(cacheKey, allowStale: true);
    return stale == null ? null : FinancialScores.fromJson(stale);
  }

  Future<List<AnomalyAlert>> detectAnomalies(
    String userId, {
    String? depenseId,
    bool saveToDb = true,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(userId, 'anomalies');
    if (!forceRefresh && !saveToDb) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) {
        return _readAnomalies(cached);
      }
    }

    final result = await _sendMap(
      label: 'anomalies',
      request: () => _httpClient.post(
        Uri.parse('${BackendConfig.baseUrl}/anomalies/detect'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'depense_id': depenseId,
          'save_to_db': saveToDb,
        }),
      ),
    );

    if (result != null) {
      await _writeCache(cacheKey, result);
      final anomalies = _readAnomalies(result);
      unawaited(NotificationService.instance.notifyAnomalies(anomalies));
      return anomalies;
    }

    final stale = await _readCachedMap(cacheKey, allowStale: true);
    return stale == null ? const <AnomalyAlert>[] : _readAnomalies(stale);
  }

  Future<XGBoostForecast?> forecastXGBoost(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(userId, 'xgboost');
    if (!forceRefresh) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) return XGBoostForecast.fromJson(cached);
    }

    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/forecast/xgboost',
    ).replace(queryParameters: {'user_id': userId});
    final result = await _sendMap(
      label: 'xgboost',
      request: () => _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    if (result != null) {
      await _writeCache(cacheKey, result);
      final forecast = XGBoostForecast.fromJson(result);
      unawaited(NotificationService.instance.notifyDeficitRisk(forecast));
      return forecast;
    }

    final stale = await _readCachedMap(cacheKey, allowStale: true);
    return stale == null ? null : XGBoostForecast.fromJson(stale);
  }

  Future<ProphetForecast?> forecastProphet(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _cacheKey(userId, 'prophet');
    if (!forceRefresh) {
      final cached = await _readCachedMap(cacheKey);
      if (cached != null) return ProphetForecast.fromJson(cached);
    }

    final uri = Uri.parse(
      '${BackendConfig.baseUrl}/forecast/prophet',
    ).replace(queryParameters: {'user_id': userId});
    final result = await _sendMap(
      label: 'prophet',
      request: () => _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    if (result != null) {
      await _writeCache(cacheKey, result);
      return ProphetForecast.fromJson(result);
    }

    final stale = await _readCachedMap(cacheKey, allowStale: true);
    return stale == null ? null : ProphetForecast.fromJson(stale);
  }

  Future<PredictionData> getAllPredictions(
    String userId, {
    bool forceRefresh = false,
  }) async {
    final results = await Future.wait<Object?>([
      calculateScores(userId, forceRefresh: forceRefresh),
      forecastXGBoost(userId, forceRefresh: forceRefresh),
      forecastProphet(userId, forceRefresh: forceRefresh),
      detectAnomalies(userId, saveToDb: false, forceRefresh: forceRefresh),
    ]);

    return PredictionData(
      scores: results[0] as FinancialScores?,
      xgboost: results[1] as XGBoostForecast?,
      prophet: results[2] as ProphetForecast?,
      anomalies: (results[3] as List<AnomalyAlert>?) ?? const <AnomalyAlert>[],
      fetchedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> triggerPostExpenseAnalysis({
    String? userId,
    String? depenseId,
  }) async {
    final resolvedUserId =
        userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (resolvedUserId == null) return;

    final anomalies = await detectAnomalies(
      resolvedUserId,
      depenseId: depenseId,
      saveToDb: true,
      forceRefresh: true,
    );
    unawaited(NotificationService.instance.notifyAnomalies(anomalies));
  }

  Future<void> triggerFinancialRefresh({String? userId}) async {
    final resolvedUserId =
        userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (resolvedUserId == null) return;

    await Future.wait([
      calculateScores(resolvedUserId, forceRefresh: true),
      forecastXGBoost(resolvedUserId, forceRefresh: true),
    ]);
  }

  Future<Map<String, dynamic>?> _sendMap({
    required String label,
    required Future<http.Response> Function() request,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= BackendConfig.retryCount; attempt++) {
      try {
        final response = await request().timeout(BackendConfig.timeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
          if (decoded is Map) return _stringKeyedMap(decoded);
          throw const FormatException('Response is not a JSON object');
        }
        lastError = 'HTTP ${response.statusCode}: ${response.body}';
      } catch (error) {
        lastError = error;
      }

      if (attempt < BackendConfig.retryCount) {
        await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
      }
    }

    debugPrint('[PredictiveAnalyticsService] $label failed: $lastError');
    return null;
  }

  List<AnomalyAlert> _readAnomalies(Map<String, dynamic> json) {
    final value = json['anomalies'];
    if (value is! List) return const <AnomalyAlert>[];
    return value
        .whereType<Map>()
        .map((item) => AnomalyAlert.fromJson(_stringKeyedMap(item)))
        .toList();
  }

  Future<Map<String, dynamic>?> _readCachedMap(
    String key, {
    bool allowStale = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final cachedAt = DateTime.tryParse(_asString(decoded['cached_at']));
      final payload = decoded['payload'];
      if (payload is! Map) return null;

      final isFresh =
          cachedAt != null &&
          DateTime.now().difference(cachedAt) <= BackendConfig.cacheTtl;
      if (!allowStale && !isFresh) return null;

      return _stringKeyedMap(payload);
    } catch (error) {
      debugPrint('[PredictiveAnalyticsService] Cache read failed: $error');
      return null;
    }
  }

  Future<void> _writeCache(String key, Map<String, dynamic> payload) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        'cached_at': DateTime.now().toIso8601String(),
        'payload': payload,
      }),
    );
  }

  String _cacheKey(String userId, String name) {
    return 'predictive.$userId.$name';
  }
}

String _asString(Object? value) => value == null ? '' : value.toString();

Map<String, dynamic> _stringKeyedMap(Map value) {
  return value.map((key, val) => MapEntry(key.toString(), val));
}
