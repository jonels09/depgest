from pydantic_settings import BaseSettings
from typing import Optional
import os

class Settings(BaseSettings):
    """
    Configuration centralisée pour le backend IA financière.
    Charge les variables d'environnement depuis .env
    """
    
    # Supabase Configuration
    SUPABASE_URL: str
    SUPABASE_KEY: str
    SUPABASE_DB_PASSWORD: Optional[str] = None
    
    # FastAPI Configuration
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    API_TITLE: str = "DepGest Predictive Analytics API"
    API_VERSION: str = "1.0.0"
    ENVIRONMENT: str = "development"  # development, staging, production
    
    # Model Training Configuration
    XGBOOST_TEST_SIZE: float = 0.2
    XGBOOST_MAX_DEPTH: int = 6
    XGBOOST_LEARNING_RATE: float = 0.1
    XGBOOST_N_ESTIMATORS: int = 100
    
    PROPHET_YEARLY_SEASONALITY: bool = True
    PROPHET_WEEKLY_SEASONALITY: bool = True
    PROPHET_DAILY_SEASONALITY: bool = False
    PROPHET_INTERVAL_WIDTH: float = 0.95
    
    # Anomaly Detection Configuration
    ANOMALY_ISOLATION_FOREST_CONTAMINATION: float = 0.05
    ANOMALY_ZSCORE_THRESHOLD: float = 2.5
    ANOMALY_MIN_HISTORY_DAYS: int = 30
    
    # Scheduler Configuration
    SCHEDULER_TIMEZONE: str = "UTC"
    SCHEDULER_RETRAIN_HOUR: int = 2  # 02:00 UTC
    SCHEDULER_RETRAIN_DAY_OF_WEEK: str = "*"  # "*" = daily, "0-6" = specific days
    
    # Logging Configuration
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "json"
    
    # Feature Flags
    ENABLE_XGBOOST: bool = True
    ENABLE_PROPHET: bool = True
    ENABLE_ANOMALY_DETECTION: bool = True
    ENABLE_SCORE_CALCULATION: bool = True
    ENABLE_AUTO_RETRAINING: bool = True
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# Singleton instance
settings = Settings()
