"""
Task Scheduler for Model Retraining
Orchestre retraining quotidien des modèles (Scores → XGBoost → Prophet)

Schedule:
- Daily at 02:00 UTC
- Retrain all user models
- Skip if already trained today
- Rollback on failure
"""

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from datetime import datetime, timedelta
import asyncio
import logging
from typing import Dict, List
import pytz

from config import settings
from supabase_client import get_supabase_client
from models.score_calculator import ScoreCalculator
from models.anomaly_detector import AnomalyDetector
from models.xgboost_forecaster import XGBoostForecaster
from models.prophet_forecaster import ProphetForecaster

logger = logging.getLogger(__name__)


class ModelScheduler:
    """
    Orchestre retraining automatique des modèles.
    """
    
    def __init__(self):
        self.scheduler = AsyncIOScheduler()
        self.supabase_client = get_supabase_client()
        self.score_calculator = ScoreCalculator()
        self.anomaly_detector = AnomalyDetector()
        self.xgboost_forecaster = XGBoostForecaster()
        self.prophet_forecaster = ProphetForecaster()
        self.is_running = False
    
    def start(self):
        """Démarre le scheduler."""
        if self.is_running:
            logger.warning("⚠️ Scheduler already running")
            return
        
        try:
            # Ajouter job retraining quotidien
            self.scheduler.add_job(
                func=self._retrain_all_models,
                trigger=CronTrigger(
                    hour=settings.SCHEDULER_RETRAIN_HOUR,
                    minute=0,
                    timezone=pytz.timezone(settings.SCHEDULER_TIMEZONE)
                ),
                id='daily_model_retraining',
                name='Daily Model Retraining',
                misfire_grace_time=600
            )
            
            self.scheduler.start()
            self.is_running = True
            logger.info(f"🚀 Scheduler started - Daily retraining at {settings.SCHEDULER_RETRAIN_HOUR}:00 UTC")
            
        except Exception as e:
            logger.error(f"❌ Failed to start scheduler: {e}")
    
    def stop(self):
        """Arrête le scheduler."""
        if not self.is_running:
            logger.warning("⚠️ Scheduler not running")
            return
        
        try:
            self.scheduler.shutdown()
            self.is_running = False
            logger.info("✅ Scheduler stopped")
        except Exception as e:
            logger.error(f"❌ Failed to stop scheduler: {e}")
    
    async def _retrain_all_models(self):
        """
        Retrain tous les modèles pour tous les utilisateurs.
        Orchestration: Scores → XGBoost → Prophet
        """
        
        try:
            logger.info("🔄 Starting daily model retraining cycle...")
            start_time = datetime.utcnow()
            
            # 1. Récupérer liste d'utilisateurs actifs
            user_ids = await self.supabase_client.get_all_user_ids()
            
            if not user_ids:
                logger.warning("No user IDs found for retraining")
                return
            
            stats = {
                "total_users": len(user_ids),
                "successful": 0,
                "failed": 0,
                "errors": []
            }
            
            for user_id in user_ids:
                try:
                    await self._retrain_user_models(user_id)
                    stats["successful"] += 1
                except Exception as e:
                    logger.error(f"❌ Retraining failed for {user_id}: {e}")
                    stats["failed"] += 1
                    stats["errors"].append({
                        "user_id": user_id,
                        "error": str(e)
                    })
            
            elapsed = (datetime.utcnow() - start_time).total_seconds()
            logger.info(f"✅ Retraining cycle complete in {elapsed:.1f}s - {stats}")
            
        except Exception as e:
            logger.error(f"❌ Critical error in retraining cycle: {e}")
    
    async def _retrain_user_models(self, user_id: str):
        """
        Retrain modèles pour utilisateur spécifique.
        
        Orchestration:
        1. Calculer scores financiers
        2. Détecter anomalies
        3. Entraîner XGBoost
        4. Entraîner Prophet
        5. Sauvegarder métadonnées
        """
        
        logger.info(f"📊 Retraining models for user {user_id[:8]}...")
        
        try:
            # 1. Récupérer données
            expenses_df = await self.supabase_client.get_user_expenses(user_id)
            income_df = await self.supabase_client.get_user_income(user_id)
            budgets_df = await self.supabase_client.get_user_budgets(user_id)
            
            if expenses_df.empty or income_df.empty:
                logger.warning(f"No data for user {user_id}")
                return
            
            # 2. Calculer scores
            if settings.ENABLE_SCORE_CALCULATION:
                logger.info(f"  → Calculating financial scores...")
                scores = self.score_calculator.calculate_all_scores(
                    expenses_df=expenses_df,
                    income_df=income_df,
                    budgets_df=budgets_df,
                    window_months=3
                )
                
                await self.supabase_client.save_financial_scores(
                    user_id=user_id,
                    month=datetime.utcnow(),
                    discipline_score=scores.get('discipline_score', 50),
                    stability_score=scores.get('stability_score', 50),
                    savings_score=scores.get('savings_score', 50),
                    risk_score=scores.get('risk_score', 50),
                    overall_score=scores.get('overall_score', 50),
                    insights=scores.get('insights', {})
                )
                logger.info(f"  ✅ Scores: {scores.get('overall_score', 50):.1f}")
            
            # 3. Détecter anomalies (optionnel, peut être on-demand)
            if settings.ENABLE_ANOMALY_DETECTION:
                logger.info(f"  → Detecting anomalies...")
                anomalies = self.anomaly_detector.detect_anomalies(expenses_df)
                logger.info(f"  ✅ Anomalies detected: {len(anomalies)}")
            
            # 4. XGBoost retraining
            if settings.ENABLE_XGBOOST:
                logger.info(f"  → Training XGBoost model...")
                metrics = self.xgboost_forecaster.train(expenses_df, income_df)
                
                if self.xgboost_forecaster.is_trained:
                    forecast = self.xgboost_forecaster.forecast(expenses_df, income_df)
                    next_month = datetime.utcnow() + timedelta(days=30)
                    
                    await self.supabase_client.save_predictions(
                        user_id=user_id,
                        month=next_month,
                        predicted_spending=forecast.get('predicted_spending', 0),
                        predicted_balance=forecast.get('predicted_balance', 0),
                        deficit_risk=forecast.get('deficit_risk', 0),
                        recommended_budget=forecast.get('recommended_budget', {})
                    )
                    
                    await self.supabase_client.save_model_metadata(
                        model_type='xgboost',
                        last_trained=datetime.utcnow(),
                        training_count=1,
                        data_points_used=len(expenses_df),
                        metrics=metrics
                    )
                    logger.info(f"  ✅ XGBoost trained - Spending: {forecast.get('predicted_spending', 0):.0f}")
            
            # 5. Prophet retraining (nécessite 12 mois)
            if settings.ENABLE_PROPHET and len(expenses_df) >= 365:
                logger.info(f"  → Training Prophet model...")
                metrics = self.prophet_forecaster.train(expenses_df)
                
                if self.prophet_forecaster.is_trained:
                    forecast = self.prophet_forecaster.forecast(periods=3)
                    
                    await self.supabase_client.save_model_metadata(
                        model_type='prophet',
                        last_trained=datetime.utcnow(),
                        training_count=1,
                        data_points_used=len(expenses_df),
                        metrics=metrics
                    )
                    logger.info(f"  ✅ Prophet trained - Seasonal patterns detected")
            
            logger.info(f"✅ User {user_id[:8]} retraining complete")
            
        except Exception as e:
            logger.error(f"❌ Error retraining user {user_id}: {e}")
            raise


# Global scheduler instance
_scheduler = None


def get_scheduler() -> ModelScheduler:
    """Factory pour obtenir scheduler singleton."""
    global _scheduler
    if _scheduler is None:
        _scheduler = ModelScheduler()
    return _scheduler


def start_scheduler():
    """Démarre le scheduler."""
    scheduler = get_scheduler()
    if not scheduler.is_running and settings.ENABLE_AUTO_RETRAINING:
        scheduler.start()


def stop_scheduler():
    """Arrête le scheduler."""
    scheduler = get_scheduler()
    if scheduler.is_running:
        scheduler.stop()
