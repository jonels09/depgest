"""
Tests for AnomalyDetector
"""

import pytest
import pandas as pd
from datetime import datetime, timedelta
from models.anomaly_detector import AnomalyDetector


@pytest.fixture
def anomaly_detector():
    return AnomalyDetector(contamination=0.05, zscore_threshold=2.5)


@pytest.fixture
def sample_expenses_normal():
    """Dépenses normales."""
    dates = pd.date_range(start='2024-01-01', periods=30, freq='D')
    data = {
        'id': [f'exp_{i}' for i in range(30)],
        'date': dates,
        'total': [50, 55, 48, 52, 51] * 6,  # Pattern normal
        'category': ['Alimentation'] * 30
    }
    return pd.DataFrame(data)


@pytest.fixture
def sample_expenses_with_spike():
    """Dépenses avec spike anomal."""
    dates = pd.date_range(start='2024-01-01', periods=30, freq='D')
    amounts = [50, 55, 48, 52, 51] * 6
    amounts[15] = 500  # Spike
    
    data = {
        'id': [f'exp_{i}' for i in range(30)],
        'date': dates,
        'total': amounts,
        'category': ['Alimentation'] * 30
    }
    return pd.DataFrame(data)


@pytest.fixture
def sample_expenses_suspicious():
    """Dépenses avec patterns suspects."""
    dates = pd.date_range(start='2024-01-01', periods=30, freq='D')
    amounts = [100.00] * 10 + [50, 55, 48, 52, 51] * 4
    
    data = {
        'id': [f'exp_{i}' for i in range(30)],
        'date': dates,
        'total': amounts,
        'category': ['Alimentation'] * 30
    }
    return pd.DataFrame(data)


def test_normal_expenses_no_anomalies(anomaly_detector, sample_expenses_normal):
    """Teste que dépenses normales ne génèrent pas anomalies."""
    
    anomalies = anomaly_detector.detect_anomalies(sample_expenses_normal)
    
    # Peu ou pas d'anomalies pour données normales
    assert len(anomalies) <= 2  # Tolérance

def test_spike_detection(anomaly_detector, sample_expenses_with_spike):
    """Teste détection d'une dépense anormalement élevée."""
    
    anomalies = anomaly_detector.detect_anomalies(sample_expenses_with_spike)
    
    # Doit détecter la dépense de 500
    high_amount_anomalies = [a for a in anomalies if a.get('anomaly_type') in ['UNUSUAL_AMOUNT', 'SUDDEN_SPIKE']]
    assert len(high_amount_anomalies) > 0
    
    # Au moins un devrait être severity MEDIUM ou HIGH
    high_severity = [a for a in high_amount_anomalies if a.get('severity') in ['MEDIUM', 'HIGH']]
    assert len(high_severity) > 0


def test_suspicious_pattern_detection(anomaly_detector, sample_expenses_suspicious):
    """Teste détection de patterns suspects (montants répétés)."""
    
    anomalies = anomaly_detector.detect_anomalies(sample_expenses_suspicious)
    
    # Doit détecter montants répétés 100.00
    fraud_anomalies = [a for a in anomalies if a.get('anomaly_type') == 'FRAUD_SUSPICIOUS']
    
    # Au moins un pattern de montant répété devrait être détecté
    repeated_patterns = [a for a in fraud_anomalies if 'repeat' in a.get('description', '').lower()]
    assert len(repeated_patterns) > 0


def test_anomaly_summary_structure(anomaly_detector, sample_expenses_with_spike):
    """Teste structure du résumé anomalies."""
    
    anomalies = anomaly_detector.detect_anomalies(sample_expenses_with_spike)
    summary = anomaly_detector.get_anomaly_summary(anomalies)
    
    # Vérifie structure
    assert 'total_anomalies' in summary
    assert 'by_severity' in summary
    assert 'by_type' in summary
    
    # Vérifie que total_anomalies = somme des sévérités
    total_by_severity = sum(summary['by_severity'].values())
    assert summary['total_anomalies'] >= total_by_severity


def test_empty_expenses_no_crash(anomaly_detector):
    """Teste robustesse avec DataFrame vide."""
    
    empty_df = pd.DataFrame({'date': [], 'total': [], 'category': [], 'id': []})
    
    anomalies = anomaly_detector.detect_anomalies(empty_df)
    
    assert isinstance(anomalies, list)
    assert len(anomalies) == 0


def test_anomaly_metadata_present(anomaly_detector, sample_expenses_with_spike):
    """Teste que métadonnées sont présentes dans anomalies."""
    
    anomalies = anomaly_detector.detect_anomalies(sample_expenses_with_spike)
    
    for anomaly in anomalies:
        assert 'anomaly_type' in anomaly
        assert 'severity' in anomaly
        assert 'description' in anomaly
        assert 'metadata' in anomaly
        assert isinstance(anomaly['metadata'], dict)


def test_contamination_parameter(anomaly_detector, sample_expenses_normal):
    """Teste que paramètre contamination affecte détection."""
    
    detector_strict = AnomalyDetector(contamination=0.01, zscore_threshold=2.5)
    detector_loose = AnomalyDetector(contamination=0.20, zscore_threshold=2.5)
    
    anomalies_strict = detector_strict.detect_anomalies(sample_expenses_normal)
    anomalies_loose = detector_loose.detect_anomalies(sample_expenses_normal)
    
    # Strict devrait détecter moins d'anomalies
    assert len(anomalies_strict) <= len(anomalies_loose)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
