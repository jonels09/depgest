"""
FastAPI Application for DepGest Predictive Analytics Backend

Endpoints:
- POST /scores/calculate - Calculate financial scores
- POST /anomalies/detect - Detect anomalies  
- GET /health - Health check
- GET /docs - Swagger API documentation
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, List
import logging
from datetime import datetime
import pandas as pd
import sys

from config import settings
from supabase_client import get_supabase_client
from models.score_calculator import ScoreCalculator
from models.anomaly_detector import AnomalyDetector
from models.xgboost_forecaster import XGBoostForecaster
from models.prophet_forecaster import ProphetForecaster

# ==================== LOGGING ====================
logging.basicConfig(
    level=getattr(logging, settings.LOG_LEVEL),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ==================== FASTAPI APP ====================
app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    description="AI-powered financial predictions and analysis"
)

# ==================== CORS CONFIGURATION ====================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # À restreindre en production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
from scheduler import start_scheduler

@app.on_event("startup")
async def startup_event():
    """Vérifie connexion au démarrage."""
    logger.info("🚀 DepGest Predictive Analytics Backend starting...")
    health = await supabase_client.health_check()
    if health:
        logger.info("✅ Database connection established")
    else:
        logger.error("❌ Database connection failed!")
    
    if settings.ENABLE_AUTO_RETRAINING:
        start_scheduler()

# ==================== REQUEST/RESPONSE MODELS ====================

class CalculateScoresRequest(BaseModel):
    user_id: str
    window_months: int = 3
    include_budgets: bool = False

class CalculateScoresResponse(BaseModel):
    user_id: str
    discipline_score: float
    stability_score: float
    savings_score: float
    risk_score: float
    overall_score: float
    insights: Dict
    window_months: int
    calculated_at: str

class DetectAnomaliesRequest(BaseModel):
    user_id: str
    depense_id: Optional[str] = None
    save_to_db: bool = True

class HealthCheckResponse(BaseModel):
    status: str
    timestamp: str
    database_connected: bool
    version: str

# ==================== INITIALIZATION ====================

supabase_client = get_supabase_client()
score_calculator = ScoreCalculator()
anomaly_detector = AnomalyDetector()
xgboost_forecaster = XGBoostForecaster(
    max_depth=settings.XGBOOST_MAX_DEPTH,
    learning_rate=settings.XGBOOST_LEARNING_RATE,
    n_estimators=settings.XGBOOST_N_ESTIMATORS
)
prophet_forecaster = ProphetForecaster(
    yearly_seasonality=settings.PROPHET_YEARLY_SEASONALITY,
    weekly_seasonality=settings.PROPHET_WEEKLY_SEASONALITY,
    daily_seasonality=settings.PROPHET_DAILY_SEASONALITY,
    interval_width=settings.PROPHET_INTERVAL_WIDTH
)

# ==================== HEALTH CHECK ====================

@app.get("/health", response_model=HealthCheckResponse)
async def health_check():
    """Vérifie santé du service."""
    try:
        db_ok = await supabase_client.health_check()
        return HealthCheckResponse(
            status="healthy" if db_ok else "degraded",
            timestamp=datetime.utcnow().isoformat(),
            database_connected=db_ok,
            version=settings.API_VERSION
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=500, detail="Health check failed")

# ==================== SCORES ENDPOINTS ====================

@app.post("/scores/calculate", response_model=CalculateScoresResponse)
async def calculate_scores(request: CalculateScoresRequest):
    """
    Calcule tous les scores financiers pour un utilisateur.
    
    Args:
        user_id: UUID utilisateur
        window_months: Période d'analyse (3, 6, ou 12 mois)
        include_budgets: Inclure budgets dans calcul (optionnel)
    
    Returns:
        Tous les scores + insights + recommendations
    """
    
    try:
        logger.info(f"📊 Calculating scores for user {request.user_id[:8]}...")
        
        # 1. Récupérer données utilisateur
        expenses_df = await supabase_client.get_user_expenses(
            request.user_id,
            start_date=None,  # Toute l'historique
            end_date=None
        )
        
        income_df = await supabase_client.get_user_income(
            request.user_id,
            start_date=None,
            end_date=None
        )
        
        budgets_df = None
        if request.include_budgets:
            budgets_df = await supabase_client.get_user_budgets(request.user_id)
        
        # 2. Calculer scores
        scores = score_calculator.calculate_all_scores(
            expenses_df=expenses_df,
            income_df=income_df,
            budgets_df=budgets_df,
            window_months=request.window_months
        )
        
        # 3. Sauvegarder résultats dans Supabase
        await supabase_client.save_financial_scores(
            user_id=request.user_id,
            month=datetime.utcnow(),
            discipline_score=scores['discipline_score'],
            stability_score=scores['stability_score'],
            savings_score=scores['savings_score'],
            risk_score=scores['risk_score'],
            overall_score=scores['overall_score'],
            insights=scores['insights']
        )
        
        logger.info(f"✅ Scores calculated successfully")
        
        return CalculateScoresResponse(
            user_id=request.user_id,
            discipline_score=scores['discipline_score'],
            stability_score=scores['stability_score'],
            savings_score=scores['savings_score'],
            risk_score=scores['risk_score'],
            overall_score=scores['overall_score'],
            insights=scores['insights'],
            window_months=request.window_months,
            calculated_at=scores['calculated_at']
        )
        
    except Exception as e:
        logger.error(f"❌ Score calculation failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== ANOMALY DETECTION ENDPOINTS ====================

@app.post("/anomalies/detect")
async def detect_anomalies(request: DetectAnomaliesRequest):
    """
    Détecte anomalies pour un utilisateur.
    
    Args:
        user_id: UUID utilisateur
        depense_id: ID dépense spécifique (optionnel)
        save_to_db: Sauvegarder dans Supabase
    
    Returns:
        Liste anomalies détectées avec type, severity, description
    """
    
    try:
        logger.info(f"🔍 Detecting anomalies for user {request.user_id[:8]}...")
        
        # 1. Récupérer dépenses utilisateur
        expenses_df = await supabase_client.get_user_expenses(request.user_id)
        
        if expenses_df.empty:
            logger.warning(f"No expenses found for user {request.user_id}")
            return {
                "user_id": request.user_id,
                "anomalies": [],
                "summary": {
                    "total_anomalies": 0,
                    "by_severity": {"LOW": 0, "MEDIUM": 0, "HIGH": 0},
                    "by_type": {}
                },
                "detected_at": datetime.utcnow().isoformat()
            }
        
        # 2. Détecter anomalies
        anomalies = anomaly_detector.detect_anomalies(expenses_df)
        
        # 3. Filtrer sur depense_id si spécifié
        if request.depense_id:
            anomalies = [a for a in anomalies if a.get('depense_id') == request.depense_id]
        
        # 4. Sauvegarder dans Supabase si demandé
        if request.save_to_db and anomalies:
            for anomaly in anomalies:
                await supabase_client.save_anomaly(
                    user_id=request.user_id,
                    depense_id=anomaly.get('depense_id', 'unknown'),
                    anomaly_type=anomaly.get('anomaly_type', 'UNKNOWN'),
                    severity=anomaly.get('severity', 'LOW'),
                    description=anomaly.get('description', ''),
                    metadata=anomaly.get('metadata', {})
                )
        
        # 5. Retourner résumé
        summary = anomaly_detector.get_anomaly_summary(anomalies)
        
        logger.info(f"✅ Detected {len(anomalies)} anomalies")
        
        return {
            "user_id": request.user_id,
            "anomalies": anomalies,
            "summary": summary,
            "detected_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Anomaly detection failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== FORECAST ENDPOINTS ====================

@app.post("/forecast/xgboost")
async def forecast_xgboost(user_id: str):
    """
    Prédictions XGBoost pour dépenses futures.
    
    Returns:
        - predicted_spending: Dépenses prévues mois suivant
        - predicted_balance: Solde fin mois
        - deficit_risk: Probabilité déficit (%)
        - recommended_budget: Budgets recommandés par catégorie
    """
    
    try:
        logger.info(f"📈 Generating XGBoost forecast for user {user_id[:8]}...")
        
        if not settings.ENABLE_XGBOOST:
            logger.warning("XGBoost disabled in settings")
            return {
                "user_id": user_id,
                "status": "disabled",
                "generated_at": datetime.utcnow().isoformat()
            }
        
        # 1. Récupérer données
        expenses_df = await supabase_client.get_user_expenses(user_id)
        income_df = await supabase_client.get_user_income(user_id)
        
        if expenses_df.empty or income_df.empty:
            forecast = xgboost_forecaster.baseline_forecast(expenses_df, income_df)
            metrics = {"model": "baseline", "reason": "insufficient_data"}
        else:
            # 2. Entraîner modèle
            metrics = xgboost_forecaster.train(expenses_df, income_df)
            
            # 3. Générer prévisions
            forecast = (
                xgboost_forecaster.forecast(expenses_df, income_df)
                if xgboost_forecaster.is_trained
                else xgboost_forecaster.baseline_forecast(expenses_df, income_df)
            )
            if not xgboost_forecaster.is_trained:
                metrics = {"model": "baseline", "reason": "limited_monthly_history"}
        
        # 4. Sauvegarder résultats
        next_month = pd.Timestamp.now() + pd.DateOffset(months=1)
        await supabase_client.save_predictions(
            user_id=user_id,
            month=next_month,
            predicted_spending=forecast.get('predicted_spending', 0),
            predicted_balance=forecast.get('predicted_balance', 0),
            deficit_risk=forecast.get('deficit_risk', 0),
            recommended_budget=forecast.get('recommended_budget', {})
        )
        
        # 5. Sauvegarder métadonnées
        await supabase_client.save_model_metadata(
            model_type='xgboost',
            last_trained=datetime.utcnow(),
            training_count=1,
            data_points_used=len(expenses_df),
            metrics=metrics
        )
        
        logger.info(f"✅ XGBoost forecast generated successfully")
        
        return {
            "user_id": user_id,
            "status": "success",
            "forecast": forecast,
            "metrics": metrics,
            "generated_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ XGBoost forecast failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/forecast/prophet")
async def forecast_prophet(user_id: str):
    """
    Prédictions Prophet pour patterns saisonniers.
    
    Returns:
        - monthly_forecast: Prévisions 3 mois + intervalles confiance
        - seasonal_patterns: Patterns détectés (vacances, fêtes, etc.)
        - trend: Direction tendance générale
    """
    
    try:
        logger.info(f"🔮 Generating Prophet forecast for user {user_id[:8]}...")
        
        if not settings.ENABLE_PROPHET:
            logger.warning("Prophet disabled in settings")
            return {
                "user_id": user_id,
                "status": "disabled",
                "generated_at": datetime.utcnow().isoformat()
            }
        
        # 1. Récupérer données
        expenses_df = await supabase_client.get_user_expenses(user_id)
        
        if expenses_df.empty:
            metrics = {"model": "baseline", "reason": "insufficient_data"}
            forecast = prophet_forecaster.baseline_forecast(expenses_df, periods=3)
        else:
            # 2. Entraîner modèle
            metrics = prophet_forecaster.train(expenses_df)
            
            # 3. Générer prévisions
            forecast = (
                prophet_forecaster.forecast(periods=3)
                if prophet_forecaster.is_trained
                else prophet_forecaster.baseline_forecast(expenses_df, periods=3)
            )
            if not prophet_forecaster.is_trained:
                metrics = {"model": "baseline", "reason": "limited_monthly_history"}
        
        # 4. Sauvegarder insights
        if forecast.get('monthly_forecast'):
            await supabase_client.save_model_metadata(
                model_type='prophet',
                last_trained=datetime.utcnow(),
                training_count=1,
                data_points_used=len(expenses_df),
                metrics=metrics
            )
        
        logger.info(f"✅ Prophet forecast generated successfully")
        
        return {
            "user_id": user_id,
            "status": "success",
            "forecast": forecast,
            "metrics": metrics,
            "generated_at": datetime.utcnow().isoformat()
        }
        
    except Exception as e:
        logger.error(f"❌ Prophet forecast failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# ==================== ERROR HANDLERS ====================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": exc.detail,
            "timestamp": datetime.utcnow().isoformat()
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request, exc):
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "timestamp": datetime.utcnow().isoformat()
        }
    )

# ==================== ROOT ENDPOINT ====================

@app.get("/")
async def root():
    return {
        "service": "DepGest Predictive Analytics",
        "version": settings.API_VERSION,
        "docs": "/docs",
        "health": "/health"
    }

# ==================== RUN ====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host=settings.API_HOST,
        port=settings.API_PORT,
        log_level=settings.LOG_LEVEL.lower()
    )
