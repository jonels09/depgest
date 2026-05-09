# DepGest Predictive Analytics Backend

Backend Python FastAPI pour intégration d'intelligence artificielle financière dans DepGest (Flutter).

## Architecture

```
backend_python/
├── config.py                 # Configuration centralisée
├── supabase_client.py        # Client Supabase pour accès données
├── main.py                   # FastAPI app + endpoints (à créer)
├── scheduler.py              # APScheduler + orchestration (à créer)
├── models/
│   ├── score_calculator.py       # Scores financiers
│   ├── anomaly_detector.py       # Détection anomalies
│   ├── xgboost_forecaster.py     # Prédictions XGBoost
│   └── prophet_forecaster.py     # Patterns saisonniers Prophet
├── migrations/
│   └── 001_create_prediction_tables.sql  # Tables Supabase
├── tests/                    # Unit + integration tests (à créer)
├── requirements.txt          # Dépendances Python
├── .env.example             # Template variables d'environnement
└── Dockerfile               # Containerization (optionnel)
```

## Setup Rapide

### 1. Prérequis
- Python 3.9+
- Compte Supabase avec projet créé
- pip ou Poetry

### 2. Installation

```bash
cd backend_python

# Créer .env à partir du template
cp .env.example .env
# Éditer .env avec vos clés Supabase

# Installer dépendances
pip install -r requirements.txt

# (Optionnel) Si vous utilisez Poetry
# poetry install
```

### 3. Configuration Supabase

Exécutez la migration SQL dans Supabase SQL Editor:

```
1. Allez à https://supabase.com/dashboard
2. Sélectionnez votre projet
3. Allez à SQL Editor
4. Créez une nouvelle requête
5. Copiez le contenu de migrations/001_create_prediction_tables.sql
6. Exécutez la requête (Run)
```

Les tables créées:
- `financial_scores` - Scores financiers mensuels
- `predictions` - Prédictions XGBoost
- `anomalies` - Anomalies détectées
- `model_metadata` - Infos entraînement modèles
- `prophet_insights` - Patterns saisonniers (optionnel)

### 4. Test Connexion

```bash
python -c "from supabase_client import get_supabase_client; \
           client = get_supabase_client(); \
           print('✅ Connected!' if client.health_check() else '❌ Failed')"
```

## Phases Implémentation

### Phase 1: ✅ Infrastructure Backend (Complétée)
- [x] Structure Python + dependencies
- [x] Configuration centralisée (config.py)
- [x] Client Supabase (supabase_client.py)
- [x] Tables Supabase + RLS

**Prochaine étape:** Phase 2 - Score Financier

### Phase 2: Score Financier (À faire)
- [ ] Module `models/score_calculator.py`
- [ ] Endpoint FastAPI `/scores/calculate`
- [ ] Tests unitaires

### Phase 3: Détection Anomalies (À faire)
- [ ] Module `models/anomaly_detector.py` (Isolation Forest + Z-score)
- [ ] Endpoint FastAPI `/anomalies/detect`

### Phase 4: XGBoost Forecaster (À faire)
- [ ] Module `models/xgboost_forecaster.py`
- [ ] Endpoint FastAPI `/forecast/xgboost`

### Phase 5: Prophet Forecaster (À faire)
- [ ] Module `models/prophet_forecaster.py`
- [ ] Endpoint FastAPI `/forecast/prophet`

### Phase 6: Scheduler (À faire)
- [ ] Module `scheduler.py` (APScheduler)
- [ ] Orchestration quotidienne des retraînements

### Phase 7-9: Flutter Integration + Tests + Deploy (À faire)

## API Endpoints (Roadmap)

```
POST   /scores/calculate          # Calculer scores financiers
POST   /anomalies/detect          # Détecter anomalies
GET    /anomalies/{user_id}       # Lister anomalies utilisateur
POST   /forecast/xgboost          # Prédictions XGBoost
POST   /forecast/prophet          # Prédictions Prophet
GET    /health                    # Health check
GET    /docs                      # Swagger UI
```

## Dépendances Principales

```
FastAPI 0.104.1      - Web framework
XGBoost 2.0.3        - Gradient boosting (short-term forecasting)
Prophet 1.1.5        - Time series (seasonal patterns)
scikit-learn 1.3.2   - Machine learning utilities (Isolation Forest)
pandas 2.1.3         - Data manipulation
Supabase 2.0.3       - Client cloud database
APScheduler 3.10.4   - Task scheduling
Pydantic 2.5.0       - Data validation
```

## Logs

Le backend log en format JSON pour faciliter parsing.

```bash
# Démarrer avec logs actifs
LOG_LEVEL=INFO python main.py

# Voir logs en temps réel
tail -f app.log
```

## Prochaines Étapes

1. **Phase 2 (Score Financier):** Implémentation de la logique calcul scores
2. **Phase 3 (Anomalies):** Détection basée sur Isolation Forest + Z-score
3. **Phase 4-5 (Forecasters):** Modèles XGBoost et Prophet
4. **Phase 6 (Scheduler):** Orchestration quotidienne (02:00 UTC)
5. **Phase 7:** Intégration Flutter + Dashboard

## Questions?

Consultez le plan complet: `plan-depgestPredictiveAI.prompt.md`
