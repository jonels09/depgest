# Plan: Intégration IA Prédictive Financière Multi-Modèles

**TL;DR:** Créer un backend Python (FastAPI) qui entraîne XGBoost, Prophet et détection d'anomalies sur vos données Supabase, recalculé quotidiennement. Flutter interroge ce backend pour afficher scores financiers, alertes d'anomalies, et prévisions dans un nouveau Dashboard Analytics. Architecture hybride : Python pour les modèles lourds, Flutter pour l'UI et le sync local.

---

## **Steps**

### **Phase 1: Infrastructure Backend (Dépendances pour tout le reste)**

1. **Créer structure Python** (*dependency: None*)
   - Dossier `/backend_python/` à la racine du projet
   - Poetry ou pip pour gérer les dépendances (XGBoost, Prophet, scikit-learn, FastAPI, SQLAlchemy, Supabase client)
   - Configuration `.env` pour connexion Supabase

2. **Configurer connexion Supabase** (*parallel with step 1*)
   - Créer `backend_python/config.py` : clés API Supabase, paramètres de modèle
   - Module `backend_python/supabase_client.py` pour interroger depenses/revenus/budgets

3. **Créer tables de stockage dans Supabase** (*depends on 2*)
   - `predictions` : XGBoost forecasts (user_id, month, predicted_spending, predicted_balance, deficit_risk, recommended_budget, created_at)
   - `anomalies` : alertes détectées (user_id, depense_id, anomaly_type, severity, description, detected_at)
   - `financial_scores` : scores mensuels (user_id, month, discipline_score, stability_score, savings_score, risk_score, overall_score, created_at)
   - `model_metadata` : versions/dates d'entraînement (model_type, last_trained, training_count, data_points_used)

### **Phase 2: Modèle Score Financier (Fondation)**

4. **Implémenter module `score_calculator.py`** (*depends on 3*)
   - **Discipline Score** (0-100) : régularité des épargnes, respect des budgets, stabilité mensuellement
   - **Stability Score** (0-100) : variance des dépenses, ratio revenu/dépense stable
   - **Savings Score** (0-100) : % épargnes, progression des goals, fréquence contributions
   - **Risk Score** (0-100 inversé) : surspend rate, déficits mensuels, volatilité
   - Overall Score = moyenne pondérée (30% Discipline, 30% Stability, 25% Savings, 15% Risk)
   - Calculer sur fenêtre glissante 3, 6, 12 mois

5. **Créer endpoint FastAPI** `/scores/calculate` (*depends on 4*)
   - Récupère données utilisateur depuis Supabase
   - Appelle `score_calculator.py`
   - Sauvegarde résultats dans table `financial_scores`
   - Retourne scores et insights textuels

### **Phase 3: Détection Anomalies (Sécurité)**

6. **Implémenter `anomaly_detector.py`** (*depends on 3*)
   - **Isolation Forest** : détecte outliers dans distribution des dépenses par catégorie
   - **Z-score** : hausse brutale (> 2σ) par rapport moyenne personnelle
   - **Statistiques saisonnières** : dépenses inhabituelles vs cycle utilisateur
   - **Fraude potentielle** : patterns soudains, montants extrêmes
   - Retourne : (anomaly_type, severity=LOW/MEDIUM/HIGH, description)

7. **Créer endpoint FastAPI** `/anomalies/detect` (*depends on 6*)
   - Exécuté après chaque nouvelle dépense (via trigger Supabase ou polling)
   - Sauvegarde anomalies détectées dans `anomalies` table
   - Marque anomalies résolues/confirmées par utilisateur

### **Phase 4: XGBoost - Prévisions Court Terme**

8. **Implémenter `xgboost_forecaster.py`** (*depends on 3*)
   - **Features d'entrée** : derniers 12 mois dépenses/revenus, jour du mois, mois, jour de semaine, catégories historiques
   - **Targets de sortie** :
     - Total dépenses mois suivant
     - Solde fin de mois
     - Probabilité déficit (classification)
     - Budget recommandé par catégorie
   - Validation cross-fold (80/20), métrique MAE/RMSE
   - Gérer utilisateurs avec données limitées (< 3 mois) : utiliser moyennes ou baseline

9. **Créer endpoint FastAPI** `/forecast/xgboost` (*depends on 8*)
   - Réentraîne modèle quotidiennement (background job via APScheduler)
   - Sauvegarde dans `predictions` table
   - Retourne : spending_forecast, balance_forecast, deficit_risk_percent, budget_recommendations

### **Phase 5: Prophet - Patterns Saisonniers**

10. **Implémenter `prophet_forecaster.py`** (*depends on 3*)
    - Entraîne sur série temporelle dépenses globales par mois
    - Détecte saisonnalité (p.ex. dépenses vacances juillet/août)
    - Identifie cycles financiers (par ex. fin de mois surspend)
    - Produit prévisions 3 mois + intervalles confiance (80%, 95%)
    - Segmente par catégorie (si données suffisantes)

