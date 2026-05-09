"""
Tests for XGBoostForecaster
"""

import pytest
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from models.xgboost_forecaster import XGBoostForecaster


@pytest.fixture
def xgboost_forecaster():
    return XGBoostForecaster(
        max_depth=6,
        learning_rate=0.1,
        n_estimators=100,
        test_size=0.2
    )


@pytest.fixture
def sample_expenses_12months():
    """Dépenses 12 mois."""
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    data = {
        'date': dates,
        'total': [1000, 1100, 950, 1200, 1050, 1100, 900, 1150, 1000, 1050, 1100, 1200],
        'category': ['Alimentation'] * 12
    }
    return pd.DataFrame(data)


@pytest.fixture
def sample_income_12months():
    """Revenus 12 mois."""
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    data = {
        'date': dates,
        'amount': [2000] * 12
    }
    return pd.DataFrame(data)


def test_training_with_sufficient_data(xgboost_forecaster, sample_expenses_12months, sample_income_12months):
    """Teste entraînement réussi avec données suffisantes."""
    
    metrics = xgboost_forecaster.train(sample_expenses_12months, sample_income_12months)
    
    assert xgboost_forecaster.is_trained == True
    assert xgboost_forecaster.spending_model is not None
    assert isinstance(metrics, dict)


def test_training_insufficient_data(xgboost_forecaster):
    """Teste que entraînement échoue avec peu de données."""
    
    minimal_expenses = pd.DataFrame({
        'date': pd.date_range('2024-01-01', periods=2, freq='D'),
        'total': [100, 200],
        'category': ['Test'] * 2
    })
    
    minimal_income = pd.DataFrame({
        'date': pd.date_range('2024-01-01', periods=2, freq='D'),
        'amount': [500, 500]
    })
    
    metrics = xgboost_forecaster.train(minimal_expenses, minimal_income)
    
    assert xgboost_forecaster.is_trained == False


def test_forecast_before_training(xgboost_forecaster, sample_expenses_12months, sample_income_12months):
    """Teste que forecast sans entraînement retourne valeurs par défaut."""
    
    forecast = xgboost_forecaster.forecast(sample_expenses_12months, sample_income_12months)
    
    assert forecast['predicted_spending'] == 0.0
    assert forecast['model_version'] == 'baseline'


def test_forecast_after_training(xgboost_forecaster, sample_expenses_12months, sample_income_12months):
    """Teste forecast après entraînement."""
    
    xgboost_forecaster.train(sample_expenses_12months, sample_income_12months)
    forecast = xgboost_forecaster.forecast(sample_expenses_12months, sample_income_12months)
    
    assert forecast['predicted_spending'] > 0
    assert 0 <= forecast['deficit_risk'] <= 100
    assert isinstance(forecast['recommended_budget'], dict)


def test_predicted_spending_reasonable(xgboost_forecaster, sample_expenses_12months, sample_income_12months):
    """Teste que prédictions sont raisonnables (proche de moyenne)."""
    
    xgboost_forecaster.train(sample_expenses_12months, sample_income_12months)
    forecast = xgboost_forecaster.forecast(sample_expenses_12months, sample_income_12months)
    
    avg_spending = sample_expenses_12months['total'].mean()
    predicted = forecast['predicted_spending']
    
    # Prédiction dans plage raisonnable (70-130% de moyenne)
    assert predicted > avg_spending * 0.7
    assert predicted < avg_spending * 1.3


def test_recommended_budget_sums_correctly(xgboost_forecaster, sample_expenses_12months, sample_income_12months):
    """Teste que budgets recommandés somment au total prédit."""
    
    xgboost_forecaster.train(sample_expenses_12months, sample_income_12months)
    forecast = xgboost_forecaster.forecast(sample_expenses_12months, sample_income_12months)
    
    budget_total = sum(forecast['recommended_budget'].values())
    predicted = forecast['predicted_spending']
    
    # Tolérance 5%
    if budget_total > 0:
        assert abs(budget_total - predicted) < predicted * 0.05


def test_deficit_risk_with_surplus_income(xgboost_forecaster):
    """Teste que risque déficit bas quand revenus >> dépenses."""
    
    expenses = pd.DataFrame({
        'date': pd.date_range('2023-01-01', periods=12, freq='M'),
        'total': [500] * 12,
        'category': ['Test'] * 12
    })
    
    income = pd.DataFrame({
        'date': pd.date_range('2023-01-01', periods=12, freq='M'),
        'amount': [3000] * 12  # 6x les dépenses
    })
    
    xgboost_forecaster.train(expenses, income)
    forecast = xgboost_forecaster.forecast(expenses, income)
    
    # Risque déficit devrait être très bas
    assert forecast['deficit_risk'] < 25


def test_deficit_risk_with_deficit(xgboost_forecaster):
    """Teste que risque déficit élevé quand dépenses > revenus."""
    
    expenses = pd.DataFrame({
        'date': pd.date_range('2023-01-01', periods=12, freq='M'),
        'total': [2000] * 12,
        'category': ['Test'] * 12
    })
    
    income = pd.DataFrame({
        'date': pd.date_range('2023-01-01', periods=12, freq='M'),
        'amount': [1500] * 12  # Moins que dépenses
    })
    
    xgboost_forecaster.train(expenses, income)
    forecast = xgboost_forecaster.forecast(expenses, income)
    
    # Risque déficit devrait être élevé
    assert forecast['deficit_risk'] > 75


def test_empty_dataframe_handling(xgboost_forecaster):
    """Teste robustesse avec DataFrames vides."""
    
    empty_expenses = pd.DataFrame({'date': [], 'total': [], 'category': []})
    empty_income = pd.DataFrame({'date': [], 'amount': []})
    
    forecast = xgboost_forecaster.forecast(empty_expenses, empty_income)
    
    # Doit retourner forecast par défaut sans crash
    assert 'predicted_spending' in forecast
    assert forecast['model_version'] == 'baseline'


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
