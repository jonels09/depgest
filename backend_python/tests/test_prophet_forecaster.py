"""
Tests for ProphetForecaster
"""

import pytest
import pandas as pd
from datetime import datetime, timedelta
from models.prophet_forecaster import ProphetForecaster


@pytest.fixture
def prophet_forecaster():
    return ProphetForecaster(
        yearly_seasonality=True,
        weekly_seasonality=True,
        daily_seasonality=False,
        interval_width=0.95
    )


@pytest.fixture
def sample_expenses_24months():
    """Dépenses 24 mois pour seasonality."""
    dates = pd.date_range(start='2022-01-01', periods=24, freq='M')
    # Pattern annuel: July-August spike, December spike, autres mois normaux
    amounts = []
    for i, date in enumerate(dates):
        month = date.month
        if month in [7, 8]:  # Vacances
            amounts.append(1500)
        elif month == 12:  # Fêtes
            amounts.append(1800)
        else:
            amounts.append(1000)
    
    data = {
        'date': dates,
        'total': amounts,
        'category': ['Total'] * 24
    }
    return pd.DataFrame(data)


def test_training_requires_12_months_minimum(prophet_forecaster):
    """Teste que Prophet nécessite minimum 12 mois."""
    
    short_data = pd.DataFrame({
        'date': pd.date_range('2024-01-01', periods=6, freq='M'),
        'total': [1000] * 6,
        'category': ['Test'] * 6
    })
    
    metrics = prophet_forecaster.train(short_data)
    
    assert prophet_forecaster.is_trained == False


def test_training_with_24months(prophet_forecaster, sample_expenses_24months):
    """Teste entraînement réussi avec 24 mois."""
    
    metrics = prophet_forecaster.train(sample_expenses_24months)
    
    assert prophet_forecaster.is_trained == True
    assert prophet_forecaster.model is not None


def test_forecast_structure(prophet_forecaster, sample_expenses_24months):
    """Teste structure du forecast retourné."""
    
    prophet_forecaster.train(sample_expenses_24months)
    forecast = prophet_forecaster.forecast(periods=3)
    
    assert 'monthly_forecast' in forecast
    assert 'seasonal_patterns' in forecast
    assert 'trend' in forecast
    assert 'confidence_level' in forecast
    
    # Vérifie que forecast a 3 mois
    assert len(forecast['monthly_forecast']) == 3


def test_forecast_monthly_format(prophet_forecaster, sample_expenses_24months):
    """Teste format des prévisions mensuelles."""
    
    prophet_forecaster.train(sample_expenses_24months)
    forecast = prophet_forecaster.forecast(periods=3)
    
    for month_forecast in forecast['monthly_forecast']:
        assert 'date' in month_forecast
        assert 'forecast' in month_forecast
        assert 'lower_95' in month_forecast
        assert 'upper_95' in month_forecast
        
        # Intervalles devraient être: lower < forecast < upper
        assert month_forecast['lower_95'] <= month_forecast['forecast']
        assert month_forecast['forecast'] <= month_forecast['upper_95']


def test_trend_detection(prophet_forecaster, sample_expenses_24months):
    """Teste détection de tendance."""
    
    prophet_forecaster.train(sample_expenses_24months)
    forecast = prophet_forecaster.forecast(periods=3)
    
    trend = forecast['trend']
    
    assert 'direction' in trend
    assert trend['direction'] in ['UP', 'DOWN', 'STABLE']
    assert 'percent' in trend


def test_confidence_intervals_consistent(prophet_forecaster, sample_expenses_24months):
    """Teste que intervalles de confiance sont cohérents."""
    
    prophet_forecaster.train(sample_expenses_24months)
    forecast = prophet_forecaster.forecast(periods=3)
    
    for month_forecast in forecast['monthly_forecast']:
        lower = month_forecast['lower_95']
        upper = month_forecast['upper_95']
        forecast_val = month_forecast['forecast']
        
        # Intervalles larges (95%)
        width = upper - lower
        assert width > 0
        
        # Forecast au milieu environ
        assert lower < forecast_val < upper


def test_forecast_without_training(prophet_forecaster):
    """Teste forecast sans entraînement retourne baseline."""
    
    forecast = prophet_forecaster.forecast(periods=3)
    
    # Doit retourner baseline, pas crash
    assert 'monthly_forecast' in forecast
    assert len(forecast['monthly_forecast']) == 3
    assert forecast['model_version'] == 'baseline'


def test_multiple_forecast_periods(prophet_forecaster, sample_expenses_24months):
    """Teste différentes longueurs de forecast."""
    
    prophet_forecaster.train(sample_expenses_24months)
    
    forecast_3m = prophet_forecaster.forecast(periods=3)
    forecast_6m = prophet_forecaster.forecast(periods=6)
    
    assert len(forecast_3m['monthly_forecast']) == 3
    assert len(forecast_6m['monthly_forecast']) == 6


def test_empty_dataframe_handling(prophet_forecaster):
    """Teste robustesse avec DataFrame vide."""
    
    empty_df = pd.DataFrame({'date': [], 'total': [], 'category': []})
    
    metrics = prophet_forecaster.train(empty_df)
    
    assert prophet_forecaster.is_trained == False


def test_monotonic_forecast_values(prophet_forecaster, sample_expenses_24months):
    """Teste que valeurs du forecast sont raisonnables."""
    
    prophet_forecaster.train(sample_expenses_24months)
    forecast = prophet_forecaster.forecast(periods=3)
    
    for month_forecast in forecast['monthly_forecast']:
        # Dépenses devraient être positives et raisonnables
        assert month_forecast['forecast'] > 0
        assert month_forecast['forecast'] < 10000  # Limite sup raisonnable


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