11. **Créer endpoint FastAPI** `/forecast/prophet` (*depends on 10*)
    - Réentraîne quotidiennement
    - Sauvegarde tendances saisonnières
    - Retourne : monthly_forecast, seasonal_patterns, confidence_intervals

### **Phase 6: Task Scheduler (Orchestration)**

12. **Créer `scheduler.py`** (*depends on 5, 9, 11*)
    - APScheduler : tâche quotidienne 02:00 UTC
    - Exécute séquentiellement : Score → XGBoost → Prophet (Anomalies exécutées à la demande)
    - Logs + notifications erreurs (email/Sentry)
    - Rollback si entraînement échoue (restaure modèle précédent)

### **Phase 7: Flutter - Dashboard & Intégration**

13. **Créer `screens/analytics_dashboard_screen.dart`** (*depends on 12*)
    - Onglet principal : Vue d'ensemble scores + prévisions
    - 4 sections :
      1. **Financial Score Card** : Overall score, 4 sub-scores, tendance (↑/↓), insights
      2. **XGBoost Forecasts** : Dépenses prévues vs budget, solde projeté, risque déficit
      3. **Prophet Insights** : Cycles saisonniers, pattern détecté, prévisions 3 mois
      4. **Anomalies & Alerts** : Dernières anomalies, sévérité, actions

14. **Créer service `services/predictive_analytics_service.dart`** (*parallel with 13*)
    - Classe `PredictiveAnalyticsService` : méthodes pour interroger backend Python
    - Cache local (SharedPreferences) : scores, prévisions (invalider 24h)
    - Retry logic + error handling
    - Streaming pour scores en temps réel

15. **Intégrer dans `home_screen.dart`** (*depends on 13, 14*)
    - Widget `PredictionSnippet` : affiche top 3 insights (score, prévision, anomalies)
    - Bouton "Voir détails" → navigate to `analytics_dashboard_screen`

16. **Ajouter notifications** (*depends on 15*)
    - `services/notification_service.dart` : alertes push anomalies MEDIUM/HIGH
    - Alerter si risque déficit détecté
    - Configurable par utilisateur (paramètres)

17. **Mettre à jour `pubspec.yaml`** (*parallel with 14*)
    - Ajouter : `http`, `intl` (formats), `charts_flutter` (graphiques)
    - (Note: XGBoost/Prophet restent côté backend Python)

### **Phase 8: Intégration Données & Sync**

18. **Modifier `database_helper.dart`** (*depends on 3, 17*)
    - Après chaque insertion depense/revenu : appel asynchrone à `/anomalies/detect`
    - Récupérer + cacher predictions/scores

19. **Ajouter méthode `DAO.getPredictions()`** (*depends on 18*)
    - Requête Supabase table `predictions` + `anomalies` + `financial_scores`
    - Retourner dans modèle `PredictionData` Flutter-friendly

20. **Sync des données d'entraînement** (*depends on 18*)
    - Backend Python exécute requête Supabase chaque jour (via `supabase_client.py`)
    - Récupère tous les depenses/revenus de l'utilisateur, filtre par date_range
    - Garantir confidentialité : modèles NOT stockés cloud, seulement prédictions

### **Phase 9: Tests & Déploiement**

21. **Tests backend Python** (*parallel with 19, 20*)
    - Unit tests : `test_score_calculator.py`, `test_xgboost_forecaster.py`, etc.
    - Fixtures : données synthétiques utilisateurs test
    - Validation : scores 0-100, prévisions réalistes

22. **Tests Flutter** (*parallel with 21*)
    - Tests `PredictiveAnalyticsService` : mocking API
    - Tests UI : dashboard render, navigation
    - Tests integration : flux complet data → display

23. **Déploiement backend** (*depends on 21*)
    - Option A: Heroku/Railway (gratuit pour POC)
    - Option B: Docker + VPS
    - Option C: Supabase Edge Functions (TypeScript transpilé de Python)
    - Configurer variables d'environnement, CORS pour Flutter

24. **Packaging & documentation** (*depends on 22, 23*)
    - README backend : setup, requirements, API docs (Swagger)
    - Diagramme architecture
    - Guide utilisateur : interprétation scores

---

## **Relevant Files**

