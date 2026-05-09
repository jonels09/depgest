"""
Tests for ScoreCalculator
Teste calcul des 4 scores et validations
"""

import pytest
import pandas as pd
from datetime import datetime, timedelta
from models.score_calculator import ScoreCalculator


@pytest.fixture
def score_calculator():
    return ScoreCalculator()


@pytest.fixture
def sample_expenses():
    """Génère dépenses synthétiques."""
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    data = {
        'date': dates,
        'total': [1000, 1100, 950, 1200, 1050, 1100, 900, 1150, 1000, 1050, 1100, 1200],
        'category': ['Alimention'] * 12
    }
    return pd.DataFrame(data)


@pytest.fixture
def sample_income():
    """Génère revenus synthétiques."""
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    data = {
        'date': dates,
        'amount': [2000] * 12
    }
    return pd.DataFrame(data)


def test_score_ranges(score_calculator, sample_expenses, sample_income):
    """Teste que tous les scores sont dans la plage 0-100."""
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=sample_expenses,
        income_df=sample_income,
        window_months=12
    )
    
    assert 0 <= scores['discipline_score'] <= 100
    assert 0 <= scores['stability_score'] <= 100
    assert 0 <= scores['savings_score'] <= 100
    assert 0 <= scores['risk_score'] <= 100
    assert 0 <= scores['overall_score'] <= 100


def test_default_scores_insufficient_data(score_calculator):
    """Teste comportement avec données insuffisantes."""
    
    empty_expenses = pd.DataFrame({'date': [], 'total': [], 'category': []})
    empty_income = pd.DataFrame({'date': [], 'amount': []})
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=empty_expenses,
        income_df=empty_income
    )
    
    # Doit retourner scores par défaut (50)
    assert scores['overall_score'] == 50.0
    assert scores['discipline_score'] == 50.0


def test_stable_expenses_high_stability(score_calculator):
    """Teste que dépenses stables = score stabilité élevé."""
    
    # Créer dépenses très stables (même montant chaque mois)
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    stable_expenses = pd.DataFrame({
        'date': dates,
        'total': [1000] * 12,
        'category': ['Test'] * 12
    })
    
    income = pd.DataFrame({
        'date': dates,
        'amount': [2000] * 12
    })
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=stable_expenses,
        income_df=income
    )
    
    # Stability score devrait être élevé pour dépenses stables
    assert scores['stability_score'] > 70


def test_positive_savings(score_calculator):
    """Teste calcul savings score avec surplus régulier."""
    
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    expenses = pd.DataFrame({
        'date': dates,
        'total': [1000] * 12,
        'category': ['Test'] * 12
    })
    
    # Revenus >> dépenses = épargnes importantes
    income = pd.DataFrame({
        'date': dates,
        'amount': [2000] * 12
    })
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=expenses,
        income_df=income
    )
    
    # Savings score devrait être élevé
    assert scores['savings_score'] > 60


def test_high_deficit_risk(score_calculator):
    """Teste calcul risk score avec déficits fréquents."""
    
    dates = pd.date_range(start='2023-01-01', periods=12, freq='M')
    expenses = pd.DataFrame({
        'date': dates,
        'total': [2000] * 12,
        'category': ['Test'] * 12
    })
    
    # Revenus < dépenses = déficit
    income = pd.DataFrame({
        'date': dates,
        'amount': [1500] * 12
    })
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=expenses,
        income_df=income
    )
    
    # Risk score devrait être élevé
    assert scores['risk_score'] > 70


def test_insights_generated(score_calculator, sample_expenses, sample_income):
    """Teste que insights sont générés."""
    
    scores = score_calculator.calculate_all_scores(
        expenses_df=sample_expenses,
        income_df=sample_income
    )
    
    assert 'insights' in scores
    assert 'overall' in scores['insights']
    assert 'discipline' in scores['insights']
    assert 'recommendations' in scores['insights']
    assert len(scores['insights']['recommendations']) > 0


def test_window_months_parameter(score_calculator, sample_expenses, sample_income):
    """Teste que window_months affecte les calculs."""
    
    scores_3m = score_calculator.calculate_all_scores(
        expenses_df=sample_expenses,
        income_df=sample_income,
        window_months=3
    )
    
    scores_12m = score_calculator.calculate_all_scores(
        expenses_df=sample_expenses,
        income_df=sample_income,
        window_months=12
    )
    
    # Résultats peuvent différer selon la fenêtre
    assert scores_3m['window_months'] == 3
    assert scores_12m['window_months'] == 12


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
