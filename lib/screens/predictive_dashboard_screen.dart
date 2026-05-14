import 'package:flutter/material.dart';
import '../models/predictive_models.dart';
import '../services/predictive_analytics_service.dart';

/// Dashboard des prédictions et analyses IA
class PredictiveDashboardScreen extends StatefulWidget {
  final String userId;

  const PredictiveDashboardScreen({super.key, required this.userId});

  @override
  State<PredictiveDashboardScreen> createState() =>
      _PredictiveDashboardScreenState();
}

class _PredictiveDashboardScreenState extends State<PredictiveDashboardScreen> {
  final _analyticsService = PredictiveAnalyticsService();
  late Future<PredictionData> _predictionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPredictions();
  }

  void _refreshPredictions({bool force = false}) {
    setState(() {
      _predictionsFuture = _analyticsService.getAllPredictions(
        widget.userId,
        forceRefresh: force,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 Analyse Prédictive'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshPredictions(force: true),
            tooltip: 'Rafraîchir les données',
          ),
        ],
      ),
      body: FutureBuilder(
        future: _predictionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _refreshPredictions(force: true),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final scores = data.scores;
          final xgboost = data.xgboost;
          final prophet = data.prophet;
          final anomalies = data.anomalies;

          return RefreshIndicator(
            onRefresh: () async {
              _refreshPredictions(force: true);
              await _predictionsFuture;
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Scores Financiers
                  if (scores != null && scores.windowMonths > 0) ...[
                    const Text(
                      '📊 Score Financier',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildScoresCard(scores),
                    const SizedBox(height: 24),
                  ],

                  // Section XGBoost Forecast
                  if (xgboost != null && xgboost.forecast.isNotEmpty && (scores?.windowMonths ?? 0) > 0) ...[
                    const Text(
                      '📈 Prévision Dépenses (XGBoost)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildXGBoostCard(xgboost),
                    const SizedBox(height: 24),
                  ],

                  // Section Prophet Forecast
                  if (prophet != null &&
                      prophet.monthlyForecast.isNotEmpty && (scores?.windowMonths ?? 0) > 0) ...[
                    const Text(
                      '🔮 Tendances Saisonnières (Prophet)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProphetCard(prophet),
                    const SizedBox(height: 24),
                  ],

                  // Section Anomalies
                  if (anomalies.isNotEmpty) ...[
                    const Text(
                      '⚠️ Anomalies Détectées',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnomaliesSection(anomalies),
                    const SizedBox(height: 24),
                  ],

                  // Section Recommandations
                  if (scores != null && scores.windowMonths > 0) ...[
                    const Text(
                      '💡 Recommandations',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRecommendationsCard(scores),
                  ],

                  // No data message or insufficient data
                  if ((scores == null && xgboost == null && prophet == null && anomalies.isEmpty) || 
                      (scores != null && scores.windowMonths < 2) ||
                      (prophet != null && prophet.modelVersion == 'baseline')) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            (scores?.windowMonths != null && scores!.windowMonths < 2) || (prophet?.modelVersion == 'baseline')
                                ? 'Données insuffisantes' 
                                : 'Aucune analyse disponible',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (scores?.windowMonths != null && scores!.windowMonths < 2) || (prophet?.modelVersion == 'baseline')
                                ? 'L\'IA a besoin d\'au moins 2 mois de données historiques\npour générer des prévisions fiables.'
                                : 'Les analyses apparaîtront automatiquement\naprès génération par le backend IA',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoresCard(FinancialScores scores) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overall Score prominently displayed
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _scoreGradient(scores.overallScore),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Score Global',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${scores.overallScore.toStringAsFixed(1)}/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _scoreInterpretation(scores.overallScore),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Individual scores
            _buildScoreRow('Discipline', scores.disciplineScore),
            const SizedBox(height: 12),
            _buildScoreRow('Stabilité', scores.stabilityScore),
            const SizedBox(height: 12),
            _buildScoreRow('Épargne', scores.savingsScore),
            const SizedBox(height: 12),
            _buildScoreRow('Risque', scores.riskScore),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreRow(String label, double score) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_scoreColor(score)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 40,
          child: Text(
            '${score.toStringAsFixed(0)}%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildXGBoostCard(XGBoostForecast xgboost) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (xgboost.predictedSpending != null) ...[
              _buildPredictionItem(
                '💰 Dépenses Prévues',
                '${xgboost.predictedSpending?.toStringAsFixed(0) ?? '--'} Ar',
                Colors.blue,
              ),
              const SizedBox(height: 16),
            ],
            if (xgboost.predictedBalance != null) ...[
              _buildPredictionItem(
                '🏦 Solde Prévu',
                '${xgboost.predictedBalance?.toStringAsFixed(0) ?? '--'} Ar',
                xgboost.predictedBalance! >= 0 ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 16),
            ],
            if (xgboost.deficitRiskPercent != null) ...[
              Row(
                children: [
                  const Text('⚠️ Risque de Déficit'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _riskColor(xgboost.deficitRiskPercent!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${xgboost.deficitRiskPercent!.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (xgboost.recommendedBudget != null &&
                xgboost.recommendedBudget!.isNotEmpty) ...[
              const Text(
                'Budget Recommandé par Catégorie:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...xgboost.recommendedBudget!.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text(
                        '${e.value.toStringAsFixed(0)} Ar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProphetCard(ProphetForecast prophet) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prévisions Mensuelles (3 mois):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (prophet.monthlyForecast.isNotEmpty) ...[
              ...prophet.monthlyForecast.take(3).map((forecast) {
                final ds = forecast['date'] ?? 'N/A';
                final yhat = (forecast['forecast'] as num?)?.toDouble() ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ds.toString()),
                      Text(
                        '${yhat.toStringAsFixed(0)} Ar',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            if (prophet.seasonalPatterns.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Patterns Saisonniers:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...prophet.seasonalPatterns.entries.map((e) {
                return Text('• ${e.key}', style: const TextStyle(fontSize: 12));
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesSection(List<AnomalyAlert> anomalies) {
    return Column(
      children: anomalies.map((alert) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: alert.severityColor, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: alert.severityColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.severity,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.anomalyType,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(alert.description),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendationsCard(FinancialScores scores) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._generateRecommendations(scores).map((rec) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rec)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  List<String> _generateRecommendations(FinancialScores scores) {
    final recommendations = <String>[];

    if (scores.overallScore < 40) {
      recommendations.add(
        '⚠️ Votre score est faible. Priorisez la réduction des dépenses.',
      );
    }
    if (scores.disciplineScore < 50) {
      recommendations.add(
        '📝 Améliorez votre discipline : suivi régulier des dépenses.',
      );
    }
    if (scores.stabilityScore < 50) {
      recommendations.add(
        '📊 Vos dépenses varient trop. Essayez de stabiliser votre consommation.',
      );
    }
    if (scores.savingsScore < 50) {
      recommendations.add(
        '💰 Augmentez votre taux d\'épargne : fixez un budget pour l\'épargne.',
      );
    }
    if (scores.riskScore > 70) {
      recommendations.add(
        '🛑 Votre profil de risque est élevé. Diversifiez vos revenus.',
      );
    }
    if (scores.overallScore >= 80) {
      recommendations.add(
        '🎉 Excellent travail ! Continuez à maintenir cette discipline financière.',
      );
    }

    return recommendations.isNotEmpty
        ? recommendations
        : ['💡 Vos finances sont équilibrées. Maintenez votre gestion actuelle.'];
  }

  Color _scoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  List<Color> _scoreGradient(double score) {
    if (score >= 80) {
      return [Colors.green.shade600, Colors.green.shade400];
    } else if (score >= 60) {
      return [Colors.blue.shade600, Colors.blue.shade400];
    } else if (score >= 40) {
      return [Colors.orange.shade600, Colors.orange.shade400];
    } else {
      return [Colors.red.shade600, Colors.red.shade400];
    }
  }

  String _scoreInterpretation(double score) {
    if (score >= 90) return 'Excellent';
    if (score >= 75) return 'Très Bon';
    if (score >= 60) return 'Bon';
    if (score >= 40) return 'À Améliorer';
    return 'Critique';
  }

  Color _riskColor(double risk) {
    if (risk < 25) return Colors.green;
    if (risk < 50) return Colors.amber;
    if (risk < 75) return Colors.orange;
    return Colors.red;
  }
}