**Backend (à créer):**
- `backend_python/requirements.txt` — XGBoost, Prophet, scikit-learn, FastAPI, sqlalchemy, supabase-py, apscheduler
- `backend_python/config.py` — Configuration Supabase, paramètres modèles
- `backend_python/supabase_client.py` — Client données Supabase
- `backend_python/models/score_calculator.py` — Logique calcul scores financiers
- `backend_python/models/anomaly_detector.py` — Isolation Forest + Z-score
- `backend_python/models/xgboost_forecaster.py` — Prédictions court terme
- `backend_python/models/prophet_forecaster.py` — Saisonnalité & patterns
- `backend_python/main.py` — FastAPI app + endpoints
- `backend_python/scheduler.py` — APScheduler + orchestration quotidienne
- `backend_python/Dockerfile` — Containerization (optionnel)

**Flutter (à créer/modifier):**
- `lib/screens/analytics_dashboard_screen.dart` — Dashboard IA (NEW)
- `lib/services/predictive_analytics_service.dart` — Service API (NEW)
- `lib/services/notification_service.dart` — Alertes (NEW)
- `lib/models/prediction_models.dart` — Modèles prédictions (NEW)
- `lib/screens/home_screen.dart` — Intégrer snippet prédictions (MODIFY)
- `lib/database/database_helper.dart` — Hook dépenses → anomalies (MODIFY)
- `pubspec.yaml` — Ajouter dépendances (MODIFY)

**Supabase (à créer):**
- SQL migration : tables `predictions`, `anomalies`, `financial_scores`, `model_metadata`
- RLS policies : chaque user voit ses prédictions uniquement

---

## **Verification**

1. **Backend tests** : `pytest backend_python/tests/` → 100% pass, >90% code coverage
2. **Score calculation** : Vérifier scores 0-100, coherence sur données test (stabilité → 70-80, déficit → 10-20)
3. **XGBoost** : MAE < 15% dépenses moyennes mensuelles, prévisions convergent vers baseline si données insuffisantes
4. **Prophet** : Détecte cycles reconnus (ex: July surge si vacances), SMAPE < 20%
5. **Anomaly detection** : Tester avec dépense 10x normale → flagged MEDIUM/HIGH
6. **Flutter UI** : Dashboard load < 2s (après cache), navigation smooth, notifications push OK
7. **Sync** : Après créer dépense → anomalies détectées < 5s
8. **End-to-end** : Créer utilisateur test, importer 12 mois données, attendre scheduler 24h, vérifier dashboard populated

---

## **Decisions**

- ✅ **Backend Python** (recommandé) : XGBoost/Prophet nécessitent Python, pas viable en Dart pur
- ✅ **Tous historiques** : Maximiser qualité entraînement, fenêtre glissante pour utiliser max data
- ✅ **Réentraînement quotidien** : Balance fraîcheur données vs compute cost (02:00 UTC pendant creux réseau)
- ✅ **Dashboard séparé** : Meilleure UX que widgets dispersés, permet focus utilisateur
- ✅ **Anomalies à la demande** : Rapide, exécuté après chaque dépense sans attendre scheduler
- ✅ **Modèles NOT cloud** : Seulement prédictions stockées Supabase → privacy, pas d'upload modèles
- ⚠️ **Fallback pour peu de données** : Utilisateurs < 3 mois → XGBoost baselines, Prophet N/A

---

## **Further Considerations**

1. **Infrastructure déploiement** : Heroku/Railway gratuit vs VPS payant ? Vérifier latence API Flutter ↔ Backend (< 500ms cible)
   - **Recommandation** : Heroku gratuit pour MVP, upgrade si besoin

2. **Retraçabilité modèles** : Stocker `model_metadata` avec date, # samples, RMSE ? Utile pour debug/rollback
   - **Recommandation** : Oui, ajouter version modèles, permettre user opt-in à version antérieure

3. **Confidentialité données** : Modèles Python entraînés côté backend = zéro données quittent votre infra, OK ? Ou vérifier RGPD/compliance
   - **Recommandation** : Données jamais quittent API backend, modèles jamais sauvegardés → maximum privacy

---

## **Implementation Order**

**Week 1-2: Backend Infrastructure**
- Phase 1 (Steps 1-3): Setup Python, config, tables Supabase

**Week 3: Score Financier**
- Phase 2 (Steps 4-5): Score calculator + endpoint

**Week 4: Anomaly Detection**
- Phase 3 (Steps 6-7): Detector + endpoint

**Week 5-6: Forecasting Models**
- Phase 4 (Steps 8-9): XGBoost
- Phase 5 (Steps 10-11): Prophet

**Week 7: Orchestration**
- Phase 6 (Step 12): Scheduler setup

**Week 8-9: Flutter UI**
- Phase 7 (Steps 13-17): Dashboard + services + UI integration

**Week 10: Sync & Integration**
- Phase 8 (Steps 18-20): Data sync, hooks, DAO methods

**Week 11: Testing**
- Phase 9 (Steps 21-22): Backend + Flutter tests

**Week 12: Deployment**
- Phase 9 (Steps 23-24): Deploy backend, documentation
