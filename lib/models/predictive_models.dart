import 'package:flutter/material.dart';

double _asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

String _asString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is List) {
    return value
        .whereType<Map>()
        .map((item) => item.map((key, val) => MapEntry(key.toString(), val)))
        .toList();
  }
  return <Map<String, dynamic>>[];
}

class FinancialScores {
  final String userId;
  final double disciplineScore;
  final double stabilityScore;
  final double savingsScore;
  final double riskScore;
  final double overallScore;
  final Map<String, dynamic> insights;
  final String calculatedAt;
  final int windowMonths;

  const FinancialScores({
    required this.userId,
    required this.disciplineScore,
    required this.stabilityScore,
    required this.savingsScore,
    required this.riskScore,
    required this.overallScore,
    required this.insights,
    required this.calculatedAt,
    this.windowMonths = 3,
  });

  factory FinancialScores.fromJson(Map<String, dynamic> json) {
    return FinancialScores(
      userId: _asString(json['user_id']),
      disciplineScore: _asDouble(json['discipline_score']),
      stabilityScore: _asDouble(json['stability_score']),
      savingsScore: _asDouble(json['savings_score']),
      riskScore: _asDouble(json['risk_score']),
      overallScore: _asDouble(json['overall_score']),
      insights: _asMap(json['insights']),
      calculatedAt: _asString(
        json['calculated_at'] ?? json['created_at'],
        DateTime.now().toIso8601String(),
      ),
      windowMonths: (json['window_months'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'discipline_score': disciplineScore,
    'stability_score': stabilityScore,
    'savings_score': savingsScore,
    'risk_score': riskScore,
    'overall_score': overallScore,
    'insights': insights,
    'calculated_at': calculatedAt,
    'window_months': windowMonths,
  };

  List<String> get recommendations {
    final value = insights['recommendations'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const <String>[];
  }
}

class XGBoostForecast {
  final String userId;
  final String status;
  final Map<String, dynamic> forecast;
  final Map<String, dynamic> metrics;
  final String generatedAt;

  const XGBoostForecast({
    required this.userId,
    required this.status,
    required this.forecast,
    required this.metrics,
    required this.generatedAt,
  });

  factory XGBoostForecast.fromJson(Map<String, dynamic> json) {
    final nestedForecast = _asMap(json['forecast']);
    final forecast =
        nestedForecast.isNotEmpty
              ? nestedForecast
              : <String, dynamic>{
                  'predicted_spending': json['predicted_spending'],
                  'predicted_balance': json['predicted_balance'],
                  'deficit_risk': json['deficit_risk'],
                  'recommended_budget': json['recommended_budget'],
                  'model_version': json['model_version'],
                }
          ..removeWhere((_, value) => value == null);

    return XGBoostForecast(
      userId: _asString(json['user_id']),
      status: _asString(
        json['status'],
        forecast.isEmpty ? 'unknown' : 'success',
      ),
      forecast: forecast,
      metrics: _asMap(json['metrics']),
      generatedAt: _asString(
        json['generated_at'] ?? json['created_at'],
        DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'status': status,
    'forecast': forecast,
    'metrics': metrics,
    'generated_at': generatedAt,
  };

  double? get predictedSpending {
    final value = forecast['predicted_spending'];
    return value == null ? null : _asDouble(value);
  }

  double? get predictedBalance {
    final value = forecast['predicted_balance'];
    return value == null ? null : _asDouble(value);
  }

  double? get deficitRiskPercent {
    final value = forecast['deficit_risk'];
    if (value == null) return null;
    final raw = _asDouble(value);
    return raw <= 1 ? raw * 100 : raw;
  }

  Map<String, double>? get recommendedBudget {
    final value = forecast['recommended_budget'];
    if (value is! Map) return null;
    return value.map((key, val) => MapEntry(key.toString(), _asDouble(val)));
  }

  String get modelVersion => _asString(forecast['model_version'], 'v1.0');
}

class ProphetForecast {
  final String userId;
  final String status;
  final Map<String, dynamic> forecast;
  final Map<String, dynamic> metrics;
  final String generatedAt;

  const ProphetForecast({
    required this.userId,
    required this.status,
    required this.forecast,
    required this.metrics,
    required this.generatedAt,
  });

  factory ProphetForecast.fromJson(Map<String, dynamic> json) {
    return ProphetForecast(
      userId: _asString(json['user_id']),
      status: _asString(json['status'], 'unknown'),
      forecast: _asMap(json['forecast']),
      metrics: _asMap(json['metrics']),
      generatedAt: _asString(
        json['generated_at'] ?? json['created_at'],
        DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'status': status,
    'forecast': forecast,
    'metrics': metrics,
    'generated_at': generatedAt,
  };

  List<Map<String, dynamic>> get monthlyForecast {
    return _asMapList(forecast['monthly_forecast']).map((item) {
      final forecastValue = item['forecast'] ?? item['yhat'];
      return {
        'date': item['date'] ?? item['ds'],
        'forecast': _asDouble(forecastValue),
        'lower_95': _asDouble(item['lower_95'] ?? item['yhat_lower']),
        'upper_95': _asDouble(item['upper_95'] ?? item['yhat_upper']),
      };
    }).toList();
  }

  Map<String, dynamic> get seasonalPatterns {
    return _asMap(forecast['seasonal_patterns']);
  }

  Map<String, dynamic> get trend => _asMap(forecast['trend']);
}

class AnomalyAlert {
  final String? id;
  final String? depenseId;
  final String anomalyType;
  final String severity;
  final String description;
  final Map<String, dynamic> metadata;
  final String detectedAt;
  final bool isConfirmed;

  const AnomalyAlert({
    this.id,
    this.depenseId,
    required this.anomalyType,
    required this.severity,
    required this.description,
    required this.metadata,
    required this.detectedAt,
    this.isConfirmed = false,
  });

  factory AnomalyAlert.fromJson(Map<String, dynamic> json) {
    return AnomalyAlert(
      id: json['id']?.toString(),
      depenseId: json['depense_id']?.toString(),
      anomalyType: _asString(json['anomaly_type'], 'UNKNOWN'),
      severity: _asString(json['severity'], 'LOW'),
      description: _asString(json['description']),
      metadata: _asMap(json['metadata']),
      detectedAt: _asString(
        json['detected_at'] ?? json['created_at'],
        DateTime.now().toIso8601String(),
      ),
      isConfirmed: json['is_confirmed'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'depense_id': depenseId,
    'anomaly_type': anomalyType,
    'severity': severity,
    'description': description,
    'metadata': metadata,
    'detected_at': detectedAt,
    'is_confirmed': isConfirmed,
  };

  bool get isHighSeverity => severity.toUpperCase() == 'HIGH';
  bool get isMediumOrHigh {
    final normalized = severity.toUpperCase();
    return normalized == 'MEDIUM' || normalized == 'HIGH';
  }

  Color get severityColor {
    switch (severity.toUpperCase()) {
      case 'HIGH':
        return const Color(0xFFBA1A1A);
      case 'MEDIUM':
        return const Color(0xFFF57C00);
      case 'LOW':
      default:
        return const Color(0xFF2E7D32);
    }
  }
}

class PredictionData {
  final FinancialScores? scores;
  final XGBoostForecast? xgboost;
  final ProphetForecast? prophet;
  final List<AnomalyAlert> anomalies;
  final String fetchedAt;
  final bool fromCache;

  const PredictionData({
    this.scores,
    this.xgboost,
    this.prophet,
    this.anomalies = const <AnomalyAlert>[],
    required this.fetchedAt,
    this.fromCache = false,
  });

  factory PredictionData.empty({bool fromCache = false}) {
    return PredictionData(
      fetchedAt: DateTime.now().toIso8601String(),
      fromCache: fromCache,
    );
  }

  factory PredictionData.fromJson(Map<String, dynamic> json) {
    final scoresJson = json['scores'];
    final xgboostJson = json['xgboost'];
    final prophetJson = json['prophet'];
    return PredictionData(
      scores: scoresJson is Map
          ? FinancialScores.fromJson(_asMap(scoresJson))
          : null,
      xgboost: xgboostJson is Map
          ? XGBoostForecast.fromJson(_asMap(xgboostJson))
          : null,
      prophet: prophetJson is Map
          ? ProphetForecast.fromJson(_asMap(prophetJson))
          : null,
      anomalies: _asMapList(
        json['anomalies'],
      ).map(AnomalyAlert.fromJson).toList(),
      fetchedAt: _asString(
        json['fetched_at'],
        DateTime.now().toIso8601String(),
      ),
      fromCache: json['from_cache'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'scores': scores?.toJson(),
    'xgboost': xgboost?.toJson(),
    'prophet': prophet?.toJson(),
    'anomalies': anomalies.map((item) => item.toJson()).toList(),
    'fetched_at': fetchedAt,
    'from_cache': fromCache,
  };

  bool get hasData {
    return scores != null ||
        xgboost != null ||
        prophet != null ||
        anomalies.isNotEmpty;
  }

  PredictionData copyWith({
    FinancialScores? scores,
    XGBoostForecast? xgboost,
    ProphetForecast? prophet,
    List<AnomalyAlert>? anomalies,
    String? fetchedAt,
    bool? fromCache,
  }) {
    return PredictionData(
      scores: scores ?? this.scores,
      xgboost: xgboost ?? this.xgboost,
      prophet: prophet ?? this.prophet,
      anomalies: anomalies ?? this.anomalies,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  List<String> topInsights() {
    final items = <String>[];
    if (scores != null) {
      items.add(
        'Score financier: ${scores!.overallScore.toStringAsFixed(0)}/100',
      );
    }
    final spending = xgboost?.predictedSpending;
    if (spending != null && spending > 0) {
      items.add('Depenses prevues: ${spending.toStringAsFixed(0)} Ar');
    }
    final risk = xgboost?.deficitRiskPercent;
    if (risk != null && risk >= 50) {
      items.add('Risque deficit: ${risk.toStringAsFixed(0)}%');
    }
    final serious = anomalies.where((item) => item.isMediumOrHigh).length;
    if (serious > 0) {
      items.add('$serious anomalie(s) a verifier');
    }
    return items.take(3).toList();
  }
}
