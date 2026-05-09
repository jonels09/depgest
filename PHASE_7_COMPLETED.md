# Phase 7 : Flutter Dashboard Prédictif 🤖

## ✅ Accomplissements

### 1. **Modèles de Données Prédictives** (`predictive_models.dart`)
- `FinancialScores` : Scores de discipline, stabilité, épargne, risque
- `XGBoostForecast` : Prédictions XGBoost avec dépenses et budgets
- `ProphetForecast` : Prédictions saisonnières avec patterns détectés
- `AnomalyAlert` : Alertes d'anomalies avec severity (LOW/MEDIUM/HIGH)

### 2. **Service API Prédictif** (`predictive_analytics_service.dart`)
Singleton service avec méthodes :
- `healthCheck()` : Vérifier la connexion au backend
- `calculateScores(userId)` : Calcul des scores financiers
- `detectAnomalies(userId)` : Détection des anomalies
- `forecastXGBoost(userId)` : Prédictions XGBoost
- `forecastProphet(userId)` : Prédictions Prophet
- `getAllPredictions(userId)` : Récupère toutes les prédictions en parallèle

### 3. **Dashboard Prédictif** (`predictive_dashboard_screen.dart`)
Interface complète affichant :

#### 📊 **Section Scores Financiers**
- Score global avec gradient de couleur (rouge → vert)
- Scores individuels : Discipline, Stabilité, Épargne, Risque
- Interprétation textuelle (Critique → Excellent)
- Barres de progression animées

#### 📈 **Section XGBoost**
- Dépenses prévues pour le mois suivant
- Solde prévu (fin de mois)
- Risque de déficit en pourcentage
- Budgets recommandés par catégorie

#### 🔮 **Section Prophet**
- Prévisions 3 mois avec dates et montants
- Patterns saisonniers détectés
- Tendances observées

#### ⚠️ **Section Anomalies**
- Listes des anomalies détectées
- Code couleur par sévérité
- Type et description de chaque anomalie

#### 💡 **Section Recommandations**
- Recommandations générées en fonction des scores
- Conseils personnalisés pour améliorer la gestion financière

### 4. **Intégration Navigation** 
- Ajout du tab "🤖 IA" dans la navigation inférieure
- Positionnement entre "Stats" et "Plan"
- Récupération automatique de l'ID utilisateur depuis Supabase

### 5. **Configuration Backend** (`supabase_config.dart`)
```dart
class BackendConfig {
  static const String baseUrl = 'http://localhost:8000'; // Dev local
  static const Duration timeout = Duration(seconds: 30);
}
```

## 🏗️ Architecture

```
Flutter Frontend
    ↓
PredictiveAnalyticsService (singleton)
    ↓
Backend FastAPI (localhost:8000)
    ↓
Models ML (XGBoost, Prophet, Isolation Forest)
    ↓
Supabase (récupération données + stockage résultats)
```

## 📱 Interface Utilisateur

### Écran Principal
- **Rafraîchissement** : Bouton en haut à droite
- **Pull-to-refresh** : Geste de rafraîchissement standard
- **Skeleton loading** : Spinner pendant le chargement
- **Gestion erreurs** : Affichage avec bouton "Réessayer"

### Couleurs et Styles
- **Scores ≥ 80%** : Vert (excellent)
- **Scores ≥ 60%** : Bleu (bon)
- **Scores ≥ 40%** : Orange (à améliorer)
- **Scores < 40%** : Rouge (critique)

## 🚀 Utilisation

### Accéder au Dashboard
1. Lancer l'application Flutter
2. Cliquer sur l'onglet "🤖 IA" en bas
3. Le service récupère automatiquement les prédictions du backend

### Flux Requêtes
```
Utilisateur clique "IA" 
    → Service récupère user_id Supabase
    → Appelle /scores/calculate
    → Appelle /forecast/xgboost
    → Appelle /forecast/prophet
    → Appelle /anomalies/detect
    → Affiche résultats (ou erreur + retry)
```

## ⚙️ Configuration Requise

### Backend (Python)
- Service FastAPI running sur `http://localhost:8000`
- Endpoints implémentés : /health, /scores/calculate, /anomalies/detect, /forecast/xgboost, /forecast/prophet

### Frontend (Flutter)
- Packages requis :
  - `http` (pour appels API)
  - `supabase_flutter` (pour auth user_id)
  - `intl` (pour formatage)

### Supabase
- Tables de stockage : predictions, financial_scores, anomalies, model_metadata
- RLS configurée par user_id

## 📊 Exemple de Réponse

### Scores Financiers
```json
{
  "user_id": "uuid-123",
  "discipline_score": 85.5,
  "stability_score": 72.0,
  "savings_score": 68.3,
  "risk_score": 45.2,
  "overall_score": 72.75,
  "insights": {
    "strong": "Excellente discipline budgétaire",
    "weak": "Épargne irrégulière"
  }
}
```

### XGBoost Forecast
```json
{
  "status": "success",
  "forecast": {
    "predicted_spending": 2450.50,
    "predicted_balance": 1280.75,
    "deficit_risk": 0.12,
    "recommended_budget": {
      "Alimentation": 600,
      "Transport": 400,
      "Loisirs": 350
    }
  }
}
```

## 🔄 État Intégration

| Composant | État | Notes |
|-----------|------|-------|
| Modèles   | ✅   | Tous les modèles définis |
| Service   | ✅   | Toutes les méthodes implémentées |
| UI        | ✅   | Dashboard complet et fonctionnel |
| Navigation| ✅   | Onglet "IA" ajouté |
| Config    | ✅   | Backend URL configurée |
| Supabase  | ✅   | Authentification intégrée |

## 📝 Prochaines Étapes (Phase 8)

- [ ] Intégration de la synchronisation Supabase en temps réel
- [ ] Caching des prédictions pour offline
- [ ] Graphiques et visualisations avancées
- [ ] Partage des rapports
- [ ] Notifications pour anomalies détectées
- [ ] Export PDF des rapports

## 🐛 Dépannage

### Backend non accessible
```
❌ Backend health check failed: Connection refused
→ Vérifier que le backend FastAPI est running sur port 8000
```

### Pas de données
```
→ Vérifier que l'utilisateur a assez de données dans Supabase
→ Vérifier que les tables de dépenses/revenus ne sont pas vides
```

### Erreur réseau
```
→ Vérifier la configuration BackendConfig.baseUrl
→ Vérifier les règles CORS du backend
```

---

**Status**: ✅ Phase 7 Complétée - Dashboard fonctionnel et intégré  
**Prochaine Phase**: Phase 8 - Data Sync Integration
