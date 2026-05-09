"""
Machine Learning models package.

Imports are intentionally lazy: Prophet and XGBoost are heavy optional modules,
and importing them here makes lightweight score/anomaly tests depend on the
whole ML stack.
"""

__all__ = [
    "score_calculator",
    "anomaly_detector",
    "xgboost_forecaster",
    "prophet_forecaster",
]
